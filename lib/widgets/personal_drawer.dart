import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/agent/llm_agent.dart';
import '../screens/agent/agent_management_screen.dart';
import '../screens/agent/ai_settings_screen.dart';
import '../screens/settings_screen.dart';
import '../services/agent_storage.dart';
import '../services/settings_service.dart';

/// 个人侧边栏 Drawer（AI 管理、设置、关于等）
/// 抽离为独立模块，便于扩展更多入口
class PersonalDrawer extends StatefulWidget {
  const PersonalDrawer({
    super.key,
    required this.onAboutTap,
    required this.onDevModeEntry,
  });

  final VoidCallback onAboutTap;
  final Future<void> Function() onDevModeEntry;

  @override
  State<PersonalDrawer> createState() => _PersonalDrawerState();
}

class _PersonalDrawerState extends State<PersonalDrawer> {
  String? _nickname;

  @override
  void initState() {
    super.initState();
    _nickname = SettingsService.current.nickname;
  }

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _nickname ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置昵称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入你的昵称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final trimmed = result.trim();
      await SettingsService.save(
        SettingsService.current.copyWith(
          nickname: trimmed.isEmpty ? null : trimmed,
          clearNickname: trimmed.isEmpty,
        ),
      );
      setState(() => _nickname = trimmed.isEmpty ? null : trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = _nickname?.isNotEmpty == true ? _nickname! : 'Friday';

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 头部个人信息区（点击可编辑昵称）
            InkWell(
              onTap: _editNickname,
              child: DrawerHeader(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: colorScheme.primaryContainer,
                      child: _nickname?.isNotEmpty == true
                          ? Text(
                              _nickname![0].toUpperCase(),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : Icon(
                              Icons.person_outline,
                              size: 48,
                              color: colorScheme.onPrimaryContainer,
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    Text(
                      '点击修改昵称',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 功能分组区
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  // AI 功能组
                  _AiMenuGroup(),
                  const SizedBox(height: 8),
                  // 通用功能组
                  _GeneralMenuGroup(
                    onAboutTap: widget.onAboutTap,
                    onDevModeEntry: widget.onDevModeEntry,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AI 相关功能组
class _AiMenuGroup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4, top: 8),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'AI',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('API 接入'),
                subtitle: const Text('配置接入点与密钥'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const AiSettingsScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.smart_toy_outlined),
                title: const Text('Agent 管理'),
                subtitle: const Text('管理自定义 Agent'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const AgentManagementScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _DefaultAgentTile(),
            ],
          ),
        ),
      ],
    );
  }
}

/// 默认 Agent 选择入口
class _DefaultAgentTile extends StatefulWidget {
  @override
  State<_DefaultAgentTile> createState() => _DefaultAgentTileState();
}

class _DefaultAgentTileState extends State<_DefaultAgentTile> {
  LlmAgent? _defaultAgent;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _defaultAgent = AgentStorage.getDefault();
    });
  }

  Future<void> _selectDefaultAgent() async {
    final agents = AgentStorage.getAll();
    if (agents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可用 Agent')),
      );
      return;
    }

    final selected = await showDialog<LlmAgent>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择默认 Agent'),
        children: agents.map((agent) {
          final isDefault = agent.id == _defaultAgent?.id;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, agent),
            child: Row(
              children: [
                Icon(
                  isDefault ? Icons.check_circle : Icons.circle_outlined,
                  color: isDefault
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(agent.name),
                      if (agent.description != null)
                        Text(
                          agent.description!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected != null && mounted) {
      await AgentStorage.setDefault(selected.id);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已将「${selected.name}」设为默认')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.check_circle_outline),
      title: const Text('默认 Agent'),
      subtitle: Text(_defaultAgent?.name ?? '未设置'),
      onTap: _selectDefaultAgent,
    );
  }
}

/// 通用功能组
class _GeneralMenuGroup extends StatelessWidget {
  const _GeneralMenuGroup({
    required this.onAboutTap,
    required this.onDevModeEntry,
  });

  final VoidCallback onAboutTap;
  final Future<void> Function() onDevModeEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4, top: 8),
          child: Row(
            children: [
              Icon(
                Icons.tune,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '通用',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('设置'),
                subtitle: const Text('主题、提醒与统计'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('关于'),
                subtitle: const Text('版本与开发者信息'),
                onTap: onAboutTap,
                onLongPress: kDebugMode
                    ? () async {
                        Navigator.pop(context);
                        await onDevModeEntry();
                      }
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
