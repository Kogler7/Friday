import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Queue } from 'bullmq';
import { RedisModule } from '../redis/redis.module';
import { AgentTask } from './agent-task.entity';
import { AGENT_QUEUE_NAME } from './agent.constants';
import { AGENT_QUEUE } from './agent-queue.token';
import { AgentController } from './agent.controller';
import { AgentStreamController } from './agent-stream.controller';
import { AgentTasksService } from './agent-tasks.service';

@Module({
  imports: [ConfigModule, RedisModule, TypeOrmModule.forFeature([AgentTask])],
  controllers: [AgentController, AgentStreamController],
  providers: [
    {
      provide: AGENT_QUEUE,
      useFactory: (config: ConfigService) => {
        return new Queue(AGENT_QUEUE_NAME, {
          connection: {
            url: config.getOrThrow<string>('REDIS_URL'),
            maxRetriesPerRequest: null,
          },
        });
      },
      inject: [ConfigService],
    },
    AgentTasksService,
  ],
  exports: [AgentTasksService, AGENT_QUEUE],
})
export class AgentModule {}
