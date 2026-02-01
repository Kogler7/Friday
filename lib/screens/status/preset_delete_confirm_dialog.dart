import 'package:flutter/material.dart';

import '../idea/delete_confirm_dialog.dart';

/// 预设删除确认：可见时点按删除/长按隐藏，已隐藏时点按彻底删除/长按恢复可见
class PresetDeleteConfirmDialog extends StatefulWidget {
  final String presetName;
  final bool isHidden;
  final bool isBuiltin;

  const PresetDeleteConfirmDialog({
    super.key,
    required this.presetName,
    required this.isHidden,
    required this.isBuiltin,
  });

  @override
  State<PresetDeleteConfirmDialog> createState() => _PresetDeleteConfirmDialogState();
}

class _PresetDeleteConfirmDialogState extends State<PresetDeleteConfirmDialog> {
  bool _longPressHandled = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('删除预设'),
      content: Text('确定要删除「${widget.presetName}」吗？'),
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
