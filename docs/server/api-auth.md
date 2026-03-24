# 认证与健康检查

以下路径基准与错误格式见 [api-overview.md](./api-overview.md)。

---

## GET `/health`

存活检查，**无需认证**。

**响应 200**

```json
{ "ok": true }
```

---

## POST `/auth/register`

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

## POST `/auth/login`

登录。

**请求体**

| 字段 | 类型 | 规则 |
|------|------|------|
| `email` | string | 合法邮箱，trim + 小写 |
| `password` | string | 非空（最小长度 1） |

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

## GET `/me`

当前登录用户（需有效 JWT，且用户仍在数据库中存在）。

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
