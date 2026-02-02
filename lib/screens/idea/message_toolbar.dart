import 'package:flutter/material.dart';

import '../../models/idea/chat_message.dart';

/// 消息长按后紧挨消息下方弹出的工具栏
class MessageToolbar extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onCopy;
  final VoidCallback onMultiSelectOrSelectToHere;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onQuote;
  final VoidCallback onDismiss;
  /// 多选模式下为 true，此时「多选」按钮显示为「选择到这里」
  final bool isMultiSelectMode;

  const MessageToolbar({
    super.key,
    required this.message,
    required this.onCopy,
    required this.onMultiSelectOrSelectToHere,
    required this.onDelete,
    required this.onEdit,
    required this.onQuote,
    required this.onDismiss,
    this.isMultiSelectMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolbarButton(
              icon: Icons.copy,
              label: '复制',
              onTap: () {
                onDismiss();
                onCopy();
              },
            ),
            _ToolbarButton(
              icon: Icons.checklist,
              label: isMultiSelectMode ? '选择到这里' : '多选',
              onTap: () {
                onDismiss();
                onMultiSelectOrSelectToHere();
              },
            ),
            _ToolbarButton(
              icon: Icons.delete_outline,
              label: '删除',
              onTap: () {
                onDismiss();
                onDelete();
              },
            ),
            _ToolbarButton(
              icon: Icons.edit_outlined,
              label: '编辑',
              onTap: () {
                onDismiss();
                onEdit();
              },
            ),
            _ToolbarButton(
              icon: Icons.format_quote,
              label: '引用',
              onTap: () {
                onDismiss();
                onQuote();
              },
            ),
            _ToolbarButton(
              icon: Icons.smart_toy_outlined,
              label: '问AI',
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: disabled
                  ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                  : theme.colorScheme.onSurface,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: disabled
                    ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
