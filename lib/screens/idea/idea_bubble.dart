import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/idea/chat_message.dart';

/// 时间文字预估宽度（仅 HH:mm）；从屏幕最左侧滑入
const double _timeSlideWidth = 48;

/// 长消息折叠阈值，超过则显示「展开」并支持点击进入详情
const int _collapseLength = 200;

/// 想法页消息气泡；右滑时时间从屏幕最左侧往右滑入，松手后弹回；气泡位置不变
/// 支持用户消息与 LLM 助手消息（Markdown、折叠、全文详情）
class IdeaBubble extends StatelessWidget {
  final ChatMessage message;
  final String timeStr;
  /// 时间滑入进度 0~1（0=在左侧外，1=完全进入）；右滑随手势、松手后动画弹回
  final double showTimeAmount;
  /// 流式输出时覆盖显示的正文（仅 assistant 消息）
  final String? streamingContent;
  /// 点击长消息「展开」时打开全文详情
  final void Function(String content)? onOpenFullContent;
  /// 是否为已隐藏消息（开发者模式下展示），true 时使用灰色字体
  final bool isHidden;

  const IdeaBubble({
    super.key,
    required this.message,
    required this.timeStr,
    this.showTimeAmount = 0,
    this.streamingContent,
    this.onOpenFullContent,
    this.isHidden = false,
  });

  String get _displayContent =>
      (message.isFromLlm && streamingContent != null)
          ? streamingContent!
          : message.content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAssistant = message.isFromLlm;
    final content = _displayContent;
    final isLong = content.length > _collapseLength;
    final showCollapsed = isLong && (onOpenFullContent != null);
    final hiddenStyle = theme.colorScheme.outline;

    final crossAlign = isAssistant ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final textAlign = TextAlign.left;
    final bubble = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isHidden
            ? theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              )
            : (isAssistant
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.primaryContainer),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isAssistant ? 4 : 16),
          bottomRight: Radius.circular(isAssistant ? 16 : 4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAlign,
        children: [
          if (isAssistant && message.llmAgentName != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    message.llmAgentName!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (message.quotedContent != null && message.quotedContent!.isNotEmpty && !isAssistant) ...[
            Container(
              padding: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.outline,
                    width: 3,
                  ),
                ),
              ),
              margin: const EdgeInsets.only(left: 4),
              child: Text(
                message.quotedContent!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (isAssistant)
            MarkdownBody(
              data: showCollapsed
                  ? '${content.substring(0, _collapseLength)}…'
                  : content,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyLarge?.copyWith(
                  color: isHidden ? hiddenStyle : theme.colorScheme.onSurface,
                ),
                listBullet: theme.textTheme.bodyLarge?.copyWith(
                  color: isHidden ? hiddenStyle : null,
                ),
                blockquote: theme.textTheme.bodyMedium?.copyWith(
                  color: isHidden ? hiddenStyle : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Text(
              content,
              textAlign: textAlign,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isHidden ? hiddenStyle : null,
              ),
            ),
          if (showCollapsed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                onTap: () => onOpenFullContent?.call(content),
                borderRadius: BorderRadius.circular(4),
                child: Text(
                  '展开',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final t = showTimeAmount.clamp(0.0, 1.0);
    final offsetX = -_timeSlideWidth * (1 - t);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              return Row(
                mainAxisAlignment: isAssistant ? MainAxisAlignment.start : MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isAssistant) Expanded(child: const SizedBox.shrink()),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: bubble,
                  ),
                  if (isAssistant) Expanded(child: const SizedBox.shrink()),
                ],
              );
            },
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
