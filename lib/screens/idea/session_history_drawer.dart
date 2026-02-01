import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../common/slidable_action_tile.dart';
import '../../models/idea/idea_session.dart';
import '../../services/idea_session_storage.dart';
import 'delete_confirm_dialog.dart';
import 'session_edit_sheet.dart';
import 'session_list_entry.dart';

/// 会话历史抽屉：分栏（星标/刚刚/七天内/一月内/其他），左滑删除/右滑锁定，右侧星标按钮可点击切换，长按编辑
class SessionHistoryDrawer extends StatefulWidget {
  final String? currentSessionId;
  final bool isDevMode;
  final ValueChanged<IdeaSession> onSessionSelected;
  final VoidCallback onNewSession;
  final VoidCallback onSessionsChanged;

  const SessionHistoryDrawer({
    super.key,
    required this.currentSessionId,
    required this.isDevMode,
    required this.onSessionSelected,
    required this.onNewSession,
    required this.onSessionsChanged,
  });

  @override
  State<SessionHistoryDrawer> createState() => _SessionHistoryDrawerState();
}

class _SessionHistoryDrawerState extends State<SessionHistoryDrawer> {
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

  Future<void> _onToggleStar(IdeaSession session) async {
    final updated = session.copyWith(isStarred: !session.isStarred);
    await IdeaSessionStorage.saveSession(updated);
    _refresh();
    widget.onSessionsChanged();
  }

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

  Future<void> _onUnhide(IdeaSession session) async {
    final updated = session.copyWith(isHidden: false);
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
    final result = await showDialog<DeleteConfirmResult>(
      context: context,
      builder: (ctx) => DeleteConfirmDialog(sessionTitle: session.title),
    );
    if (result == null || result == DeleteConfirmResult.cancel || !mounted) return;
    if (result == DeleteConfirmResult.setHidden) {
      if (widget.isDevMode && session.isHidden) {
        await _onUnhide(session);
      } else {
        await _onSetHidden(session);
      }
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
      builder: (ctx) => SessionEditSheet(
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

  static List<SessionListEntry> _buildGroupedEntries(List<IdeaSession> raw) {
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

    final entries = <SessionListEntry>[];
    if (starred.isNotEmpty) {
      entries.add(SessionListEntry.section('星标'));
      for (final s in starred) {
        entries.add(SessionListEntry.session(s));
      }
    }
    if (justNow.isNotEmpty) {
      entries.add(SessionListEntry.section('刚刚'));
      for (final s in justNow) {
        entries.add(SessionListEntry.session(s));
      }
    }
    if (within7.isNotEmpty) {
      entries.add(SessionListEntry.section('七天内'));
      for (final s in within7) {
        entries.add(SessionListEntry.session(s));
      }
    }
    if (within30.isNotEmpty) {
      entries.add(SessionListEntry.section('一月内'));
      for (final s in within30) {
        entries.add(SessionListEntry.session(s));
      }
    }
    if (other.isNotEmpty) {
      entries.add(SessionListEntry.section('其他'));
      for (final s in other) {
        entries.add(SessionListEntry.session(s));
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = widget.isDevMode
        ? [..._sessions, ..._hiddenSessions.where((s) => !_sessions.any((x) => x.id == s.id))]
        : _sessions;
    final entries = _buildGroupedEntries(raw);

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
                            icon: Icons.delete_outline,
                            backgroundColor: theme.colorScheme.error,
                            iconColor: theme.colorScheme.onError,
                            onTrigger: () => _onSwipeDelete(session),
                          ),
                          rightAction: SwipeActionConfig(
                            icon: isLocked ? Icons.lock_open : Icons.lock,
                            backgroundColor: isLocked
                                ? Colors.green.shade200
                                : Colors.amber.shade200,
                            iconColor: isLocked
                                ? Colors.green.shade900
                                : Colors.amber.shade900,
                            onTrigger: () => _onLock(session),
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
                                    IconButton(
                                      icon: Icon(
                                        session.isStarred
                                            ? Icons.star
                                            : Icons.star_border,
                                        size: 22,
                                        color: session.isStarred
                                            ? Colors.amber.shade700
                                            : theme.colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () => _onToggleStar(session),
                                      style: IconButton.styleFrom(
                                        padding: const EdgeInsets.all(4),
                                        minimumSize: const Size(36, 36),
                                      ),
                                    ),
                                    if (isLocked)
                                      Icon(Icons.lock,
                                          size: 20,
                                          color: theme.colorScheme.primary),
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
