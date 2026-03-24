# 跨端存储重构进展（进行中）

## 已完成
- 新增统一存储接口层：`StatusRepository` / `IdeaRepository` / `TodoRepository`
- 新增仓储门面：`RepositoryFacade`，支持 `local` 与 `remote` 模式切换
- 手机端本地实现：`Local*Repository`（新格式写入，保留旧数据读取回退）
- 桌面端远端实现：`Remote*Repository` + `InMemoryCache`（仅内存，不落盘）
- 关键业务页面/服务迁移到统一 API（`idea/event/stats/timeline` 等）
- 增加跨端对接 UI 入口：设置页 -> `跨端对接`
- 增加传输协议客户端：`createChannel / pushData / pullData / expireChannel`
- 增加自动迁移入口：`LegacyAutoMigrationService`（默认关闭）

## 当前行为说明
- 桌面端数据来自远端拉取后写入内存，结束会话会清空内存数据。
- 手机端保留旧数据读取逻辑，新链路默认写入 `v2` key。
- 旧数据不会被直接覆盖，后续可灰度开启旧 -> 新自动迁移。

## 尚未完成
- `server/` 中转服务未最终落地并联调完成（客户端已预留接口）。
- 尚未完成生产级安全增强（例如 HTTPS、更严格 token 策略、设备绑定）。
- 尚未完成完整自动化端到端测试（当前以模型层与模块分析为主）。

## 局域网联调建议
- 推荐由桌面机启动中转服务，手机与桌面连接同一 Wi-Fi。
- 移动端与桌面端均使用 `http://<桌面局域网IP>:<端口>` 访问中转服务。
- 注意：手机端不能使用 `127.0.0.1` 访问桌面服务。
