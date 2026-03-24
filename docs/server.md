# Friday 后端服务（`server/`）说明

本文档描述仓库内 NestJS 后端的**目录结构**、**环境配置**与 **HTTP 接口**，与当前代码保持一致。代码根目录：`server/`。

## 技术栈

| 类别 | 选型 |
|------|------|
| 框架 | NestJS 10 |
| HTTP 适配器 | Fastify（`@nestjs/platform-fastify`） |
| 数据库 | PostgreSQL，经 TypeORM 访问 |
| 认证 | JWT（`@nestjs/jwt`）+ Passport JWT（`passport-jwt`） |
| 密码 | bcryptjs（cost 12） |
| 校验 | class-validator / class-transformer（全局 `ValidationPipe`） |

## 目录结构

```
server/
├── docker-compose.yml      # 本地 PostgreSQL 16
├── .env.example            # 环境变量模板
├── nest-cli.json
├── package.json
├── tsconfig.json
├── tsconfig.build.json
└── src/
    ├── main.ts             # 入口：Fastify、全局校验、JWT_SECRET 校验、监听端口
    ├── app.module.ts       # 根模块：Config、TypeORM、Users、Auth
    ├── app.controller.ts   # GET /health
    ├── common/
    │   └── current-user.decorator.ts   # @CurrentUser()，取 JWT 校验后的用户
    ├── users/
    │   ├── user.entity.ts  # users 表实体
    │   ├── users.service.ts
    │   └── users.module.ts
    └── auth/
        ├── auth.module.ts  # JwtModule、Passport、AuthController、ProfileController
        ├── auth.service.ts # 注册、登录、签发 token
        ├── auth.controller.ts    # POST /auth/register、POST /auth/login
        ├── profile.controller.ts # GET /me（需 JWT）
        ├── jwt.strategy.ts       # Bearer JWT 校验，并查库确认用户仍存在
        └── dto/
            ├── register.dto.ts
            └── login.dto.ts
```

### 模块关系（简要）

- `AppModule` 注册全局 `ConfigModule`，用 `DATABASE_URL` 连接 PostgreSQL；`DATABASE_SYNC=true` 时由 TypeORM 根据实体**同步表结构**（仅建议本地使用）。
- `UsersModule` 提供 `User` 仓储与 `UsersService`。
- `AuthModule` 依赖 `UsersModule`，提供注册/登录与 JWT 策略；`ProfileController` 挂在根路径，提供 `/me`。

## 环境变量

复制 `server/.env.example` 为 `server/.env` 并按环境修改。

| 变量 | 说明 |
|------|------|
| `DATABASE_URL` | PostgreSQL 连接串，例如 `postgresql://postgres:postgres@localhost:5432/friday` |
| `JWT_SECRET` | JWT 签名密钥；**长度至少 16**（建议 ≥32），生产务必使用强随机串 |
| `PORT` | 监听端口，默认 `3000` |
| `DATABASE_SYNC` | 为 `true` 时开启 TypeORM `synchronize`；**生产环境应设为 false**，改用手写 migration |

启动时若 `JWT_SECRET` 缺失或过短，进程会直接抛出错误并退出。

## 运行命令

在 `server/` 目录下：

| 命令 | 说明 |
|------|------|
| `npm install` | 安装依赖 |
| `npm run start:dev` | 开发模式（watch） |
| `npm run build` | 编译到 `dist/` |
| `npm run start:prod` | 运行 `node dist/main.js`（需先 build） |

本地数据库可执行：`docker compose -f server/docker-compose.yml up -d`（默认暴露本机 `5432`，库名 `friday`）。

## 数据模型：`users`

| 字段（数据库列） | 类型 | 说明 |
|------------------|------|------|
| `id` | UUID | 主键，默认生成 |
| `email` | 字符串 | 唯一，请求中会 trim 并转小写 |
| `password_hash` | 字符串 | bcrypt 哈希，不对外返回 |
| `created_at` | 时间戳 | 创建时间 |

实体定义见：`server/src/users/user.entity.ts`。

## HTTP 接口

基准 URL：`http://<host>:<PORT>`（默认 `http://localhost:3000`）。  
请求体均为 **JSON**，响应体除说明外多为 **JSON**。

Nest 默认对 `HttpException` 返回形如：

```json
{
  "statusCode": 400,
  "message": "...",
  "error": "Bad Request"
}
```

校验失败时 `message` 可能为字符串数组（字段错误列表）。下面表格中的「业务 message」指 `message` 字段的常见字符串形式。

---

### GET `/health`

存活检查，无需认证。

**响应 200**

```json
{ "ok": true }
```

---

### POST `/auth/register`

用户注册；成功后返回 JWT 与公开用户信息。

**请求体**

| 字段 | 类型 | 规则 |
|------|------|------|
| `email` | string | 合法邮箱，trim + 小写 |
| `password` | string | 至少 8 位 |

**响应 201**

```json
{
  "token": "<JWT>",
  "user": {
    "id": "<uuid>",
    "email": "user@example.com"
  }
}
```

**常见错误**

| statusCode | 说明 |
|------------|------|
| 400 | 校验失败（邮箱格式、密码长度、多余字段等） |
| 409 | 邮箱已存在（message：`该邮箱已注册`） |

---

### POST `/auth/login`

登录。

**请求体**

| 字段 | 类型 | 规则 |
|------|------|------|
| `email` | string | 合法邮箱，trim + 小写 |
| `password` | string | 非空（最小长度 1，由 DTO 校验） |

**响应 200**

```json
{
  "token": "<JWT>",
  "user": {
    "id": "<uuid>",
    "email": "user@example.com"
  }
}
```

**常见错误**

| statusCode | 说明 |
|------------|------|
| 400 | 校验失败 |
| 401 | 邮箱不存在或密码错误（message：`邮箱或密码错误`） |

---

### GET `/me`

获取当前登录用户（需有效 JWT，且用户仍在数据库中存在）。

**请求头**

| 头 | 值 |
|----|-----|
| `Authorization` | `Bearer <JWT>` |

**响应 200**

```json
{
  "id": "<uuid>",
  "email": "user@example.com"
}
```

**常见错误**

| statusCode | 说明 |
|------------|------|
| 401 | 未带 Token、Token 无效/过期、或用户已被删除 |

---

## JWT 说明

- **签发**：注册、登录成功时由 `AuthService` 签发。
- **有效期**：7 天（`auth.module.ts` 中 `signOptions.expiresIn: '7d'`）。
- **Payload（claims）**：`sub` 为用户 UUID，`email` 为邮箱字符串（与 `JwtStrategy` 校验逻辑一致）。
- **校验**：`Authorization: Bearer <token>`；策略会再次按 `sub` 查询数据库，用户不存在则 401。

## 全局行为摘要

- **校验**：`whitelist: true`、`forbidNonWhitelisted: true`，未在 DTO 声明的字段会触发 400。
- **监听**：`0.0.0.0:<PORT>`，便于容器或局域网访问。

---

文档版本与代码同步时以 `server/src` 为准；若接口有变更，请同时更新本文件。
