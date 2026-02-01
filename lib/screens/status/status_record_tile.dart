import 'package:flutter/material.dart';

import '../../models/activity/activity_state.dart';
import '../../models/activity/hourly_record.dart';
import '../../services/settings_service.dart';

/// 状态页小时记录卡片：图标、时间范围、状态名称
class StatusRecordTile extends StatelessWidget {
  final HourlyRecord record;

  const StatusRecordTile({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final r = record;
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
  }
}
