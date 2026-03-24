import {
  Controller,
  Get,
  NotFoundException,
  Param,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import type { FastifyReply, FastifyRequest } from 'fastify';
import { CurrentUser, type RequestUser } from '../common/current-user.decorator';
import { AgentTaskStatus } from './agent-task-status.enum';
import { AgentTasksService } from './agent-tasks.service';
import { serializeAgentEvent } from './agent-events';
import { taskEventsChannel } from './agent.constants';

@Controller('agent')
@UseGuards(AuthGuard('jwt'))
export class AgentStreamController {
  constructor(private readonly tasks: AgentTasksService) {}

  @Get('tasks/:id/stream')
  async stream(
    @Param('id') taskId: string,
    @CurrentUser() user: RequestUser,
    @Req() req: FastifyRequest,
    @Res({ passthrough: false }) res: FastifyReply,
  ): Promise<void> {
    const task = await this.tasks.findOwned(taskId, user.id);
    if (!task) {
      throw new NotFoundException('任务不存在');
    }

    res.raw.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
      'X-Accel-Buffering': 'no',
    });

    if (task.status === AgentTaskStatus.Completed) {
      res.raw.write(
        `data: ${serializeAgentEvent({ type: 'done', resultSummary: task.resultSummary ?? undefined })}\n\n`,
      );
      res.raw.end();
      return;
    }
    if (task.status === AgentTaskStatus.Failed) {
      res.raw.write(
        `data: ${serializeAgentEvent({ type: 'error', message: task.errorMessage ?? 'failed' })}\n\n`,
      );
      res.raw.write(`data: ${serializeAgentEvent({ type: 'done' })}\n\n`);
      res.raw.end();
      return;
    }

    const sub = this.tasks.duplicateSubscriber();
    const channel = taskEventsChannel(taskId);
    await sub.subscribe(channel);

    const onMessage = (_ch: string, message: string) => {
      res.raw.write(`data: ${message}\n\n`);
    };
    sub.on('message', onMessage);

    const cleanup = () => {
      sub.off('message', onMessage);
      void sub.unsubscribe(channel);
      void sub.quit();
      if (!res.raw.writableEnded) {
        res.raw.end();
      }
    };

    req.raw.on('close', cleanup);
  }
}
