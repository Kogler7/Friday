import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../constants/app_config.dart' show userDeveloperMode;
import '../models/idea/chat_message.dart';
import '../models/idea/idea_session.dart';
import '../services/dev_mode_auth_service.dart';
import '../services/idea_session_storage.dart';
import '../widgets/chat_export_sheet.dart';

/// 鎯虫硶椤碉細澶氫細璇濈鐞嗭紝鍚戝彸婊戝姩鎵撳紑浼氳瘽鍘嗗彶鎶藉眽锛涗細璇濋」鍙彸婊戝睍绀哄垹闄?閿佸畾
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
        reason: '楠岃瘉韬唤浠ユ煡鐪嬭浼氳瘽',
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

  Future<void> _createAndSwitchToNewSession() async {
    final session = await IdeaSessionStorage.createSession();
    await IdeaSessionStorage.setCurrentSessionId(session.id);
    _loadCurrentSession();
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
    final updated = session.copyWith(
      messages: newMessages,
      updatedAt: DateTime.now(),
      title: IdeaSessionStorage.sessionTitle(session.copyWith(messages: newMessages)),
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
              tooltip: '瀵煎嚭',
              onPressed: _openExport,
            ),
    );
  }
}

/// 浼氳瘽鍘嗗彶鎶藉眽锛氬垪琛ㄥ彲鍙虫粦灞曠ず鍒犻櫎銆侀攣瀹氾紱鍒犻櫎寮圭‘璁わ紝鐐瑰嚮纭鍒犻櫎銆侀暱鎸夌‘璁よ涓洪殣钘?
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

  Future<void> _onDelete(IdeaSession session) async {
    final isHidden = session.isHidden;
    final result = await showDialog<_DeleteConfirmResult>(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(
        sessionTitle: IdeaSessionStorage.sessionTitle(session),
        isHidden: isHidden,
        isDevMode: widget.isDevMode,
      ),
    );
    if (result == null || result == _DeleteConfirmResult.cancel || !mounted) return;
    if (result == _DeleteConfirmResult.setHidden) {
      await _onSetHidden(session);
      return;
    }
    final permanentDelete = widget.isDevMode && isHidden;
    await IdeaSessionStorage.deleteSession(session.id);
    _refresh();
    widget.onSessionsChanged();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(permanentDelete ? '已彻底删除' : '已删除会话')),
      );
    }
  }

  Future<void> _onSetHidden(IdeaSession session) async {
    final updated = session.copyWith(isHidden: true);
    await IdeaSessionStorage.saveSession(updated);
    _refresh();
    widget.onSessionsChanged();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('宸茶涓洪殣钘忥紝浠呭湪寮€鍙戣€呮ā寮忎笅鍙')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = widget.isDevMode
        ? [..._sessions, ..._hiddenSessions.where((s) => !_sessions.any((x) => x.id == s.id))]
        : _sessions;
    final list = List<IdeaSession>.from(raw)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '浼氳瘽鍘嗗彶',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      widget.onNewSession();
                    },
                    icon: const Icon(Icons.add),
                    tooltip: '鏂板缓浼氳瘽',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        '鏆傛棤浼氳瘽',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final session = list[index];
                        return _SessionSlidableTile(
                          session: session,
                          isSelected: session.id == widget.currentSessionId,
                          isDevMode: widget.isDevMode,
                          onTap: () => widget.onSessionSelected(session),
                          onLock: () => _onLock(session),
                          onDelete: () => _onDelete(session),
                          onSetHidden: () => _onSetHidden(session),
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

/// 鍒犻櫎纭缁撴灉锛氬彇娑堛€佸垹闄ゃ€佽涓洪殣钘?
enum _DeleteConfirmResult { cancel, delete, setHidden }

/// 鍒犻櫎纭瀵硅瘽妗嗭細鐐瑰嚮纭鎵ц鍒犻櫎锛堝紑鍙戣€呮ā寮忎笅闅愯棌浼氳瘽涓哄交搴曞垹闄わ級锛岄暱鎸夌‘璁よ涓洪殣钘?
class _DeleteConfirmDialog extends StatefulWidget {
  final String sessionTitle;
  final bool isHidden;
  final bool isDevMode;

  const _DeleteConfirmDialog({
    required this.sessionTitle,
    required this.isHidden,
    required this.isDevMode,
  });

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _longPressHandled = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('鍒犻櫎浼氳瘽'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('确定要删除「${widget.sessionTitle}」吗？'),
          const SizedBox(height: 12),
          Text(
            '点击「确认」删除会话；长按「确认」则设为隐藏（仅在开发者模式下可见）。'
            '${widget.isDevMode && widget.isHidden ? " 当前为开发者模式，删除隐藏会话将彻底删除。" : ""}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
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
          child: TextButton(
            onPressed: () {
              if (_longPressHandled) return;
              Navigator.of(context).pop(_DeleteConfirmResult.delete);
            },
            child: const Text('纭'),
          ),
        ),
      ],
    );
  }
}

/// 浼氳瘽鍒楄〃椤癸細鍚戝彸婊戝姩灞曠ず鍒犻櫎銆侀攣瀹?
class _SessionSlidableTile extends StatelessWidget {
  final IdeaSession session;
  final bool isSelected;
  final bool isDevMode;
  final VoidCallback onTap;
  final VoidCallback onLock;
  final VoidCallback onDelete;
  final VoidCallback onSetHidden;

  const _SessionSlidableTile({
    required this.session,
    required this.isSelected,
    required this.isDevMode,
    required this.onTap,
    required this.onLock,
    required this.onDelete,
    required this.onSetHidden,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = IdeaSessionStorage.sessionTitle(session);
    final subtitle = DateFormat('MM-dd HH:mm').format(session.updatedAt);
    return Slidable(
      key: ValueKey(session.id),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => onLock(),
            backgroundColor: theme.colorScheme.tertiaryContainer,
            foregroundColor: theme.colorScheme.onTertiaryContainer,
            icon: session.isLocked ? Icons.lock_open : Icons.lock,
            label: session.isLocked ? '瑙ｉ攣' : '閿佸畾',
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: theme.colorScheme.errorContainer,
            foregroundColor: theme.colorScheme.onErrorContainer,
            icon: Icons.delete_outline,
            label: '鍒犻櫎',
          ),
        ],
      ),
      child: ListTile(
        selected: isSelected,
        leading: Icon(
          session.isLocked ? Icons.lock : Icons.chat_bubble_outline,
          color: session.isHidden && isDevMode
              ? theme.colorScheme.outline
              : null,
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: session.isHidden && isDevMode
              ? theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                  fontStyle: FontStyle.italic,
                )
              : null,
        ),
        subtitle: session.isHidden && isDevMode
            ? const Text('已隐藏', style: TextStyle(fontStyle: FontStyle.italic))
            : Text(subtitle),
        onTap: onTap,
      ),
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
