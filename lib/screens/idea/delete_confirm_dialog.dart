import 'package:flutter/material.dart';

/// 删除确认结果：取消、删除、设为隐藏（长按确认）
enum DeleteConfirmResult { cancel, delete, setHidden }

/// 删除确认对话框：单击确认则删除，长按确认则隐藏（仅开发者模式可见）；界面提示与正常删除无区别
class DeleteConfirmDialog extends StatefulWidget {
  final String sessionTitle;

  const DeleteConfirmDialog({super.key, required this.sessionTitle});

  @override
  State<DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<DeleteConfirmDialog> {
  bool _longPressHandled = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('删除会话'),
      content: Text('确定要删除「${widget.sessionTitle}」吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(DeleteConfirmResult.cancel),
          child: const Text('取消'),
        ),
        GestureDetector(
          onLongPress: () {
            _longPressHandled = true;
            Navigator.of(context).pop(DeleteConfirmResult.setHidden);
          },
          child: FilledButton(
            onPressed: () {
              if (_longPressHandled) return;
              Navigator.of(context).pop(DeleteConfirmResult.delete);
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
