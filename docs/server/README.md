# Friday 后端（`server/`）文档

仓库内 NestJS 后端说明与接口契约，与 [server/](../../server/) 源码保持一致。若代码有变更，请同步更新本目录下对应文件。

## 文档索引

| 文档 | 内容 |
|------|------|
| [architecture.md](./architecture.md) | 技术栈、目录结构、模块关系、Agent 数据流 |
| [setup.md](./setup.md) | 环境变量、Docker、npm 命令、本地联调 |
| [data-model.md](./data-model.md) | `users`、`agent_tasks` 表与实体引用 |
| [api-overview.md](./api-overview.md) | 基准 URL、错误格式、JWT 约定、全局行为 |
| [api-auth.md](./api-auth.md) | `/health`、注册、登录、`/me` |
| [api-agent.md](./api-agent.md) | Agent 任务、SSE 流式、WebSocket 信令、事件 payload |

## 快速定位

- 只跑登录与用户：**api-auth.md** + **api-overview.md**
- 跑长任务与流式：**setup.md**（需同时起 API + Worker）+ **api-agent.md**
