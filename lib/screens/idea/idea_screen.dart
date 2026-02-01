import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_config.dart' show userDeveloperMode;
import '../../models/idea/chat_message.dart';
import '../../models/idea/idea_session.dart';
import '../../services/dev_mode_auth_service.dart';
import '../../services/idea_session_storage.dart';
import '../../widgets/chat_export_sheet.dart';
import 'idea_bubble.dart';
import 'session_history_drawer.dart';

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
                          return IdeaBubble(
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
      endDrawer: SessionHistoryDrawer(
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
