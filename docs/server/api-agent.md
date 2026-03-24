# Agent 任务、SSE 与 WebSocket

需 **JWT** 的接口在请求头携带：`Authorization: Bearer <JWT>`（WebSocket 例外见下文）。  
基准 URL 与错误格式见 [api-overview.md](./api-overview.md)。  
数据模型见 [data-model.md](./data-model.md)。运行要求见 [setup.md](./setup.md)。

---

## POST `/agent/tasks`

创建 Agent 长任务并入 BullMQ 队列。**需 Worker 进程消费**，见 [setup.md](./setup.md)。

**请求体**

| 字段 | 类型 | 规则 |
|------|------|------|
| `message` | string | 非空，最大约 32000 字符 |

**响应 201**

```json
{
  "id": "<task-uuid>",
  "status": "queued",
  "createdAt": "2025-01-01T00:00:00.000Z"
}
```

---

## GET `/agent/tasks/:id`

查询任务状态与结果摘要；任务必须属于当前用户。

**响应 200**

```json
{
  "id": "<uuid>",
  "status": "queued",
  "input": { "message": "..." },
  "resultSummary": null,
  "errorMessage": null,
  "createdAt": "...",
  "updatedAt": "..."
}
```

`status` 为 `completed` 时 `resultSummary` 为模型输出全文；`failed` 时见 `errorMessage`。

---

## GET `/agent/tasks/:id/stream`

**Server-Sent Events**，订阅 Worker 发布到 Redis 的实时事件。需 JWT：`Authorization: Bearer <JWT>`。

行为说明：

- 若任务已 **completed**：直接返回一条 `data:`，内容为 `done` 事件（带 `resultSummary`），随后结束。
- 若已 **failed**：先推送 `error`，再推送 `done`，随后结束。
- 若 **queued** / **running**：订阅频道 `task:<id>:events`，将 Redis 消息原样作为 SSE 的 `data:` 行写出（每条为 JSON 字符串）。

### 事件 payload（JSON）

| `type` | 说明 |
|--------|------|
| `token` | `{ "type": "token", "text": "<chunk>" }`，模型流式分片 |
| `error` | `{ "type": "error", "message": "..." }` |
| `done` | `{ "type": "done", "resultSummary"?: "..." }`，表示该任务流结束 |

客户端应在收到 `done` 后关闭连接或停止读取。

---

## WebSocket `GET /agent/ws?token=<JWT>`

用于**信令**，**不**承载模型 token 流（与 SSE 分工，避免重复）。

连接前将登录获得的 JWT 置于 query：`token`。

### 客户端 → 服务端

取消排队中的任务（若任务已开始执行，移除队列可能失败，以返回为准）：

```json
{ "type": "cancel", "taskId": "<uuid>" }
```

### 服务端 → 客户端

成功：

```json
{ "type": "cancel_result", "taskId": "<uuid>", "removed": true }
```

错误示例：

```json
{ "type": "error", "message": "任务不存在" }
```
