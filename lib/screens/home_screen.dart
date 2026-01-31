import 'package:flutter/material.dart';

import '../constants/app_config.dart';
import '../models/activity_state.dart';
import '../models/hourly_record.dart';
import '../services/dev_sample_data.dart';
import '../services/hourly_prompt_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/daily_chart.dart';
import '../widgets/hourly_prompt_dialog.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  List<HourlyRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
    HourlyPromptService.setShowPrompt((hourToRecord) {
      if (!mounted) return;
      // 延后到首帧之后，避免在 initState 中调用 showDialog 导致 context 尚未就绪
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showHourlyPromptDialog(
          context,
          hourStart: hourToRecord,
          onTimeout: () => _loadRecords(),
        );
        _loadRecords();
      });
    });
    HourlyPromptService.start();
    _checkNotificationLaunch();
  }

  void _checkNotificationLaunch() {
    final hour = NotificationService.pendingHourToRecord;
    if (hour == null || !mounted) return;
    NotificationService.clearPendingHour();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showHourlyPromptDialog(
        context,
        hourStart: hour,
        onTimeout: () => _loadRecords(),
      );
      _loadRecords();
    });
  }

  @override
  void dispose() {
    HourlyPromptService.stop();
    super.dispose();
  }

  void _loadRecords() {
    if (!mounted) return;
    setState(() {
      _records = StorageService.getRecordsForDate(_selectedDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PlanPlus · 任务规划'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '状态与提醒设置',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          if (kIsDevMode)
            IconButton(
              icon: const Icon(Icons.science),
              tooltip: '开发：填充示例数据',
              onPressed: () async {
                await DevSampleData.insertSampleData();
                _loadRecords();
              },
            ),
          if (kIsDevMode)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '开发：清除今日/昨日示例',
              onPressed: () async {
                await DevSampleData.clearSampleDataForTodayAndYesterday();
                _loadRecords();
              },
            ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                  _records = StorageService.getRecordsForDate(_selectedDate);
                });
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadRecords(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isToday ? '今天 $dateStr' : dateStr,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DailyChart(records: _records, date: _selectedDate),
              const SizedBox(height: 24),
              if (_records.isNotEmpty) ...[
                Text(
                  '小时明细',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ..._records.map((r) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        r.state == ActivityState.working
                            ? Icons.work
                            : r.state == ActivityState.resting
                                ? Icons.bedtime
                                : Icons.games,
                        color: r.state == ActivityState.working
                            ? Colors.blue
                            : r.state == ActivityState.resting
                                ? Colors.orange
                                : Colors.green,
                      ),
                      title: Text(r.displayTimeRange),
                      subtitle: Text(r.state.displayName),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
