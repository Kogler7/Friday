import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';

import '../common/slidable_action_tile.dart';
import '../models/status/status_preset.dart';
import '../models/status/status_record_data.dart';
import '../screens/status/preset_management_screen.dart';
import '../services/status_preset_storage.dart';

/// 预设选择弹框：按拼音首字母分组、右侧字母索引、搜索、置顶、删除、新建
class PresetPickerSheet extends StatefulWidget {
  final void Function(StatusRecordData data) onSelect;
  final StatusPreset? recommendedPreset;
  final double? recommendedProbability;

  const PresetPickerSheet({
    super.key,
    required this.onSelect,
    this.recommendedPreset,
    this.recommendedProbability,
  });

  @override
  State<PresetPickerSheet> createState() => _PresetPickerSheetState();
}

class _PresetPickerSheetState extends State<PresetPickerSheet> {
  List<StatusPreset> _presets = [];
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final Map<String, GlobalKey> _sectionKeys = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _presets = StatusPresetStorage.getAll();
    });
  }

  /// 获取名称拼音首字母（大写），非中文取首字符
  static String _firstLetter(String name) {
    if (name.isEmpty) return '#';
    final first = name[0];
    if (RegExp(r'[a-zA-Z0-9]').hasMatch(first)) {
      return first.toUpperCase();
    }
    final py = PinyinHelper.getShortPinyin(name);
    if (py.isEmpty) return '#';
    return py[0].toUpperCase();
  }

  /// 排序：置顶优先，再按首字母
  List<StatusPreset> _sortedPresets() {
    final filtered = _query.isEmpty
        ? _presets
        : _presets
            .where((p) =>
                p.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();
    filtered.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final la = _firstLetter(a.name);
      final lb = _firstLetter(b.name);
      if (la != lb) return la.compareTo(lb);
      return a.name.compareTo(b.name);
    });
    return filtered;
  }

  /// 分组：置顶 | A | B | ...
  List<({String section, List<StatusPreset> items})> _grouped() {
    final sorted = _sortedPresets();
    if (sorted.isEmpty) return [];
    final result = <({String section, List<StatusPreset> items})>[];
    String? lastLetter;
    List<StatusPreset> current = [];
    for (final p in sorted) {
      final letter = p.pinned ? '★' : _firstLetter(p.name);
      if (letter != lastLetter) {
        if (current.isNotEmpty) {
          result.add((section: lastLetter!, items: List.from(current)));
          current.clear();
        }
        lastLetter = letter;
      }
      current.add(p);
    }
    if (current.isNotEmpty) {
      result.add((section: lastLetter!, items: current));
    }
    return result;
  }

  List<String> _sectionLettersFromGroups(List<({String section, List<StatusPreset> items})> groups) {
    return groups.map((g) => g.section).toSet().toList()..sort();
  }

  void _scrollToSection(String letter) {
    final key = _sectionKeys[letter];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!);
    }
  }

  Future<void> _onTogglePin(StatusPreset p) async {
    await StatusPresetStorage.save(p.copyWith(pinned: !p.pinned));
    _refresh();
  }

  Future<void> _onDelete(StatusPreset p) async {
    if (p.id.startsWith('builtin_')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('内置预设不可删除')),
        );
      }
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除预设'),
        content: Text('确定删除「${p.name}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await StatusPresetStorage.delete(p.id);
      _refresh();
    }
  }

  Future<void> _onCreate() async {
    final created = await Navigator.push<StatusPreset>(
      context,
      MaterialPageRoute(
        builder: (_) => PresetEditScreen(
          preset: null,
          onSaved: () {},
          returnResult: true,
        ),
      ),
    );
    if (created != null) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = _grouped();
    final letters = _sectionLettersFromGroups(groups);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    '选择预设',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: '新建预设',
                    onPressed: _onCreate,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索预设',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.only(left: 16, right: 8, bottom: 24),
                      itemCount: groups.length,
                      itemBuilder: (_, i) {
                        final g = groups[i];
                        _sectionKeys[g.section] ??= GlobalKey();
                        return Column(
                          key: _sectionKeys[g.section],
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 12, bottom: 4),
                              child: Text(
                                g.section,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ...g.items.map((p) => _PresetTile(
                                  preset: p,
                                  onSelect: () {
                                    Navigator.pop(context);
                                    widget.onSelect(p.data);
                                  },
                                  onTogglePin: () => _onTogglePin(p),
                                  onDelete: () => _onDelete(p),
                                )),
                          ],
                        );
                      },
                    ),
                  ),
                  if (letters.isNotEmpty)
                    _LetterIndex(
                      letters: letters,
                      onLetterTap: _scrollToSection,
                    ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final StatusPreset preset;
  final VoidCallback onSelect;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const _PresetTile({
    required this.preset,
    required this.onSelect,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SlidableActionTile(
      key: ValueKey(preset.id),
      height: 56,
      leftAction: SwipeActionConfig(
        icon: Icons.delete_outline,
        backgroundColor: theme.colorScheme.error,
        iconColor: theme.colorScheme.onError,
        onTrigger: onDelete,
      ),
      rightAction: SwipeActionConfig(
        icon: preset.pinned ? Icons.star : Icons.star_border,
        backgroundColor: Colors.amber.shade200,
        iconColor: Colors.amber.shade900,
        onTrigger: onTogglePin,
      ),
      child: Material(
        color: theme.colorScheme.surface,
        child: ListTile(
          leading: Icon(preset.icon, color: preset.color, size: 28),
          title: Text(preset.name),
          trailing: preset.pinned ? Icon(Icons.star, size: 20, color: Colors.amber.shade700) : null,
          onTap: onSelect,
        ),
      ),
    );
  }
}

class _LetterIndex extends StatelessWidget {
  final List<String> letters;
  final void Function(String) onLetterTap;

  const _LetterIndex({required this.letters, required this.onLetterTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4, top: 8, bottom: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: letters.map((l) {
          return GestureDetector(
            onTap: () => onLetterTap(l),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(
                l,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
