import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AgentModule } from './agent/agent.module';
import { AppController } from './app.controller';
import { createTypeOrmOptions } from './database/typeorm.config';
import { RedisModule } from './redis/redis.module';
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => createTypeOrmOptions(config),
      inject: [ConfigService],
    }),
    RedisModule,
    UsersModule,
    AuthModule,
    AgentModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
