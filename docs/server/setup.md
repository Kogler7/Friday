# 环境与运行

## 环境变量

复制 `server/.env.example` 为 `server/.env` 并按环境修改。

| 变量 | 说明 |
|------|------|
| `DATABASE_URL` | PostgreSQL 连接串，例如 `postgresql://postgres:postgres@localhost:5432/friday` |
| `REDIS_URL` | Redis 连接串，例如 `redis://localhost:6379`（BullMQ + Pub/Sub） |
| `JWT_SECRET` | JWT 签名密钥；**长度至少 16**（建议 ≥32），生产务必使用强随机串 |
| `PORT` | 监听端口，默认 `3000` |
| `OPENAI_API_KEY` | OpenAI 兼容 API Key；**仅 Worker 进程读取**，用于 LangChain `ChatOpenAI` |
| `OPENAI_BASE_URL` | 可选，自定义兼容网关 Base URL |
| `DATABASE_SYNC` | 为 `true` 时开启 TypeORM `synchronize`；**生产环境应设为 false**，改用手写 migration |

启动时若 `JWT_SECRET` 缺失或过短，**API 进程**会直接抛出错误并退出。

未配置 `OPENAI_API_KEY` 时，Worker 仍可启动，但执行到模型调用会将任务标记为 `failed` 并推送错误事件。

## Docker（本地依赖）

```bash
docker compose -f server/docker-compose.yml up -d
```

默认：PostgreSQL 本机 **5432**，Redis 本机 **6379**，数据库名 **friday**。

## npm 命令

在 `server/` 目录下：

| 命令 | 说明 |
|------|------|
| `npm install` | 安装依赖 |
| `npm run start:dev` | API 开发模式（watch） |
| `npm run build` | 编译到 `dist/` |
| `npm run start:prod` | `node dist/main.js`（需先 build） |
| `npm run start:worker` | `node dist/worker.main.js`（消费 Agent 队列） |
| `npm run start:worker:dev` | `tsx watch` 开发模式跑 Worker |

跑 **Agent 长任务**时需**同时**启动 API 与 Worker，并配置 `OPENAI_API_KEY`（真实调用模型时）。
