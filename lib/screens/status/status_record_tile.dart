import 'package:flutter/material.dart';

import '../../models/activity/hourly_record.dart';
import '../../services/activity_tag_storage.dart';
import '../../services/status_preset_storage.dart';

/// 状态页小时记录卡片：时间轴式布局，左侧时间右侧内容
class StatusRecordTile extends StatelessWidget {
  final HourlyRecord record;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const StatusRecordTile({
    super.key,
    required this.record,
    this.selectionMode = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    final useDefaultDisplay = r.data.presetId != null &&
        (StatusPresetStorage.getById(r.data.presetId!)?.hidden ?? false);
    final tagIds = r.data.tagIds;
    final primaryTagId = tagIds.isNotEmpty ? tagIds.first : '';
    final primaryTag = useDefaultDisplay
        ? '休息'
        : (primaryTagId.isEmpty ? '—' : (ActivityTagStorage.getByName(primaryTagId)?.name ?? primaryTagId));
    final h = r.hourStart.hour;
    final m = r.hourStart.minute;
    String pad(int n) => n < 10 ? '0$n' : '$n';
    final timeStr = '${pad(h)}:${pad(m)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: selected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => onTap?.call(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              SizedBox(
                width: 44,
                child: Text(
                  timeStr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: _colorForTag(primaryTag).withValues(alpha: 0.3),
                child: Icon(
                  _iconForTag(primaryTag),
                  color: _colorForTag(primaryTag),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  useDefaultDisplay ? '休息' : r.data.summary,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _colorForTag(String tag) {
    switch (tag) {
      case '工作': return Colors.blue;
      case '休息': return Colors.orange;
      case '娱乐': return Colors.green;
      case '学习': return Colors.indigo;
      case '运动': return Colors.teal;
      case '编程': return Colors.purple;
      case '睡眠': return Colors.indigo;
      case '就餐': return Colors.amber;
      case '社交': return Colors.pink;
      case '通勤': return Colors.blueGrey;
      case '会议': return Colors.blue;
      case '思考': return Colors.cyan;
      case '交流': return Colors.lightBlue;
      case '散步': return Colors.lightGreen;
      case '旅行': return Colors.orange;
      case '游玩': return Colors.green;
      default: return Colors.grey;
    }
  }

  static IconData _iconForTag(String tag) {
    switch (tag) {
      case '工作': return Icons.work;
      case '休息': return Icons.bedtime;
      case '娱乐': return Icons.games;
      case '学习': return Icons.school;
      case '运动': return Icons.fitness_center;
      case '编程': return Icons.code;
      case '睡眠': return Icons.bed;
      case '就餐': return Icons.restaurant;
      case '社交': return Icons.group;
      case '通勤': return Icons.directions_car;
      case '会议': return Icons.meeting_room;
      case '思考': return Icons.psychology;
      case '交流': return Icons.chat;
      case '散步': return Icons.directions_walk;
      case '旅行': return Icons.flight;
      case '游玩': return Icons.celebration;
      default: return Icons.label;
    }
  }
}
