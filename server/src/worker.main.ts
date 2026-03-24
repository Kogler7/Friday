import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { WorkerModule } from './worker/worker.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.createApplicationContext(WorkerModule, {
    logger: ['error', 'warn', 'log'],
  });
  await app.init();
  console.log('Agent BullMQ worker started');
}

bootstrap().catch((err) => {
  console.error(err);
  process.exit(1);
});
