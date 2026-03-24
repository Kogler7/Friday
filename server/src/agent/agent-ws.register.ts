import type { RawData } from 'ws';
import { JwtService } from '@nestjs/jwt';
import type { NestFastifyApplication } from '@nestjs/platform-fastify';
import fastifyWebsocket from '@fastify/websocket';
import { AgentTasksService } from './agent-tasks.service';

function rawDataToString(raw: RawData): string {
  if (typeof raw === 'string') return raw;
  if (Buffer.isBuffer(raw)) return raw.toString('utf8');
  if (Array.isArray(raw)) return Buffer.concat(raw).toString('utf8');
  return Buffer.from(new Uint8Array(raw)).toString('utf8');
}

export async function registerAgentWebSocket(
  app: NestFastifyApplication,
): Promise<void> {
  const fastify = app.getHttpAdapter().getInstance();
  await fastify.register(fastifyWebsocket);

  const jwt = app.get(JwtService);
  const tasks = app.get(AgentTasksService);

  fastify.get(
    '/agent/ws',
    { websocket: true },
    (socket, req) => {
      const q = req.query as { token?: string };
      const token = q.token;
      if (!token) {
        socket.close(1008, 'missing token');
        return;
      }
      let userId: string;
      try {
        const payload = jwt.verify<{ sub: string }>(token);
        userId = payload.sub;
      } catch {
        socket.close(1008, 'invalid token');
        return;
      }

      socket.on('message', async (raw: RawData) => {
        const text = rawDataToString(raw);
        try {
          const msg = JSON.parse(text) as { type?: string; taskId?: string };
          if (msg.type === 'cancel' && msg.taskId) {
            const task = await tasks.findOwned(msg.taskId, userId);
            if (!task) {
              socket.send(
                JSON.stringify({ type: 'error', message: '任务不存在' }),
              );
              return;
            }
            const removed = await tasks.cancelQueuedJob(task);
            socket.send(
              JSON.stringify({
                type: 'cancel_result',
                taskId: msg.taskId,
                removed,
              }),
            );
          }
        } catch {
          socket.send(
            JSON.stringify({ type: 'error', message: 'invalid message' }),
          );
        }
      });
    },
  );
}
