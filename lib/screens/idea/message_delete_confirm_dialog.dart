import 'package:flutter/material.dart';

/// 消息删除确认结果：取消、删除、设为隐藏（长按确认）
enum MessageDeleteConfirmResult { cancel, delete, setHidden }

/// 消息删除确认对话框：单击确认则删除，长按确认则隐藏（仅开发者模式可见）；界面无额外提示
class MessageDeleteConfirmDialog extends StatefulWidget {
  const MessageDeleteConfirmDialog({super.key});

  @override
  State<MessageDeleteConfirmDialog> createState() =>
      _MessageDeleteConfirmDialogState();
}

class _MessageDeleteConfirmDialogState extends State<MessageDeleteConfirmDialog> {
  bool _longPressHandled = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('删除消息'),
      content: const Text('确定要删除这条消息吗？'),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(MessageDeleteConfirmResult.cancel),
          child: const Text('取消'),
        ),
        GestureDetector(
          onLongPress: () {
            _longPressHandled = true;
            Navigator.of(context).pop(MessageDeleteConfirmResult.setHidden);
          },
          child: FilledButton(
            onPressed: () {
              if (_longPressHandled) return;
              Navigator.of(context).pop(MessageDeleteConfirmResult.delete);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ),
      ],
    );
  }
}
