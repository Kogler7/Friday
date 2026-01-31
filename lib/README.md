# lib 目录说明

## 结构概览

```
lib/
├── main.dart                 # 应用入口
├── constants/                # 常量与配置
│   └── app_config.dart
├── models/                   # 数据模型（按领域归类）
│   ├── activity/            # 状态相关：工作/休息/娱乐、时段记录
│   │   ├── activity_state.dart
│   │   └── hourly_record.dart
│   ├── idea/                # 想法相关
│   │   └── chat_message.dart
│   ├── event/               # 事件/待办相关
│   │   └── todo_item.dart
│   └── settings/            # 设置相关
│       └── settings_preferences.dart
├── services/                 # 业务与存储服务
│   ├── storage_service.dart       # 状态时段存储
│   ├── settings_service.dart      # 设置持久化
│   ├── chat_storage_service.dart  # 想法记录存储
│   ├── todo_storage_service.dart  # 事件/待办存储
│   ├── notification_service.dart  # 本地通知
│   ├── hourly_prompt_service.dart # 整点提醒
│   ├── dev_mode_auth_service.dart # 开发者模式生物识别
│   ├── dev_sample_data.dart       # 开发示例数据（状态）
│   └── dev_todo_sample.dart       # 开发示例数据（待办）
├── screens/                  # 页面
│   ├── main_shell.dart      # 主导航壳（底部 Tab + 侧栏 Drawer）
│   ├── idea_screen.dart     # 想法
│   ├── event_screen.dart    # 事件
│   ├── status_screen.dart   # 状态（图表 + 小时明细）
│   ├── stats_screen.dart    # 统计（占位）
│   ├── smart_screen.dart    # 智能
│   ├── settings_screen.dart # 设置
│   ├── about_screen.dart    # 关于
│   ├── chat_screen.dart     # [已弃用，由 idea_screen 替代]
│   ├── home_screen.dart     # [已弃用，逻辑迁至 main_shell Drawer]
│   └── todo_screen.dart     # [已弃用，由 event_screen 替代]
└── widgets/                  # 可复用组件
    ├── daily_chart.dart           # 当日状态图表
    ├── hourly_prompt_dialog.dart  # 整点状态选择弹窗
    ├── chat_export_sheet.dart     # 想法导出
    ├── todo_edit_sheet.dart       # 事件编辑
    └── timeline/                  # 事件时间轴
        ├── constants.dart
        ├── models.dart
        ├── painters.dart
        ├── timeline.dart
        └── todo_timeline.dart
```

## 归类说明

- **models/** 按领域分子目录：`activity`（状态）、`idea`（想法）、`event`（事件）、`settings`（设置）。
- **services/** 保持扁平，按职责命名；开发/测试用服务以 `dev_` 前缀区分。
- **screens/** 保持扁平；已弃用页面保留在根下并标注，便于后续删除或迁移。
