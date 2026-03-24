import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { createTypeOrmOptions } from '../database/typeorm.config';
import { RedisModule } from '../redis/redis.module';
import { AgentTask } from '../agent/agent-task.entity';
import { AgentWorkerService } from './agent-worker.service';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => createTypeOrmOptions(config),
      inject: [ConfigService],
    }),
    RedisModule,
    TypeOrmModule.forFeature([AgentTask]),
  ],
  providers: [AgentWorkerService],
})
export class WorkerModule {}
