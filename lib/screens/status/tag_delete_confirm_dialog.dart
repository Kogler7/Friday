import 'package:flutter/material.dart';

import '../idea/delete_confirm_dialog.dart';

/// 标签删除确认：单击确认删除，长按确认隐藏（仅开发者模式可用）；界面与普通删除无区别
class TagDeleteConfirmDialog extends StatefulWidget {
  final String tagName;

  const TagDeleteConfirmDialog({super.key, required this.tagName});

  @override
  State<TagDeleteConfirmDialog> createState() => _TagDeleteConfirmDialogState();
}

class _TagDeleteConfirmDialogState extends State<TagDeleteConfirmDialog> {
  bool _longPressHandled = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('删除标签'),
      content: Text('确定要删除「${widget.tagName}」吗？已使用该标签的记录将保留。'),
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
