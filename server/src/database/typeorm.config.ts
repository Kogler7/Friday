import type { TypeOrmModuleOptions } from '@nestjs/typeorm';
import type { ConfigService } from '@nestjs/config';
import { AgentTask } from '../agent/agent-task.entity';
import { User } from '../users/user.entity';

export function createTypeOrmOptions(
  config: ConfigService,
): TypeOrmModuleOptions {
  return {
    type: 'postgres',
    url: config.getOrThrow<string>('DATABASE_URL'),
    entities: [User, AgentTask],
    synchronize: config.get<string>('DATABASE_SYNC') === 'true',
  };
}
