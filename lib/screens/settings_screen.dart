import 'package:flutter/material.dart';

import 'transfer/transfer_bridge_screen.dart';
import '../services/activity_tag_storage.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/status_preset_storage.dart';

/// 内置主题色选项（名称 + Color.value）
const List<({String label, int value})> _builtInSeedColors = [
  (label: '紫色', value: 0xFF673AB7),
  (label: '蓝色', value: 0xFF2196F3),
  (label: '青色', value: 0xFF009688),
  (label: '绿色', value: 0xFF4CAF50),
  (label: '橙色', value: 0xFFFF9800),
  (label: '红色', value: 0xFFF44336),
  (label: '粉色', value: 0xFFE91E63),
];

/// 状态统计与提醒设置页（入口：主页右上角）
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _statUnitMinutes;
  late int _reminderIntervalMinutes;
  late TimeOfDay _quietStart;
  late TimeOfDay _quietEnd;
  late String? _quietDefaultPresetId;
  late ThemeMode _themeMode;
  late int _seedColorValue;
  late int _ideaContextMessageCount;
  late bool _hourlyPromptEnabled;

  @override
  void initState() {
    super.initState();
    final p = SettingsService.current;
    _statUnitMinutes = p.statUnitMinutes;
    _reminderIntervalMinutes = p.reminderIntervalMinutes;
    _quietStart = p.quietPeriodStart;
    _quietEnd = p.quietPeriodEnd;
    _quietDefaultPresetId = p.quietPeriodDefaultPresetId ?? 'builtin_resting';
    _themeMode = p.themeMode;
    _seedColorValue = p.seedColorValue;
    _ideaContextMessageCount = p.ideaContextMessageCount;
    _hourlyPromptEnabled = p.hourlyPromptEnabled;
  }

  Future<void> _saveTheme(ThemeMode? themeMode, int? seedColorValue) async {
    final next = themeMode ?? _themeMode;
    final color = seedColorValue ?? _seedColorValue;
    await SettingsService.save(
      SettingsService.current.copyWith(themeMode: next, seedColorValue: color),
    );
    if (themeMode != null) setState(() => _themeMode = next);
    if (seedColorValue != null) setState(() => _seedColorValue = color);
  }

  static Color _contrastColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.4 ? Colors.black87 : Colors.white;
  }

  Future<void> _save() async {
    await SettingsService.save(
      SettingsService.current.copyWith(
        statUnitMinutes: _statUnitMinutes,
        reminderIntervalMinutes: _reminderIntervalMinutes,
        quietPeriodStart: _quietStart,
        quietPeriodEnd: _quietEnd,
        quietPeriodDefaultPresetId: _quietDefaultPresetId,
        ideaContextMessageCount: _ideaContextMessageCount,
        hourlyPromptEnabled: _hourlyPromptEnabled,
      ),
    );
    NotificationService.scheduleHourlyPrompts();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置已保存')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: () async {
              await _save();
            },
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '主题',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '外观',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('跟随系统'),
                        icon: Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('浅色'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('深色'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {_themeMode},
                    onSelectionChanged: (Set<ThemeMode> selected) {
                      final mode = selected.first;
                      _saveTheme(mode, null);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '主题色',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _builtInSeedColors.map((e) {
                      final isSelected = _seedColorValue == e.value;
                      return Tooltip(
                        message: e.label,
                        child: Material(
                          color: Color(e.value),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _saveTheme(null, e.value),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        width: 3,
                                      )
                                    : null,
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      color: _contrastColor(Color(e.value)),
                                      size: 22,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 24),
          const Text(
            '想法',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('AI 助手会话上下文条数'),
            subtitle: Text(
              _ideaContextMessageCount == 0
                  ? '不发送历史消息，仅发送当前输入'
                  : '发送最近 $_ideaContextMessageCount 条消息作为上下文',
            ),
            trailing: DropdownButton<int>(
              value:
                  const [
                    0,
                    5,
                    10,
                    20,
                    30,
                    50,
                  ].contains(_ideaContextMessageCount)
                  ? _ideaContextMessageCount
                  : 10,
              items: const [
                DropdownMenuItem(value: 0, child: Text('0（不发送）')),
                DropdownMenuItem(value: 5, child: Text('5 条')),
                DropdownMenuItem(value: 10, child: Text('10 条')),
                DropdownMenuItem(value: 20, child: Text('20 条')),
                DropdownMenuItem(value: 30, child: Text('30 条')),
                DropdownMenuItem(value: 50, child: Text('50 条')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _ideaContextMessageCount = v);
              },
            ),
          ),
          ListTile(
            title: const Text('跨端对接'),
            subtitle: const Text('桌面生成二维码，手机扫码后临时上传数据'),
            trailing: const Icon(Icons.qr_code_2),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const TransferBridgeScreen(),
                ),
              );
            },
          ),
          const Divider(height: 24),
          const Text(
            '状态统计',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('统计单位'),
            subtitle: Text('每 $_statUnitMinutes 分钟为一个单位，可后期批量修改'),
            trailing: DropdownButton<int>(
              value: _statUnitMinutes,
              items: const [
                DropdownMenuItem(value: 15, child: Text('15 分钟')),
                DropdownMenuItem(value: 20, child: Text('20 分钟')),
                DropdownMenuItem(value: 30, child: Text('30 分钟')),
                DropdownMenuItem(value: 60, child: Text('60 分钟')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _statUnitMinutes = v);
              },
            ),
          ),
          const Divider(height: 24),
          const Text(
            '提醒',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('提醒间隔'),
            subtitle: Text('默认按 $_reminderIntervalMinutes 分钟（1 小时）维度提醒'),
            trailing: DropdownButton<int>(
              value: _reminderIntervalMinutes,
              items: const [
                DropdownMenuItem(value: 30, child: Text('30 分钟')),
                DropdownMenuItem(value: 60, child: Text('60 分钟')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _reminderIntervalMinutes = v);
              },
            ),
          ),
          SwitchListTile(
            title: const Text('定期问卷'),
            subtitle: const Text('每小时提醒填写上一时段状态'),
            value: _hourlyPromptEnabled,
            onChanged: (v) => setState(() => _hourlyPromptEnabled = v),
          ),
          const Divider(height: 24),
          const Text(
            '静默时段',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('静默开始'),
            subtitle: Text(
              '${_quietStart.hour.toString().padLeft(2, '0')}:${_quietStart.minute.toString().padLeft(2, '0')}（不提醒）',
            ),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _quietStart,
              );
              if (picked != null) setState(() => _quietStart = picked);
            },
          ),
          ListTile(
            title: const Text('静默结束'),
            subtitle: Text(
              '${_quietEnd.hour.toString().padLeft(2, '0')}:${_quietEnd.minute.toString().padLeft(2, '0')}（次日早，该时间起恢复提醒）',
            ),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _quietEnd,
              );
              if (picked != null) setState(() => _quietEnd = picked);
            },
          ),
          ListTile(
            title: const Text('活动标签管理'),
            subtitle: const Text('隐藏后不会在填写时显示'),
            trailing: const Icon(Icons.label_outline),
            onTap: () => _showTagManagement(context),
          ),
          ListTile(
            title: const Text('静默时段默认预设'),
            subtitle: const Text('该时段内不提醒，未记录时自动记为该预设'),
            trailing: Builder(
              builder: (context) {
                final presets = StatusPresetStorage.getAll();
                return DropdownButton<String>(
                  value: presets.any((p) => p.id == _quietDefaultPresetId)
                      ? _quietDefaultPresetId
                      : (presets.isNotEmpty ? presets.first.id : null),
                  items: presets
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(p.icon, size: 20, color: p.color),
                              const SizedBox(width: 8),
                              Text(p.name),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _quietDefaultPresetId = v);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTagManagement(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final tags = ActivityTagStorage.getAll(includeHidden: true);
            return AlertDialog(
              title: const Text('活动标签'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tags.length,
                  itemBuilder: (_, i) {
                    final t = tags[i];
                    return SwitchListTile(
                      title: Text(t.name),
                      subtitle: Text(t.hidden ? '已隐藏' : '可见'),
                      value: !t.hidden,
                      onChanged: (v) async {
                        await ActivityTagStorage.setHidden(t.name, !v);
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
