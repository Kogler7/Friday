import 'package:flutter/material.dart';

/// 时间轴网格线绘制，替代大量 Positioned+Container 以提升性能
class TimelineGridPainter extends CustomPainter {
  final double tickHeight;
  final int tickCount;
  final Color lineColor;

  const TimelineGridPainter({
    required this.tickHeight,
    required this.tickCount,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = lineColor..strokeWidth = 1;
    for (var i = 0; i <= tickCount; i++) {
      final y = i * tickHeight;
      if (y >= size.height) break;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant TimelineGridPainter old) =>
      old.tickHeight != tickHeight ||
      old.tickCount != tickCount ||
      old.lineColor != lineColor;
}
