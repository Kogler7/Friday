import 'package:flutter/material.dart';

import '../../models/event/todo_item.dart';

/// 单日时间轴上一段要绘制的区间
class TimelineSegment {
  final TodoItem item;
  final int startMinute;
  final int endMinute;
  final bool isFullDay;
  final Color color;
  final double opacity;

  const TimelineSegment({
    required this.item,
    required this.startMinute,
    required this.endMinute,
    required this.isFullDay,
    required this.color,
    required this.opacity,
  });
}
