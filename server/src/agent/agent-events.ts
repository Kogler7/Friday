/** SSE / Pub/Sub 事件负载（JSON 字符串传输） */
export type AgentStreamEvent =
  | { type: 'token'; text: string }
  | { type: 'done'; resultSummary?: string }
  | { type: 'error'; message: string };

export function serializeAgentEvent(event: AgentStreamEvent): string {
  return JSON.stringify(event);
}
