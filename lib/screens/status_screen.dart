import 'package:flutter/material.dart';

import '../constants/app_config.dart';
import '../models/activity/activity_state.dart';
import '../models/activity/hourly_record.dart';
import '../services/dev_sample_data.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../widgets/daily_chart.dart';

/// 状态页：按日查看工作/休息/娱乐分布与小时明细
class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  DateTime _selectedDate = DateTime.now();
  List<HourlyRecord> _records = [];
  bool _chartReady = false;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _chartReady = true);
    });
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
      body: RefreshIndicator(
        onRefresh: () async => _loadRecords(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isToday ? '今天 $dateStr' : dateStr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (kIsDevMode)
                    IconButton(
                      icon: const Icon(Icons.science),
                      tooltip: '填充示例数据',
                      onPressed: () async {
                        await DevSampleData.insertSampleData();
                        _loadRecords();
                      },
                    ),
                  if (kIsDevMode)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep),
                      tooltip: '清除示例',
                      onPressed: () async {
                        await DevSampleData.clearSampleDataForTodayAndYesterday();
                        _loadRecords();
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    tooltip: '选择日期',
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
              const SizedBox(height: 16),
              RepaintBoundary(
                child: _chartReady
                    ? DailyChart(records: _records, date: _selectedDate)
                    : const SizedBox(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
              ),
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
                      title: Text(r.displayTimeRange(unitMinutes: SettingsService.current.statUnitMinutes)),
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
