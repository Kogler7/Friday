# API 总览

基准 URL：`http://<host>:<PORT>`（默认 `http://localhost:3000`）。  
除特别说明外，请求体为 **JSON**，响应体多为 **JSON**。

## 错误响应（Nest `HttpException`）

```json
{
  "statusCode": 400,
  "message": "...",
  "error": "Bad Request"
}
```

校验失败时 `message` 可能为**字符串数组**（字段级错误）。下文表格中的「业务 message」指 `message` 为字符串时的常见文案。

## JWT

- **签发**：注册、登录成功时由 `AuthService` 签发。
- **有效期**：7 天（`auth.module.ts` 中 `signOptions.expiresIn: '7d'`）。
- **Payload**：`sub` 为用户 UUID，`email` 为邮箱（与 `JwtStrategy` 一致）。
- **HTTP 校验**：`Authorization: Bearer <token>`；策略会按 `sub` 再查库，用户不存在则 401。

各需登录的接口见 [api-auth.md](./api-auth.md)、[api-agent.md](./api-agent.md)。

## 全局行为

- **校验**：`ValidationPipe` 启用 `whitelist: true`、`forbidNonWhitelisted: true`，未在 DTO 声明的字段会 400。
- **监听**：`0.0.0.0:<PORT>`，便于容器或局域网访问。
