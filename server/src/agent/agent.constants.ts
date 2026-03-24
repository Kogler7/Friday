/** BullMQ 队列名（API 入队与 Worker 消费需一致） */
export const AGENT_QUEUE_NAME = 'agent-tasks';

/** Redis Pub/Sub：Worker 发布、API SSE 订阅 */
export function taskEventsChannel(taskId: string): string {
  return `task:${taskId}:events`;
}
