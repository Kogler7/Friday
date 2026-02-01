import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_config.dart' show userDeveloperMode;
import '../models/idea/chat_message.dart';
import '../models/idea/idea_session.dart';
import '../services/dev_mode_auth_service.dart';
import '../services/idea_session_storage.dart';
import '../widgets/chat_export_sheet.dart';
import '../common/slidable_action_tile.dart';

/// 想法页：多会话管理，向右滑动打开会话历史抽屉；会话项可右滑展示删除、锁定
class IdeaScreen extends StatefulWidget {
  const IdeaScreen({super.key});

  @override
  State<IdeaScreen> createState() => _IdeaScreenState();
}

class _IdeaScreenState extends State<IdeaScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  IdeaSession? _currentSession;
  List<ChatMessage> _messages = [];
  static final DateFormat _timeFmt = DateFormat('MM-dd HH:mm');

  bool get _isDevMode => userDeveloperMode.value;

  @override
  void initState() {
    super.initState();
    _loadCurrentSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadCurrentSession() {
    final id = IdeaSessionStorage.getCurrentSessionId();
    if (id == null) {
      setState(() {
        _currentSession = null;
        _messages = [];
      });
      return;
    }
    final session = IdeaSessionStorage.getSession(id);
    if (session == null) {
      IdeaSessionStorage.setCurrentSessionId(null);
      setState(() {
        _currentSession = null;
        _messages = [];
      });
      return;
    }
    setState(() {
      _currentSession = session;
      _messages = List.from(session.messages)..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
  }

  Future<void> _switchToSession(IdeaSession session) async {
    if (session.isLocked) {
      final result = await DevModeAuthService.authenticate(
        reason: '验证身份以查看该会话',
      );
      if (result == DevModeAuthResult.failed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('验证未通过，无法打开该会话')),
          );
        }
        return;
      }
    }
    await IdeaSessionStorage.setCurrentSessionId(session.id);
    _loadCurrentSession();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addSession() async {
    final session = await IdeaSessionStorage.createSession();
    await IdeaSessionStorage.setCurrentSessionId(session.id);
    _loadCurrentSession();
  }

  Future<void> _createAndSwitchToNewSession() async {
    await _addSession();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    if (_currentSession == null) {
      final session = await IdeaSessionStorage.createSession();
      await IdeaSessionStorage.setCurrentSessionId(session.id);
      _loadCurrentSession();
      if (_currentSession == null) return;
    }
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      content: text,
    );
    final session = _currentSession!;
    final newMessages = List<ChatMessage>.from(session.messages)..add(msg);
    final newTitle = session.title == '未命名会话' && newMessages.isNotEmpty
        ? IdeaSessionStorage.sessionTitle(session.copyWith(messages: newMessages))
        : session.title;
    final updated = session.copyWith(
      messages: newMessages,
      updatedAt: DateTime.now(),
      title: newTitle,
    );
    await IdeaSessionStorage.saveSession(updated);
    _loadCurrentSession();
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _openExport() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ChatExportSheet(
        messages: _messages,
        onExported: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('想法'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加会话',
            onPressed: _addSession,
          ),
        ],
      ),
      body: Builder(
        builder: (scaffoldContext) {
          return Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentSession == null
                                  ? '选择或新建一个会话开始记录想法'
                                  : '写点什么吧，记录你的想法',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () => Scaffold.of(scaffoldContext).openEndDrawer(),
                          icon: const Icon(Icons.history),
                          label: const Text('会话历史'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _IdeaBubble(
                        message: msg,
                        timeStr: _timeFmt.format(msg.createdAt),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => Scaffold.of(scaffoldContext).openEndDrawer(),
                  icon: const Icon(Icons.menu),
                  tooltip: '会话历史',
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 4,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: '记录想法…',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _send,
                  icon: const Icon(Icons.send),
                  tooltip: '发送',
                ),
              ],
            ),
          ),
            ],
          );
        },
      ),
      endDrawer: _SessionHistoryDrawer(
        currentSessionId: _currentSession?.id,
        isDevMode: _isDevMode,
        onSessionSelected: _switchToSession,
        onNewSession: _createAndSwitchToNewSession,
        onSessionsChanged: _loadCurrentSession,
      ),
      floatingActionButton: _messages.isEmpty
          ? null
          : IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: '导出',
              onPressed: _openExport,
            ),
    );
  }
}

/// 会话列表条目：分栏标题或会话项
class _SessionListEntry {
  final bool isSection;
  final String? sectionLabel;
  final IdeaSession? session;

  _SessionListEntry._({required this.isSection, this.sectionLabel, this.session});

  factory _SessionListEntry.section(String label) =>
      _SessionListEntry._(isSection: true, sectionLabel: label);
  factory _SessionListEntry.session(IdeaSession s) =>
      _SessionListEntry._(isSection: false, session: s);
}

/// 会话历史抽屉：分栏（星标/刚刚/七天内/一月内/其他），右滑删除/锁定，长按编辑（含星标）
class _SessionHistoryDrawer extends StatefulWidget {
  final String? currentSessionId;
  final bool isDevMode;
  final ValueChanged<IdeaSession> onSessionSelected;
  final VoidCallback onNewSession;
  final VoidCallback onSessionsChanged;

  const _SessionHistoryDrawer({
    required this.currentSessionId,
    required this.isDevMode,
    required this.onSessionSelected,
    required this.onNewSession,
    required this.onSessionsChanged,
  });

  @override
  State<_SessionHistoryDrawer> createState() => _SessionHistoryDrawerState();
}

class _SessionHistoryDrawerState extends State<_SessionHistoryDrawer> {
  List<IdeaSession> _sessions = [];
  List<IdeaSession> _hiddenSessions = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _sessions = IdeaSessionStorage.getAllSessions(includeHidden: false);
      _hiddenSessions = IdeaSessionStorage.getAllSessions(includeHidden: true)
          .where((s) => s.isHidden)
          .toList();
    });
  }

  Future<void> _onLock(IdeaSession session) async {
    final updated = session.copyWith(isLocked: !session.isLocked);
    await IdeaSessionStorage.saveSession(updated);
    _refresh();
    widget.onSessionsChanged();
  }

  /// 右滑松手后弹出确认框，确认后删除
  Future<void> _onSwipeDelete(IdeaSession session) async {
    await _onDelete(session);
  }

  Future<void> _onSetHidden(IdeaSession session) async {
    final updated = session.copyWith(isHidden: true);
    await IdeaSessionStorage.saveSession(updated);
    _refresh();
    widget.onSessionsChanged();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除会话')),
      );
    }
  }

  Future<void> _onDelete(IdeaSession session) async {
    final result = await showDialog<_DeleteConfirmResult>(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(sessionTitle: session.title),
    );
    if (result == null || result == _DeleteConfirmResult.cancel || !mounted) return;
    if (result == _DeleteConfirmResult.setHidden) {
      await _onSetHidden(session);
      return;
    }
    await IdeaSessionStorage.deleteSession(session.id);
    _refresh();
    widget.onSessionsChanged();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除会话')),
      );
    }
  }

  void _showSessionLongPressSheet(BuildContext context, IdeaSession session) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _SessionEditSheet(
        session: session,
        onSave: (updated) async {
          await IdeaSessionStorage.saveSession(updated);
          _refresh();
          widget.onSessionsChanged();
        },
        onDelete: () => _onDelete(session),
        onLock: () => _onLock(session),
      ),
    );
  }

  /// 分栏条目：标题或会话
  static List<_SessionListEntry> _buildGroupedEntries(List<IdeaSession> raw) {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final starred = raw.where((s) => s.isStarred).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final nonStarred = raw.where((s) => !s.isStarred).toList();

    final justNow = nonStarred.where((s) => s.updatedAt.isAfter(oneHourAgo)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final within7 = nonStarred.where((s) =>
        !s.updatedAt.isAfter(oneHourAgo) && s.updatedAt.isAfter(sevenDaysAgo)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final within30 = nonStarred.where((s) =>
        !s.updatedAt.isAfter(sevenDaysAgo) && s.updatedAt.isAfter(thirtyDaysAgo)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final other = nonStarred.where((s) => !s.updatedAt.isAfter(thirtyDaysAgo)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final entries = <_SessionListEntry>[];
    if (starred.isNotEmpty) {
      entries.add(_SessionListEntry.section('星标'));
      for (final s in starred) entries.add(_SessionListEntry.session(s));
    }
    if (justNow.isNotEmpty) {
      entries.add(_SessionListEntry.section('刚刚'));
      for (final s in justNow) entries.add(_SessionListEntry.session(s));
    }
    if (within7.isNotEmpty) {
      entries.add(_SessionListEntry.section('七天内'));
      for (final s in within7) entries.add(_SessionListEntry.session(s));
    }
    if (within30.isNotEmpty) {
      entries.add(_SessionListEntry.section('一月内'));
      for (final s in within30) entries.add(_SessionListEntry.session(s));
    }
    if (other.isNotEmpty) {
      entries.add(_SessionListEntry.section('其他'));
      for (final s in other) entries.add(_SessionListEntry.session(s));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = widget.isDevMode
        ? [..._sessions, ..._hiddenSessions.where((s) => !_sessions.any((x) => x.id == s.id))]
        : _sessions;
    final entries = _SessionHistoryDrawerState._buildGroupedEntries(raw);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '会话历史',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => widget.onNewSession(),
                    icon: const Icon(Icons.add),
                    tooltip: '新建会话',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        '暂无会话',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        if (entry.isSection) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              entry.sectionLabel!,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        final session = entry.session!;
                        final title = session.title;
                        final subtitle =
                            DateFormat('MM-dd HH:mm').format(session.updatedAt);
                        final isLocked = session.isLocked;
                        final leadingIcon = session.iconCodePoint != null
                            ? IconData(
                                session.iconCodePoint!,
                                fontFamily: 'MaterialIcons',
                              )
                            : Icons.chat_bubble_outline;
                        final leadingColor = session.colorValue != null
                            ? Color(session.colorValue!)
                            : (session.isHidden && widget.isDevMode
                                ? theme.colorScheme.outline
                                : null);
                        return SlidableActionTile(
                          key: ValueKey(session.id),
                          height: 64,
                          leftAction: SwipeActionConfig(
                            icon: isLocked ? Icons.lock_open : Icons.lock,
                            backgroundColor: isLocked
                                ? Colors.green.shade200
                                : Colors.amber.shade200,
                            iconColor: isLocked
                                ? Colors.green.shade900
                                : Colors.amber.shade900,
                            onTrigger: () => _onLock(session),
                          ),
                          rightAction: SwipeActionConfig(
                            icon: Icons.delete_outline,
                            backgroundColor: theme.colorScheme.error,
                            iconColor: theme.colorScheme.onError,
                            onTrigger: () => _onSwipeDelete(session),
                          ),
                          child: Center(
                            child: Material(
                              color: theme.colorScheme.surface,
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: 0,
                                  bottom: 4,
                                ),
                              selected: session.id == widget.currentSessionId,
                              leading: Icon(
                                leadingIcon,
                                size: 22,
                                color: leadingColor,
                              ),
                              title: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: session.isHidden && widget.isDevMode
                                      ? theme.colorScheme.outline
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (session.isStarred)
                                    Icon(Icons.star,
                                        size: 20,
                                        color: Colors.amber.shade700),
                                  if (isLocked) ...[
                                    if (session.isStarred) const SizedBox(width: 4),
                                    Icon(Icons.lock,
                                        size: 20,
                                        color: theme.colorScheme.primary),
                                  ],
                                ],
                              ),
                              onTap: () =>
                                  widget.onSessionSelected(session),
                              onLongPress: () => _showSessionLongPressSheet(
                                  context, session),
                            ),
                          ),
                        ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 会话编辑弹窗：修改标题、图标、颜色；删除、锁定
class _SessionEditSheet extends StatefulWidget {
  final IdeaSession session;
  final ValueChanged<IdeaSession> onSave;
  final VoidCallback onDelete;
  final VoidCallback onLock;

  const _SessionEditSheet({
    required this.session,
    required this.onSave,
    required this.onDelete,
    required this.onLock,
  });

  @override
  State<_SessionEditSheet> createState() => _SessionEditSheetState();
}

/// 常用图标库（Material Icons）
const List<IconData> _sessionIconOptions = [
  Icons.chat_bubble_outline,
  Icons.lightbulb_outline,
  Icons.note_outlined,
  Icons.edit_note,
  Icons.folder_outlined,
  Icons.star_outline,
  Icons.bookmark_outline,
  Icons.label_outline,
  Icons.work_outline,
  Icons.school_outlined,
  Icons.psychology_outlined,
  Icons.auto_awesome,
  Icons.tips_and_updates_outlined,
  Icons.menu_book_outlined,
  Icons.article_outlined,
  Icons.dashboard_outlined,
  Icons.inventory_2_outlined,
  Icons.push_pin_outlined,
];

/// 常用颜色库（现代柔和配色）
const List<Color> _sessionColorOptions = [
  Color(0xFF5C6BC0), // 靛蓝
  Color(0xFF42A5F5), // 蓝
  Color(0xFF26A69A), // 青绿
  Color(0xFF66BB6A), // 绿
  Color(0xFF9CCC65), // 浅绿
  Color(0xFFFFA726), // 橙
  Color(0xFFEF5350), // 红
  Color(0xFFEC407A), // 粉
  Color(0xFFAB47BC), // 紫
  Color(0xFF7E57C2), // 深紫
  Color(0xFF78909C), // 蓝灰
  Color(0xFF8D6E63), // 棕
];

class _SessionEditSheetState extends State<_SessionEditSheet> {
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
                children: _sessionIconOptions.map((icon) {
                  final codePoint = icon.codePoint;
                  final selected = _selectedIconCodePoint == codePoint ||
                      (_selectedIconCodePoint == null &&
                          codePoint == Icons.chat_bubble_outline.codePoint);
                  final color = _selectedColorValue != null
                      ? Color(_selectedColorValue!)
                      : theme.colorScheme.primary;
                  return Material(
                    color: selected
                        ? color.withOpacity(0.2)
                        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
                children: _sessionColorOptions.map((color) {
                  final value = color.value;
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

/// 删除确认结果：取消、删除、设为隐藏（长按确认）
enum _DeleteConfirmResult { cancel, delete, setHidden }

/// 删除确认对话框：单击确认则删除，长按确认则隐藏（仅开发者模式可见）；界面提示与正常删除无区别
class _DeleteConfirmDialog extends StatefulWidget {
  final String sessionTitle;

  const _DeleteConfirmDialog({required this.sessionTitle});

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _longPressHandled = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('删除会话'),
      content: Text('确定要删除「${widget.sessionTitle}」吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_DeleteConfirmResult.cancel),
          child: const Text('取消'),
        ),
        GestureDetector(
          onLongPress: () {
            _longPressHandled = true;
            Navigator.of(context).pop(_DeleteConfirmResult.setHidden);
          },
          child: FilledButton(
            onPressed: () {
              if (_longPressHandled) return;
              Navigator.of(context).pop(_DeleteConfirmResult.delete);
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

class _IdeaBubble extends StatelessWidget {
  final ChatMessage message;
  final String timeStr;

  const _IdeaBubble({required this.message, required this.timeStr});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
