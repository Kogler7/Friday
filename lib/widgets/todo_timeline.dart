import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/todo_item.dart';

/// 今日时间轴上一段要绘制的区间
class _TimelineSegment {
  final TodoItem item;
  final int startMinute; // 0..1440
  final int endMinute;   // 0..1440
  final bool isFullDay;
  final Color color;
  final double opacity;

  _TimelineSegment({
    required this.item,
    required this.startMinute,
    required this.endMinute,
    required this.isFullDay,
    required this.color,
    required this.opacity,
  });

  int get durationMinutes => (endMinute - startMinute).clamp(0, 1440);
}

/// 今日时间轴：展示当天有时间的待办，颜色叠加，时间越长越透明，带当前时刻基准线
class TodoTimeline extends StatelessWidget {
  final List<TodoItem> items;
  final DateTime today;
  final double pixelsPerHour;
  final VoidCallback? onRefresh;
  final void Function(TodoItem)? onItemTap;

  const TodoTimeline({
    super.key,
    required this.items,
    required this.today,
    this.pixelsPerHour = 32,
    this.onRefresh,
    this.onItemTap,
  });

  static const List<Color> _palette = [
    Color(0xFF5C6BC0), // indigo
    Color(0xFF26A69A), // teal
    Color(0xFF42A5F5), // blue
    Color(0xFF66BB6A), // green
    Color(0xFFFFA726), // orange
    Color(0xFFAB47BC), // purple
  ];

  static Color _colorForItem(TodoItem item) {
    final i = item.id.hashCode.abs() % _palette.length;
    return _palette[i];
  }

  /// 是否与“今天”同一天（只比日期）
  static bool _isSameDay(DateTime? a, DateTime day) {
    if (a == null) return false;
    return a.year == day.year && a.month == day.month && a.day == day.day;
  }

  /// 将 DateTime 转为当天从 0:00 起的分钟数
  static int _toMinutesOfDay(DateTime d) {
    return d.hour * 60 + d.minute;
  }

  /// 今天 0:00 和 24:00 的 DateTime
  static (DateTime start, DateTime end) _todayRange(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (start, end);
  }

  List<_TimelineSegment> _buildSegments() {
    final segments = <_TimelineSegment>[];
    final (todayStart, todayEnd) = _todayRange(today);

    for (final item in items) {
      final color = _colorForItem(item);

      // 当天提醒 或 截止日期是今天 → 全天背景
      if (_isSameDay(item.reminderAt, today) || _isSameDay(item.dueDate, today)) {
        segments.add(_TimelineSegment(
          item: item,
          startMinute: 0,
          endMinute: 24 * 60,
          isFullDay: true,
          color: color,
          opacity: 0.22,
        ));
      }

      // 有日程时间范围且与今天有交集
      final start = item.scheduledStart;
      final end = item.scheduledEnd;
      if (start != null && end != null) {
        if (start.isBefore(todayEnd) && end.isAfter(todayStart)) {
          final startMinute = start.isBefore(todayStart)
              ? 0
              : _toMinutesOfDay(start);
          final endMinute = end.isAfter(todayEnd)
              ? 24 * 60
              : _toMinutesOfDay(end);
          final duration = (endMinute - startMinute).clamp(1, 1440);
          // 时间越长透明度越高：1h≈0.9，24h≈0.25
          final opacity = (0.25 + 0.75 * (1 - duration / 1440)).clamp(0.2, 0.95);
          segments.add(_TimelineSegment(
            item: item,
            startMinute: startMinute,
            endMinute: endMinute,
            isFullDay: false,
            color: color,
            opacity: opacity,
          ));
        }
      }
    }

    // 先画全天，再按开始时间画区间（叠加）
    segments.sort((a, b) {
      if (a.isFullDay != b.isFullDay) return a.isFullDay ? -1 : 1;
      return a.startMinute.compareTo(b.startMinute);
    });
    return segments;
  }

  @override
  Widget build(BuildContext context) {
    final segments = _buildSegments();
    final totalHeight = 24 * pixelsPerHour;
    final now = DateTime.now();
    final isToday = _isSameDay(now, today);
    final nowMinutes = isToday ? _toMinutesOfDay(now) : 0;
    final timeFmt = DateFormat('HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Text(
                '今日时间轴',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (onRefresh != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: onRefresh,
                  tooltip: '刷新',
                ),
              ],
            ],
          ),
        ),
        if (segments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
            child: Text(
              '今天没有安排时间范围的待办',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        SizedBox(
          height: totalHeight.clamp(200, 520),
          child: SingleChildScrollView(
            child: SizedBox(
              height: totalHeight,
              child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 时间刻度
                      SizedBox(
                        width: 44,
                        child: Column(
                          children: List.generate(25, (i) {
                            return SizedBox(
                              height: pixelsPerHour,
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6, top: 0),
                                  child: Text(
                                    '${i.toString().padLeft(2, '0')}:00',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 时间条区域
                      Expanded(
                        child: Stack(
                          children: [
                            // 背景网格（可选）
                            ...List.generate(24, (i) {
                              final top = i * pixelsPerHour;
                              return Positioned(
                                left: 0,
                                right: 0,
                                top: top,
                                height: pixelsPerHour,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            // 时间段块（叠加）
                            ...segments.map((s) {
                              final top = s.startMinute / 60 * pixelsPerHour;
                              final height = (s.endMinute - s.startMinute) / 60 * pixelsPerHour;
                              return Positioned(
                                left: 4,
                                right: 4,
                                top: top,
                                height: height.clamp(4.0, double.infinity),
                                child: Material(
                                  color: s.color.withOpacity(s.opacity),
                                  borderRadius: BorderRadius.circular(6),
                                  child: InkWell(
                                    onTap: () => onItemTap?.call(s.item),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Align(
                                        alignment: Alignment.topLeft,
                                        child: Text(
                                          s.item.title,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: s.color.withOpacity(0.9),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            // 当前时刻基准线
                            if (isToday && nowMinutes >= 0 && nowMinutes < 24 * 60)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: nowMinutes / 60 * pixelsPerHour - 1,
                                height: 2,
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.error,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context).colorScheme.error.withOpacity(0.5),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (isToday && nowMinutes >= 0 && nowMinutes < 24 * 60)
                              Positioned(
                                left: 0,
                                top: nowMinutes / 60 * pixelsPerHour - 8,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.surface,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        if (isToday)
          Padding(
            padding: const EdgeInsets.only(left: 52, right: 8, bottom: 4),
            child: Text(
              '当前 ${timeFmt.format(now)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
      ],
    );
  }
}
