import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/slidable_action_tile.dart';
import '../../constants/app_config.dart';
import '../../constants/default_activity_tags.dart';
import '../../models/status/activity_tag.dart';
import '../../models/status/status_enums.dart';
import '../../models/status/status_preset.dart';
import '../../models/status/status_record_data.dart';
import '../../services/activity_tag_storage.dart';
import '../../services/preset_import_export.dart';
import '../idea/delete_confirm_dialog.dart';
import 'preset_delete_confirm_dialog.dart';
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
    userDeveloperMode.addListener(_onDevModeChanged);
  }

  @override
  void dispose() {
    userDeveloperMode.removeListener(_onDevModeChanged);
    super.dispose();
  }

  void _onDevModeChanged() => _load();

  void _load() {
    final includeHidden = userDeveloperMode.value;
    setState(() {
      _presets = StatusPresetStorage.getAll(includeHidden: includeHidden);
      _tags = ActivityTagStorage.getAll(includeHidden: includeHidden);
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
        body: ValueListenableBuilder<bool>(
          valueListenable: userDeveloperMode,
          builder: (_, isDevMode, __) => TabBarView(
            children: [
              _PresetList(presets: _presets, isDevMode: isDevMode, onChanged: _load),
              _TagList(tags: _tags, isDevMode: isDevMode, onChanged: _load),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doExport() async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _ExportSelectDialog(presets: _presets),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    final toExport = _presets.where((p) => selected.contains(p.id)).toList();
    final raw = PresetImportExport.exportToJson(toExport);
    final formatted = PresetImportExport.formatJson(raw);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ExportPreviewSheet(
        jsonText: formatted,
        presetCount: toExport.length,
      ),
    );
  }

  Future<void> _doImport() async {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ImportPreviewSheet(
        onImported: () {
          _load();
          Navigator.of(ctx).pop();
        },
      ),
    );
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

/// 导出预览：格式化 JSON + 复制按钮
class _ExportPreviewSheet extends StatelessWidget {
  final String jsonText;
  final int presetCount;

  const _ExportPreviewSheet({
    required this.jsonText,
    required this.presetCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '导出预设 ($presetCount 个)',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: jsonText),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制到剪贴板')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('复制到剪贴板'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  jsonText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 导入预览：输入框 + 粘贴按钮 + 格式化 + 预设列表预览 + 确认导入
class _ImportPreviewSheet extends StatefulWidget {
  final VoidCallback onImported;

  const _ImportPreviewSheet({required this.onImported});

  @override
  State<_ImportPreviewSheet> createState() => _ImportPreviewSheetState();
}

class _ImportPreviewSheetState extends State<_ImportPreviewSheet> {
  final TextEditingController _controller = TextEditingController();
  List<StatusPreset>? _parsedPresets;
  String? _parseError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      setState(() {
        _parsedPresets = null;
        _parseError = null;
      });
      return;
    }
    final (presets, error) = PresetImportExport.parseFromJson(text);
    setState(() {
      _parsedPresets = presets;
      _parseError = error;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isNotEmpty) {
      _applyFormat(text);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('剪贴板为空')),
      );
    }
  }

  void _applyFormat(String text) {
    final formatted = PresetImportExport.formatJson(text);
    _controller.text = formatted;
    _onTextChanged();
  }

  Future<void> _confirmImport() async {
    if (_parsedPresets == null || _parsedPresets!.isEmpty) return;
    for (final p in _parsedPresets!) {
      final id = p.id.startsWith('builtin_')
          ? 'imported_${p.id}_${DateTime.now().millisecondsSinceEpoch}'
          : p.id;
      await StatusPresetStorage.save(StatusPreset(
        id: id,
        name: p.name,
        iconCodePoint: p.iconCodePoint,
        colorValue: p.colorValue,
        data: p.data,
      ));
    }
    widget.onImported();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 ${_parsedPresets!.length} 个预设')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canImport = _parsedPresets != null && _parsedPresets!.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '导入预设',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '粘贴或输入 JSON 数据',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 6,
                    onChanged: (_) => _onTextChanged(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _paste,
                        icon: const Icon(Icons.content_paste, size: 18),
                        label: const Text('从剪贴板粘贴'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _applyFormat(_controller.text),
                        icon: const Icon(Icons.format_align_left, size: 18),
                        label: const Text('格式化'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_parseError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _parseError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (_parsedPresets != null && _parsedPresets!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '将新增以下 ${_parsedPresets!.length} 个预设：',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _parsedPresets!.length,
                  itemBuilder: (_, i) {
                    final p = _parsedPresets![i];
                    return ListTile(
                      leading: Icon(p.icon, color: p.color, size: 24),
                      title: Text(p.name),
                      subtitle: Text(p.data.summary),
                    );
                  },
                ),
              ),
            ] else
              const Expanded(child: SizedBox.shrink()),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: canImport ? _confirmImport : null,
                child: const Text('确认导入'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PresetList extends StatelessWidget {
  final List<StatusPreset> presets;
  final bool isDevMode;
  final VoidCallback onChanged;

  const _PresetList({required this.presets, required this.isDevMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sorted = List<StatusPreset>.from(presets)
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    return ListView.builder(
      itemCount: sorted.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('新增预设'),
                onTap: () => _addPreset(context),
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('恢复默认'),
                subtitle: const Text('重置内置预设可见性'),
                onTap: () async {
                  await StatusPresetStorage.restoreBuiltInVisibility();
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
        final p = sorted[i - 1];
        final theme = Theme.of(context);
        final dimColor = (p.hidden && isDevMode) ? theme.colorScheme.outline : null;
        return SlidableActionTile(
          key: ValueKey(p.id),
          height: 64,
          leftAction: SwipeActionConfig(
            icon: Icons.delete_outline,
            backgroundColor: theme.colorScheme.error,
            iconColor: theme.colorScheme.onError,
            onTrigger: () => _deletePreset(context, p),
          ),
          rightAction: SwipeActionConfig(
            icon: p.pinned ? Icons.star : Icons.star_border,
            backgroundColor: Colors.amber.shade200,
            iconColor: Colors.amber.shade900,
            onTrigger: () => _togglePresetPin(p),
          ),
          child: Material(
            color: theme.colorScheme.surface,
            child: ListTile(
              leading: Icon(p.icon, color: dimColor ?? p.color),
              title: Text(p.name, style: dimColor != null ? TextStyle(color: dimColor) : null),
              subtitle: Text(p.data.summary, style: dimColor != null ? TextStyle(color: dimColor) : null),
              trailing: p.pinned
                  ? Icon(Icons.star, size: 20, color: Colors.amber.shade700)
                  : const Icon(Icons.chevron_right),
              onTap: () => _editPreset(context, p),
            ),
          ),
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

  void _togglePresetPin(StatusPreset p) async {
    await StatusPresetStorage.save(p.copyWith(pinned: !p.pinned));
    onChanged();
  }

  void _deletePreset(BuildContext context, StatusPreset p) async {
    final result = await showDialog<DeleteConfirmResult>(
      context: context,
      builder: (_) => PresetDeleteConfirmDialog(
        presetName: p.name,
        isHidden: p.hidden,
        isBuiltin: p.id.startsWith('builtin_'),
      ),
    );
    if (result == null || result == DeleteConfirmResult.cancel || !context.mounted) return;
    if (result == DeleteConfirmResult.setHidden) {
      if (p.hidden) {
        await StatusPresetStorage.setHidden(p.id, false);
      } else {
        await StatusPresetStorage.setHidden(p.id, true);
      }
      onChanged();
      return;
    }
    if (p.id.startsWith('builtin_')) {
      if (p.hidden) {
        await StatusPresetStorage.setHidden(p.id, false);
      } else {
        await StatusPresetStorage.setHidden(p.id, true);
      }
      onChanged();
    } else {
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
    final displayTags = tags;
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
        final starred = ActivityTagStorage.getStarredNames().contains(t.name);
        final theme = Theme.of(context);
        final dimColor = (t.hidden && isDevMode) ? theme.colorScheme.outline : null;
        return SlidableActionTile(
          key: ValueKey(t.name),
          height: 56,
          leftAction: SwipeActionConfig(
            icon: Icons.delete_outline,
            backgroundColor: theme.colorScheme.error,
            iconColor: theme.colorScheme.onError,
            onTrigger: () => _onDeleteTap(context, t, isBuiltIn),
          ),
          rightAction: SwipeActionConfig(
            icon: starred ? Icons.star : Icons.star_border,
            backgroundColor: Colors.amber.shade200,
            iconColor: Colors.amber.shade900,
            onTrigger: () => _toggleTagStarred(t),
          ),
          child: Material(
            color: theme.colorScheme.surface,
            child: ListTile(
              title: Text(t.name, style: dimColor != null ? TextStyle(color: dimColor) : null),
              subtitle: t.desc != null && t.desc!.isNotEmpty
                  ? Text(t.desc!, style: dimColor != null ? TextStyle(color: dimColor) : null)
                  : null,
              trailing: starred ? Icon(Icons.star, size: 20, color: Colors.amber.shade700) : null,
              onTap: () {},
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleTagStarred(ActivityTag t) async {
    final starred = ActivityTagStorage.getStarredNames().contains(t.name);
    await ActivityTagStorage.setStarred(t.name, !starred);
    onChanged();
  }

  Future<void> _onDeleteTap(
    BuildContext context,
    ActivityTag t,
    bool isBuiltIn,
  ) async {
    final result = await showDialog<DeleteConfirmResult>(
      context: context,
      builder: (_) => TagDeleteConfirmDialog(
        tagName: t.name,
        isHidden: t.hidden,
        isBuiltin: isBuiltIn,
      ),
    );
    if (result == null || result == DeleteConfirmResult.cancel || !context.mounted) return;
    if (result == DeleteConfirmResult.setHidden) {
      if (t.hidden) {
        await ActivityTagStorage.setHidden(t.name, false);
      } else {
        await ActivityTagStorage.setHidden(t.name, true);
      }
      onChanged();
      return;
    }
    if (isBuiltIn) {
      if (t.hidden) {
        await ActivityTagStorage.setHidden(t.name, false);
      } else {
        await ActivityTagStorage.setHidden(t.name, true);
      }
      onChanged();
    } else {
      await ActivityTagStorage.deleteTag(t.name);
      onChanged();
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
  late StatusRecordData _data;

  @override
  void initState() {
    super.initState();
    final p = widget.preset;
    _nameController = TextEditingController(text: p?.name ?? '');
    _iconCodePoint = p?.iconCodePoint ?? Icons.bookmark.codePoint;
    _colorValue = p?.colorValue ?? 0xFF2196F3;
    _data = StatusRecordData.withDefaults(p?.data ?? const StatusRecordData());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildEnumRow<T>(ThemeData theme, String label, List<T> values, T? current, ValueChanged<T?> onSelect) {
    String display(T v) {
      if (v is EnergyUsage) return (v as EnergyUsage).displayName;
      if (v is PhysicalUsage) return (v as PhysicalUsage).displayName;
      if (v is ActivityMotivation) return (v as ActivityMotivation).displayName;
      if (v is OutputQuality) return (v as OutputQuality).displayName;
      if (v is EmotionalState) return (v as EmotionalState).displayName;
      if (v is EnergyState) return (v as EnergyState).displayName;
      if (v is PhysicalState) return (v as PhysicalState).displayName;
      if (v is AttentionState) return (v as AttentionState).displayName;
      return v.toString();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in values)
                ChoiceChip(
                  label: Text(display(v)),
                  selected: current == v,
                  onSelected: (selected) {
                    if (selected) setState(() => onSelect(v));
                  },
                ),
            ],
          ),
        ],
      ),
    );
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
          const SizedBox(height: 20),
          Text('活动性质', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildEnumRow<EnergyUsage>(theme, '精力使用', EnergyUsage.values, _data.energyUsage, (v) { setState(() => _data = _data.copyWith(energyUsage: v)); }),
          _buildEnumRow<PhysicalUsage>(theme, '体力使用', PhysicalUsage.values, _data.physicalUsage, (v) { setState(() => _data = _data.copyWith(physicalUsage: v)); }),
          _buildEnumRow<ActivityMotivation>(theme, '活动动机', ActivityMotivation.values, _data.activityMotivation, (v) { setState(() => _data = _data.copyWith(activityMotivation: v)); }),
          _buildEnumRow<OutputQuality>(theme, '产出定性', OutputQuality.values, _data.outputQuality, (v) { setState(() => _data = _data.copyWith(outputQuality: v)); }),
          const SizedBox(height: 16),
          Text('状态指标', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildEnumRow<EmotionalState>(theme, '情绪状态', EmotionalState.values, _data.emotionalState, (v) { setState(() => _data = _data.copyWith(emotionalState: v)); }),
          _buildEnumRow<EnergyState>(theme, '精力状态', EnergyState.values, _data.energyState, (v) { setState(() => _data = _data.copyWith(energyState: v)); }),
          _buildEnumRow<PhysicalState>(theme, '生理状态', PhysicalState.values, _data.physicalState, (v) { setState(() => _data = _data.copyWith(physicalState: v)); }),
          _buildEnumRow<AttentionState>(theme, '注意力状态', AttentionState.values, _data.attentionState, (v) { setState(() => _data = _data.copyWith(attentionState: v)); }),
          const SizedBox(height: 16),
          Text('活动标签', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ActivityTagStorage.getAllSortedByStarred().map((tag) {
              final sel = _data.tagIds.contains(tag.name);
              return FilterChip(
                label: Text(tag.name),
                selected: sel,
                onSelected: (_) {
                  setState(() {
                    final next = List<String>.from(_data.tagIds);
                    if (sel) next.remove(tag.name);
                    else next.add(tag.name);
                    _data = _data.copyWith(tagIds: next);
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
      data: _data,
      pinned: widget.preset?.pinned ?? false,
    );
    await StatusPresetStorage.save(preset);
    widget.onSaved();
    if (widget.returnResult && context.mounted) {
      Navigator.pop(context, preset);
    }
  }
}