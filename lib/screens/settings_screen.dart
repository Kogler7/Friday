import 'package:flutter/material.dart';

import '../models/activity_state.dart';
import '../models/settings_preferences.dart';
import '../services/settings_service.dart';

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
  late ActivityState _quietDefaultState;

  @override
  void initState() {
    super.initState();
    final p = SettingsService.current;
    _statUnitMinutes = p.statUnitMinutes;
    _reminderIntervalMinutes = p.reminderIntervalMinutes;
    _quietStart = p.quietPeriodStart;
    _quietEnd = p.quietPeriodEnd;
    _quietDefaultState = p.quietPeriodDefaultState;
  }

  Future<void> _save() async {
    await SettingsService.save(SettingsPreferences(
      statUnitMinutes: _statUnitMinutes,
      reminderIntervalMinutes: _reminderIntervalMinutes,
      quietPeriodStart: _quietStart,
      quietPeriodEnd: _quietEnd,
      quietPeriodDefaultState: _quietDefaultState,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('状态与提醒设置'),
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
            '状态统计',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
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
          const Divider(height: 24),
          const Text(
            '静默时段',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
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
            title: const Text('静默时段默认状态'),
            subtitle: const Text('该时段内不提醒，未记录时自动记为该状态'),
            trailing: DropdownButton<ActivityState>(
              value: _quietDefaultState,
              items: ActivityState.values
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.displayName),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _quietDefaultState = v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
