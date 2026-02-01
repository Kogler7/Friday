import 'package:flutter/material.dart';

import '../../models/idea/idea_session.dart';
import 'session_edit_constants.dart';

/// 会话编辑弹窗：修改标题、图标、颜色；删除、锁定
class SessionEditSheet extends StatefulWidget {
  final IdeaSession session;
  final ValueChanged<IdeaSession> onSave;
  final VoidCallback onDelete;
  final VoidCallback onLock;

  const SessionEditSheet({
    super.key,
    required this.session,
    required this.onSave,
    required this.onDelete,
    required this.onLock,
  });

  @override
  State<SessionEditSheet> createState() => _SessionEditSheetState();
}

class _SessionEditSheetState extends State<SessionEditSheet> {
  late TextEditingController _titleController;
  int? _selectedIconCodePoint;
  int? _selectedColorValue;
  late bool _isStarred;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.session.title);
    _selectedIconCodePoint = widget.session.iconCodePoint;
    _selectedColorValue = widget.session.colorValue;
    _isStarred = widget.session.isStarred;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _applyAndPop() {
    final title = _titleController.text.trim();
    final updated = widget.session.copyWith(
      title: title.isEmpty ? '未命名会话' : title,
      updatedAt: DateTime.now(),
      isStarred: _isStarred,
      iconCodePoint: _selectedIconCodePoint,
      clearIconCodePoint: _selectedIconCodePoint == null,
      colorValue: _selectedColorValue,
      clearColorValue: _selectedColorValue == null,
    );
    widget.onSave(updated);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = widget.session;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '编辑会话',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _applyAndPop,
                    child: const Text('完成'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                maxLines: 1,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 20),
              Text(
                '图标',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sessionIconOptions.map((icon) {
                  final codePoint = icon.codePoint;
                  final selected = _selectedIconCodePoint == codePoint ||
                      (_selectedIconCodePoint == null &&
                          codePoint == Icons.chat_bubble_outline.codePoint);
                  final color = _selectedColorValue != null
                      ? Color(_selectedColorValue!)
                      : theme.colorScheme.primary;
                  return Material(
                    color: selected
                        ? color.withValues(alpha: 0.2)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedIconCodePoint =
                              codePoint == Icons.chat_bubble_outline.codePoint
                                  ? null
                                  : codePoint;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          icon,
                          size: 24,
                          color: selected ? color : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text(
                '颜色',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sessionColorOptions.map((color) {
                  final value = color.toARGB32();
                  final selected = _selectedColorValue == value;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedColorValue =
                              _selectedColorValue == value ? null : value;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.outline
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.star_outline, color: theme.colorScheme.primary),
                title: const Text('星标'),
                subtitle: const Text('星标会话将置顶显示'),
                trailing: Switch(
                  value: _isStarred,
                  onChanged: (v) => setState(() => _isStarred = v),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              ListTile(
                leading: Icon(session.isLocked ? Icons.lock_open : Icons.lock,
                    color: theme.colorScheme.primary),
                title: Text(session.isLocked ? '解锁' : '锁定'),
                onTap: () {
                  widget.onLock();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                title: Text('删除', style: TextStyle(color: theme.colorScheme.error)),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onDelete();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
