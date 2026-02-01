import 'package:flutter/material.dart';

/// 事件页筛选 Chip：显示标签与数量
class EventFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const EventFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text('$label${count > 0 ? ' ($count)' : ''}'),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}
