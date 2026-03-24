import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Queue } from 'bullmq';
import { Repository } from 'typeorm';
import { REDIS_CLIENT } from '../redis/redis.tokens';
import type IORedis from 'ioredis';
import { AgentTask } from './agent-task.entity';
import { AgentTaskStatus } from './agent-task-status.enum';
import { AGENT_QUEUE } from './agent-queue.token';
import { AGENT_QUEUE_NAME } from './agent.constants';

@Injectable()
export class AgentTasksService {
  constructor(
    @InjectRepository(AgentTask)
    private readonly repo: Repository<AgentTask>,
    @Inject(AGENT_QUEUE) private readonly queue: Queue,
    @Inject(REDIS_CLIENT) private readonly redis: IORedis,
  ) {}

  async createAndEnqueue(
    userId: string,
    message: string,
  ): Promise<AgentTask> {
    const task = this.repo.create({
      userId,
      status: AgentTaskStatus.Queued,
      input: { message },
      bullJobId: null,
      resultSummary: null,
      errorMessage: null,
    });
    await this.repo.save(task);
    const job = await this.queue.add(
      'run',
      { taskId: task.id, userId, message },
      {
        jobId: task.id,
        removeOnComplete: true,
        removeOnFail: false,
        attempts: 2,
        backoff: { type: 'exponential', delay: 5000 },
      },
    );
    task.bullJobId = String(job.id);
    await this.repo.save(task);
    return task;
  }

  async findOwned(taskId: string, userId: string): Promise<AgentTask | null> {
    return this.repo.findOne({ where: { id: taskId, userId } });
  }

  async requireOwned(taskId: string, userId: string): Promise<AgentTask> {
    const task = await this.findOwned(taskId, userId);
    if (!task) {
      throw new NotFoundException('任务不存在');
    }
    return task;
  }

  /** 供 WebSocket 取消：尝试移除队列中的任务 */
  async cancelQueuedJob(task: AgentTask): Promise<boolean> {
    if (!task.bullJobId) {
      return false;
    }
    const job = await this.queue.getJob(task.bullJobId);
    if (!job) {
      return false;
    }
    try {
      await job.remove();
      return true;
    } catch {
      return false;
    }
  }

  duplicateSubscriber(): IORedis {
    return this.redis.duplicate();
  }
}
