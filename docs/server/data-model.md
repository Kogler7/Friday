# 数据模型

实体与迁移请以 `server/src` 为准；生产环境在关闭 `DATABASE_SYNC` 后应使用 **migration** 管理表结构。

## `users`

| 字段（数据库列） | 类型 | 说明 |
|------------------|------|------|
| `id` | UUID | 主键，默认生成 |
| `email` | 字符串 | 唯一，请求中会 trim 并转小写 |
| `password_hash` | 字符串 | bcrypt 哈希，不对外返回 |
| `created_at` | 时间戳 | 创建时间 |

实体：[server/src/users/user.entity.ts](../../server/src/users/user.entity.ts)

## `agent_tasks`

| 字段（数据库列） | 类型 | 说明 |
|------------------|------|------|
| `id` | UUID | 主键 |
| `user_id` | UUID | 外键 → `users.id`，级联删除 |
| `status` | 枚举字符串 | `queued` / `running` / `completed` / `failed` |
| `bull_job_id` | 字符串，可空 | BullMQ Job Id |
| `input` | JSON | 当前为 `{ "message": string }` |
| `result_summary` | 文本，可空 | 模型完整输出（流式拼接结果） |
| `error_message` | 文本，可空 | 失败原因 |
| `created_at` / `updated_at` | 时间戳 | 创建/更新时间 |

实体：[server/src/agent/agent-task.entity.ts](../../server/src/agent/agent-task.entity.ts)
