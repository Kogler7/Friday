import 'package:flutter/material.dart';

import '../../constants/app_config.dart';
import '../../constants/default_activity_tags.dart';
import '../../models/status/activity_tag.dart';
import '../../models/status/status_preset.dart';
import '../../models/status/status_record_data.dart';
import '../../services/activity_tag_storage.dart';
import '../../services/preset_import_export.dart';
import '../idea/delete_confirm_dialog.dart';
import 'tag_delete_confirm_dialog.dart';
import '../../services/status_preset_storage.dart';

/// 预设管理：增删改预设、导入导出、活动标签增删
class PresetManagementScreen extends StatefulWidget {
  const PresetManagementScreen({super.key});

  @override
  State<PresetManagementScreen> createState() => _PresetManagementScreenState();
}

class _PresetManagementScreenState extends State<PresetManagementScreen> {
  List<StatusPreset> _presets = [];
  List<ActivityTag> _tags = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _presets = StatusPresetStorage.getAll();
      _tags = ActivityTagStorage.getAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('预设与标签管理'),
          bottom: const TabBar(
            tabs: [Tab(text: '预设'), Tab(text: '活动标签')],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) async {
                if (v == 'export') await _doExport();
                else if (v == 'import') await _doImport();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'export', child: Text('导出预设')),
                const PopupMenuItem(value: 'import', child: Text('导入预设')),
              ],
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _PresetList(presets: _presets, onChanged: _load),
            ValueListenableBuilder<bool>(
              valueListenable: userDeveloperMode,
              builder: (_, isDevMode, __) =>
                  _TagList(tags: _tags, isDevMode: isDevMode, onChanged: _load),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doExport() async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _ExportSelectDialog(presets: _presets),
    );
    if (selected == null || selected.isEmpty) return;
    final toExport = _presets.where((p) => selected.contains(p.id)).toList();
    final json = PresetImportExport.exportToJson(toExport);
    await PresetImportExport.copyToClipboard(json);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出 ${toExport.length} 个预设到剪贴板')),
      );
    }
  }

  Future<void> _doImport() async {
    final json = await PresetImportExport.pasteFromClipboard();
    if (json == null || json.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('剪贴板为空')),
        );
      }
      return;
    }
    final presets = PresetImportExport.importFromJson(json);
    if (presets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法解析预设数据')),
        );
      }
      return;
    }
    for (final p in presets) {
      final id = p.id.startsWith('builtin_') ? 'imported_${p.id}_${DateTime.now().millisecondsSinceEpoch}' : p.id;
      await StatusPresetStorage.save(StatusPreset(
        id: id,
        name: p.name,
        iconCodePoint: p.iconCodePoint,
        colorValue: p.colorValue,
        data: p.data,
      ));
    }
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 ${presets.length} 个预设')),
      );
    }
  }
}

class _ExportSelectDialog extends StatefulWidget {
  final List<StatusPreset> presets;

  const _ExportSelectDialog({required this.presets});

  @override
  State<_ExportSelectDialog> createState() => _ExportSelectDialogState();
}

class _ExportSelectDialogState extends State<_ExportSelectDialog> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择要导出的预设'),
      content: SizedBox(
        width: 280,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.presets.length,
          itemBuilder: (_, i) {
            final p = widget.presets[i];
            return CheckboxListTile(
              value: _selected.contains(p.id),
              onChanged: (v) {
                setState(() {
                  if (v == true) _selected.add(p.id);
                  else _selected.remove(p.id);
                });
              },
              title: Text(p.name),
              secondary: Icon(p.icon, color: p.color, size: 24),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('导出'),
        ),
      ],
    );
  }
}

class _PresetList extends StatelessWidget {
  final List<StatusPreset> presets;
  final VoidCallback onChanged;

  const _PresetList({required this.presets, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: presets.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('新增预设'),
            onTap: () => _addPreset(context),
          );
        }
        final p = presets[i - 1];
        final isBuiltin = p.id.startsWith('builtin_');
        return ListTile(
          leading: Icon(p.icon, color: p.color),
          title: Text(p.name),
          subtitle: Text(p.data.summary),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editPreset(context, p),
              ),
              if (!isBuiltin)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deletePreset(context, p),
                ),
            ],
          ),
          onTap: () => _editPreset(context, p),
        );
      },
    );
  }

  void _addPreset(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PresetEditScreen(
          preset: null,
          onSaved: () {
            onChanged();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _editPreset(BuildContext context, StatusPreset p) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PresetEditScreen(
          preset: p,
          onSaved: () {
            onChanged();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _deletePreset(BuildContext context, StatusPreset p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除预设'),
        content: Text('确定删除「${p.name}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await StatusPresetStorage.delete(p.id);
      onChanged();
    }
  }
}

class _TagList extends StatelessWidget {
  final List<ActivityTag> tags;
  final bool isDevMode;
  final VoidCallback onChanged;

  const _TagList({
    required this.tags,
    required this.isDevMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final displayTags = isDevMode ? tags : tags.where((t) => !t.hidden).toList();
    return ListView.builder(
      itemCount: displayTags.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('新增标签'),
                onTap: () => _addTag(context),
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('恢复默认'),
                subtitle: const Text('重置内置标签可见性'),
                onTap: () async {
                  await ActivityTagStorage.restoreDefaults();
                  onChanged();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已恢复默认')),
                    );
                  }
                },
              ),
            ],
          );
        }
        final t = displayTags[i - 1];
        final isBuiltIn = builtInActivityTags.any((d) => d.name == t.name);
        return ListTile(
          title: Text(t.name),
          subtitle: t.desc != null && t.desc!.isNotEmpty ? Text(t.desc!) : null,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _onDeleteTap(context, t, isBuiltIn),
          ),
        );
      },
    );
  }

  Future<void> _onDeleteTap(
    BuildContext context,
    ActivityTag t,
    bool isBuiltIn,
  ) async {
    final result = await showDialog<DeleteConfirmResult>(
      context: context,
      builder: (_) => TagDeleteConfirmDialog(tagName: t.name),
    );
    if (result == null || result == DeleteConfirmResult.cancel || !context.mounted) return;
    if (result == DeleteConfirmResult.setHidden) {
      if (!isDevMode) return;
      if (t.hidden) {
        await ActivityTagStorage.setHidden(t.name, false);
      } else {
        await ActivityTagStorage.setHidden(t.name, true);
      }
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除标签')),
        );
      }
      return;
    }
    if (isBuiltIn) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('内置标签仅可隐藏')),
        );
      }
    } else {
      await ActivityTagStorage.deleteTag(t.name);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除标签')),
        );
      }
    }
  }

  void _addTag(BuildContext context) {
    final c = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新增标签'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: '标签名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final name = c.text.trim();
              if (name.isEmpty) return;
              await ActivityTagStorage.addTag(ActivityTag(name: name));
              onChanged();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

}

class PresetEditScreen extends StatefulWidget {
  final StatusPreset? preset;
  final VoidCallback onSaved;
  /// 为 true 时保存后 pop 并返回新建的预设
  final bool returnResult;

  const PresetEditScreen({
    super.key,
    this.preset,
    required this.onSaved,
    this.returnResult = false,
  });

  @override
  State<PresetEditScreen> createState() => _PresetEditScreenState();
}

class _PresetEditScreenState extends State<PresetEditScreen> {
  late TextEditingController _nameController;
  late int _iconCodePoint;
  late int _colorValue;
  late List<String> _tagIds;

  @override
  void initState() {
    super.initState();
    final p = widget.preset;
    _nameController = TextEditingController(text: p?.name ?? '');
    _iconCodePoint = p?.iconCodePoint ?? Icons.bookmark.codePoint;
    _colorValue = p?.colorValue ?? 0xFF2196F3;
    _tagIds = List.from(p?.data.tagIds ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.preset == null ? '新增预设' : '编辑预设'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          const SizedBox(height: 16),
          Text('图标', style: theme.textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: _iconOptions.map((icon) {
              final cp = icon.codePoint;
              return InkWell(
                onTap: () => setState(() => _iconCodePoint = cp),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _iconCodePoint == cp ? theme.colorScheme.primaryContainer : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('颜色', style: theme.textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: _colorValues.map((v) {
              return InkWell(
                onTap: () => setState(() => _colorValue = v),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(v),
                    shape: BoxShape.circle,
                    border: _colorValue == v ? Border.all(color: theme.colorScheme.onSurface) : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('活动标签', style: theme.textTheme.titleSmall),
          Wrap(
            spacing: 6,
            children: ActivityTagStorage.getVisible().map((tag) {
              final sel = _tagIds.contains(tag.name);
              return FilterChip(
                label: Text(tag.name),
                selected: sel,
                onSelected: (_) {
                  setState(() {
                    if (sel) _tagIds.remove(tag.name);
                    else _tagIds.add(tag.name);
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static const _iconOptions = [
    Icons.work, Icons.bedtime, Icons.games, Icons.bed, Icons.school,
    Icons.code, Icons.fitness_center, Icons.directions_car, Icons.restaurant,
    Icons.psychology, Icons.group, Icons.home_repair_service, Icons.bookmark,
  ];

  static const _colorValues = [
    0xFF2196F3, 0xFFFF9800, 0xFF4CAF50, 0xFF9C27B0, 0xFF5C6BC0,
    0xFF009688, 0xFF607D8B, 0xFF795548, 0xFFE91E63,
  ];

  void _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final id = widget.preset?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
    final preset = StatusPreset(
      id: id,
      name: name,
      iconCodePoint: _iconCodePoint,
      colorValue: _colorValue,
      data: StatusRecordData(tagIds: _tagIds),
      pinned: widget.preset?.pinned ?? false,
    );
    await StatusPresetStorage.save(preset);
    widget.onSaved();
    if (widget.returnResult && context.mounted) {
      Navigator.pop(context, preset);
    }
  }
}