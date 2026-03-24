import {
  Inject,
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { ChatOpenAI } from '@langchain/openai';
import type { BaseMessageChunk } from '@langchain/core/messages';
import { HumanMessage } from '@langchain/core/messages';
import { Job, Worker } from 'bullmq';
import type IORedis from 'ioredis';
import { Repository } from 'typeorm';
import { AgentTask } from '../agent/agent-task.entity';
import { AgentTaskStatus } from '../agent/agent-task-status.enum';
import { AGENT_QUEUE_NAME, taskEventsChannel } from '../agent/agent.constants';
import { serializeAgentEvent } from '../agent/agent-events';
import { REDIS_CLIENT } from '../redis/redis.tokens';

function textFromChunk(chunk: BaseMessageChunk): string {
  const c = chunk.content;
  if (typeof c === 'string') return c;
  if (Array.isArray(c)) {
    return c
      .map((part) => {
        if (typeof part === 'string') return part;
        if (part && typeof part === 'object' && 'text' in part) {
          return String((part as { text?: string }).text ?? '');
        }
        return '';
      })
      .join('');
  }
  return '';
}

@Injectable()
export class AgentWorkerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(AgentWorkerService.name);
  private worker!: Worker;

  constructor(
    @Inject(REDIS_CLIENT) private readonly redis: IORedis,
    @InjectRepository(AgentTask)
    private readonly tasks: Repository<AgentTask>,
    private readonly config: ConfigService,
  ) {}

  onModuleInit(): void {
    const redisUrl = this.config.getOrThrow<string>('REDIS_URL');
    this.worker = new Worker(
      AGENT_QUEUE_NAME,
      (job) => this.processJob(job),
      {
        connection: {
          url: redisUrl,
          maxRetriesPerRequest: null,
        },
        concurrency: 2,
        lockDuration: 300_000,
      },
    );
    this.worker.on('failed', (job, err) => {
      this.logger.error(`Job ${job?.id} failed`, err);
    });
  }

  async onModuleDestroy(): Promise<void> {
    await this.worker.close();
  }

  private async processJob(
    job: Job<{ taskId: string; userId: string; message: string }>,
  ): Promise<void> {
    const { taskId, message } = job.data;
    const channel = taskEventsChannel(taskId);
    const publish = async (payload: string) => {
      await this.redis.publish(channel, payload);
    };

    try {
      await this.tasks.update(
        { id: taskId },
        { status: AgentTaskStatus.Running },
      );

      const apiKey = this.config.get<string>('OPENAI_API_KEY');
      if (!apiKey) {
        const errMsg = 'OPENAI_API_KEY 未配置';
        await this.tasks.update(
          { id: taskId },
          { status: AgentTaskStatus.Failed, errorMessage: errMsg },
        );
        await publish(serializeAgentEvent({ type: 'error', message: errMsg }));
        await publish(serializeAgentEvent({ type: 'done' }));
        return;
      }

      const baseURL = this.config.get<string>('OPENAI_BASE_URL');
      const model = new ChatOpenAI({
        model: 'gpt-4o-mini',
        apiKey,
        temperature: 0.3,
        configuration: baseURL ? { baseURL } : undefined,
      });

      const stream = await model.stream([new HumanMessage(message)]);
      let full = '';
      for await (const chunk of stream) {
        const text = textFromChunk(chunk);
        if (text) {
          full += text;
          await publish(serializeAgentEvent({ type: 'token', text }));
        }
      }

      await this.tasks.update(
        { id: taskId },
        {
          status: AgentTaskStatus.Completed,
          resultSummary: full,
        },
      );
      await publish(
        serializeAgentEvent({ type: 'done', resultSummary: full }),
      );
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.logger.error(`Task ${taskId} error`, e);
      await this.tasks.update(
        { id: taskId },
        { status: AgentTaskStatus.Failed, errorMessage: msg },
      );
      await publish(serializeAgentEvent({ type: 'error', message: msg }));
      await publish(serializeAgentEvent({ type: 'done' }));
    }
  }
}
