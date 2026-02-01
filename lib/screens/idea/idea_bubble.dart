import 'package:flutter/material.dart';

import '../../models/idea/chat_message.dart';

/// 时间文字预估宽度，用于从左侧滑入/弹回
const double _timeSlideWidth = 88;

/// 想法页消息气泡；右滑时时间从最左侧随手势滑入，松手后弹回
class IdeaBubble extends StatelessWidget {
  final ChatMessage message;
  final String timeStr;
  /// 时间滑入进度 0~1（0=在左侧外，1=完全进入）；右滑随手势、松手后动画弹回
  final double showTimeAmount;

  const IdeaBubble({
    super.key,
    required this.message,
    required this.timeStr,
    this.showTimeAmount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubble = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Text(
        message.content,
        style: theme.textTheme.bodyLarge,
      ),
    );
    final t = showTimeAmount.clamp(0.0, 1.0);
    final offsetX = -_timeSlideWidth * (1 - t);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(child: bubble),
            ],
          ),
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: t > 0 ? 1.0 : 0.0,
                child: Transform.translate(
                  offset: Offset(offsetX, 0),
                  child: Text(
                    timeStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
