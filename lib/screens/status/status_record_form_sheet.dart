import 'package:flutter/material.dart';

import '../../models/status/activity_tag.dart';
import '../../models/status/status_enums.dart';
import '../../models/status/status_preset.dart';
import '../../models/status/status_record_data.dart';
import '../../services/activity_tag_storage.dart';
import '../../services/status_preset_storage.dart';

/// 状态记录表单：多维度填写，支持预设快速选择、保存为预设
class StatusRecordFormSheet extends StatefulWidget {
  final StatusRecordData initialData;
  final void Function(StatusRecordData data) onSubmit;
  final VoidCallback? onCancel;

  const StatusRecordFormSheet({
    super.key,
    this.initialData = const StatusRecordData(),
    required this.onSubmit,
    this.onCancel,
  });

  @override
  State<StatusRecordFormSheet> createState() => _StatusRecordFormSheetState();
}

class _StatusRecordFormSheetState extends State<StatusRecordFormSheet> {
  late StatusRecordData _data;
  List<ActivityTag> _allTags = [];
  List<StatusPreset> _presets = [];
  bool _showAddTag = false;
  final TextEditingController _newTagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _data = StatusRecordData.withDefaults(widget.initialData);
    _presets = StatusPresetStorage.getAll();
    _allTags = ActivityTagStorage.getAllSortedByStarred();
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  void _applyPreset(StatusPreset preset) {
    setState(() => _data = StatusRecordData.withDefaults(preset.data).copyWith(presetId: preset.id));
  }

  void _submit() {
    if (!_data.isComplete) {
      final msg = _validationMessage();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      return;
    }
    widget.onSubmit(_data);
  }

  String _validationMessage() {
    if (_data.energyUsage == null) return '请选择精力使用';
    if (_data.physicalUsage == null) return '请选择体力使用';
    if (_data.activityMotivation == null) return '请选择活动动机';
    if (_data.outputQuality == null) return '请选择产出定性';
    if (_data.emotionalState == null) return '请选择情绪状态';
    if (_data.energyState == null) return '请选择精力状态';
    if (_data.physicalState == null) return '请选择生理状态';
    if (_data.attentionState == null) return '请选择注意力状态';
    if (_data.tagIds.isEmpty) return '请选择至少一个活动标签';
    return '请填写完整';
  }

  Future<void> _saveAsPreset() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController(text: _data.tagIds.isNotEmpty ? _data.tagIds.first : '');
        return AlertDialog(
          title: const Text('保存为预设'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              labelText: '预设名称',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim().isEmpty ? '未命名' : c.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (name == null || !mounted) return;
    final preset = await _showPresetIconColorPicker(name);
    if (preset == null || !mounted) return;
    await StatusPresetStorage.save(preset);
    setState(() {
      _presets = StatusPresetStorage.getAll();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存预设「$name」')),
      );
    }
  }

  Future<StatusPreset?> _showPresetIconColorPicker(String name) async {
    int iconCodePoint = Icons.bookmark.codePoint;
    int colorValue = 0xFF2196F3;
    return showDialog<StatusPreset>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('选择图标和颜色'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('图标', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetIconOptions.map((icon) {
                        final cp = icon.codePoint;
                        final sel = iconCodePoint == cp;
                        return InkWell(
                          onTap: () => setDialogState(() => iconCodePoint = cp),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: sel
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, color: sel ? Theme.of(context).colorScheme.onPrimaryContainer : null),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('颜色', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetColorValues.map((v) {
                        final sel = colorValue == v;
                        return InkWell(
                          onTap: () => setDialogState(() => colorValue = v),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(v),
                              shape: BoxShape.circle,
                              border: sel ? Border.all(color: Colors.white, width: 3) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      ctx,
                      StatusPreset(
                        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
                        name: name,
                        iconCodePoint: iconCodePoint,
                        colorValue: colorValue,
                        data: _data,
                      ),
                    );
                  },
                  child: const Text('完成'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static const List<IconData> _presetIconOptions = [
    Icons.work, Icons.bedtime, Icons.games, Icons.school,
    Icons.fitness_center, Icons.code, Icons.psychology, Icons.group,
    Icons.restaurant, Icons.directions_car, Icons.home, Icons.book,
    Icons.music_note, Icons.movie, Icons.sports_esports,
  ];

  static const List<int> _presetColorValues = [
    0xFF2196F3, 0xFFFF9800, 0xFF4CAF50,
    0xFF9C27B0, 0xFFF44336, 0xFF00BCD4,
    0xFF795548, 0xFF607D8B,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('填写状态', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (widget.onCancel != null)
                    TextButton(
                      onPressed: widget.onCancel,
                      child: const Text('取消'),
                    ),
                  FilledButton(
                    onPressed: _data.isComplete ? _submit : null,
                    child: const Text('保存'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildPresetSection(theme),
              const SizedBox(height: 16),
              _buildSection(theme, '活动性质', [
                _buildEnumRow<EnergyUsage>(theme, '精力使用', EnergyUsage.values, _data.energyUsage, (v) { setState(() => _data = _data.copyWith(energyUsage: v)); }),
                _buildEnumRow<PhysicalUsage>(theme, '体力使用', PhysicalUsage.values, _data.physicalUsage, (v) { setState(() => _data = _data.copyWith(physicalUsage: v)); }),
                _buildEnumRow<ActivityMotivation>(theme, '活动动机', ActivityMotivation.values, _data.activityMotivation, (v) { setState(() => _data = _data.copyWith(activityMotivation: v)); }),
                _buildEnumRow<OutputQuality>(theme, '产出定性', OutputQuality.values, _data.outputQuality, (v) { setState(() => _data = _data.copyWith(outputQuality: v)); }),
              ]),
              const SizedBox(height: 12),
              _buildSection(theme, '状态指标', [
                _buildEnumRow<EmotionalState>(theme, '情绪状态', EmotionalState.values, _data.emotionalState, (v) { setState(() => _data = _data.copyWith(emotionalState: v)); }),
                _buildEnumRow<EnergyState>(theme, '精力状态', EnergyState.values, _data.energyState, (v) { setState(() => _data = _data.copyWith(energyState: v)); }),
                _buildEnumRow<PhysicalState>(theme, '生理状态', PhysicalState.values, _data.physicalState, (v) { setState(() => _data = _data.copyWith(physicalState: v)); }),
                _buildEnumRow<AttentionState>(theme, '注意力状态', AttentionState.values, _data.attentionState, (v) { setState(() => _data = _data.copyWith(attentionState: v)); }),
              ]),
              const SizedBox(height: 12),
              _buildTagsSection(theme),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _saveAsPreset,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('保存为预设'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPresetSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('快速选择', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets.map((p) {
            return FilterChip(
              avatar: Icon(p.icon, size: 20, color: p.color),
              label: Text(p.name),
              selected: _presetMatches(p),
              onSelected: (_) => _applyPreset(p),
            );
          }).toList(),
        ),
      ],
    );
  }

  bool _presetMatches(StatusPreset p) {
    final myTags = _data.tagIds.toSet();
    final pTags = p.data.tagIds.toSet();
    if (myTags.length != pTags.length) return false;
    if (!myTags.containsAll(pTags)) return false;
    return _data.energyUsage == p.data.energyUsage &&
        _data.physicalUsage == p.data.physicalUsage &&
        _data.activityMotivation == p.data.activityMotivation &&
        _data.outputQuality == p.data.outputQuality &&
        _data.emotionalState == p.data.emotionalState &&
        _data.energyState == p.data.energyState &&
        _data.physicalState == p.data.physicalState &&
        _data.attentionState == p.data.attentionState;
  }

  Widget _buildSection(ThemeData theme, String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
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

  Widget _buildTagsSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('活动标签', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAddTag = !_showAddTag;
                      if (_showAddTag) {
                        _newTagController.clear();
                      }
                    });
                  },
                  icon: Icon(_showAddTag ? Icons.close : Icons.add, size: 18),
                  label: Text(_showAddTag ? '收起' : '新建标签'),
                ),
              ],
            ),
            if (_showAddTag) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newTagController,
                      decoration: const InputDecoration(
                        hintText: '输入新标签',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (text) async {
                        final t = text.trim();
                        if (t.isEmpty) return;
                        await ActivityTagStorage.addTag(ActivityTag(name: t));
                        setState(() {
                          _allTags = ActivityTagStorage.getAllSortedByStarred();
                          if (!_data.tagIds.contains(t)) {
                            _data = _data.copyWith(tagIds: [..._data.tagIds, t]);
                          }
                          _newTagController.clear();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final t = _newTagController.text.trim();
                      if (t.isEmpty) return;
                      await ActivityTagStorage.addTag(ActivityTag(name: t));
                      setState(() {
                        _allTags = ActivityTagStorage.getAllSortedByStarred();
                        if (!_data.tagIds.contains(t)) {
                          _data = _data.copyWith(tagIds: [..._data.tagIds, t]);
                        }
                        _newTagController.clear();
                      });
                    },
                    child: const Text('添加'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _allTags.map((tag) {
                final selected = _data.tagIds.contains(tag.name);
                return FilterChip(
                  label: Text(tag.name),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      final next = List<String>.from(_data.tagIds);
                      if (selected) {
                        next.remove(tag.name);
                      } else {
                        next.add(tag.name);
                      }
                      _data = _data.copyWith(tagIds: next);
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
