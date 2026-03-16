import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../constants/app_config.dart' show userDeveloperMode;
import '../../models/agent/llm_agent.dart';
import '../../models/idea/chat_message.dart';
import '../../models/idea/idea_session.dart';
import '../../services/agent_storage.dart';
import '../../services/idea_session_storage.dart';
import '../../services/llm_api_service.dart';
import '../../services/settings_service.dart';
import '../../services/local_auth_service.dart';
import 'agent_picker_overlay.dart';
import 'idea_bubble.dart';
import 'idea_export_sheet.dart';
import 'message_delete_confirm_dialog.dart';
import 'message_edit_dialog.dart';
import 'message_detail_screen.dart';
import 'message_toolbar.dart';
import 'llm_error_detail_screen.dart';

/// 供 MainShell 渲染会话历史 endDrawer 时使用的属性
class IdeaDrawerProps {
  final String? currentSessionId;
  final String? sessionTitle;
  final bool isDevMode;
  final ValueChanged<IdeaSession> onSessionSelected;
  final VoidCallback onNewSession;
  final VoidCallback onSessionsChanged;

  const IdeaDrawerProps({
    required this.currentSessionId,
    this.sessionTitle,
    required this.isDevMode,
    required this.onSessionSelected,
    required this.onNewSession,
    required this.onSessionsChanged,
  });
}

/// 多选状态回调：是否处于多选、退出多选的函数（供 MainShell 拦截返回键时调用）
typedef IdeaMultiSelectStateCallback =
    void Function(bool isMultiSelect, VoidCallback exitMultiSelect);

/// 想法页：多会话管理，左侧抽屉为个人页、右侧 endDrawer 为会话历史（AppBar 右侧按钮或左滑唤起）；右滑展示消息时间
class IdeaScreen extends StatefulWidget {
  final void Function(IdeaDrawerProps)? onSessionDrawerPropsReady;
  final void Function(List<Widget>)? onAppBarActionsReady;
  final VoidCallback? onOpenSessionHistory;
  final IdeaMultiSelectStateCallback? onMultiSelectStateChange;

  const IdeaScreen({
    super.key,
    this.onSessionDrawerPropsReady,
    this.onAppBarActionsReady,
    this.onOpenSessionHistory,
    this.onMultiSelectStateChange,
  });

  @override
  State<IdeaScreen> createState() => _IdeaScreenState();
}

/// 消息列表条目：时间分割线或气泡
class _MessageEntry {
  final bool isDivider;
  final DateTime? dividerTime;
  final ChatMessage? message;
  final int? messageIndex;

  _MessageEntry._({
    this.isDivider = false,
    this.dividerTime,
    this.message,
    this.messageIndex,
  });

  factory _MessageEntry.divider(DateTime time) =>
      _MessageEntry._(isDivider: true, dividerTime: time);
  factory _MessageEntry.bubble(ChatMessage message, int index) =>
      _MessageEntry._(isDivider: false, message: message, messageIndex: index);
}

class _IdeaScreenState extends State<IdeaScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  IdeaSession? _currentSession;
  List<ChatMessage> _messages = [];
  static final DateFormat _timeFmtShort = DateFormat('HH:mm');
  static final DateFormat _timeFmtDivider = DateFormat('yyyy-MM-dd HH:mm');

  /// 多选模式：左侧复选框，选中后可导出；可视区无选中时显示顶部/底部「选择到这里」
  bool _multiSelectMode = false;
  final Set<int> _selectedIndices = <int>{};

  /// 多选模式下从当前已选范围扩展到包含消息 idx 的连续区间
  void _selectRangeToMessage(int idx) {
    if (!_multiSelectMode || _selectedIndices.isEmpty) return;
    final from = _selectedIndices.reduce((a, b) => a < b ? a : b);
    final to = _selectedIndices.reduce((a, b) => a > b ? a : b);
    final low = from < idx ? from : idx;
    final high = to > idx ? to : idx;
    setState(() {
      for (var i = low; i <= high; i++) {
        _selectedIndices.add(i);
      }
    });
  }

  void _exitMultiSelect() {
    if (!_multiSelectMode) return;
    setState(() {
      _multiSelectMode = false;
      _selectedIndices.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyMultiSelectState();
    });
  }

  void _notifyMultiSelectState() {
    widget.onMultiSelectStateChange?.call(_multiSelectMode, _exitMultiSelect);
  }

  /// 引用消息，展示在输入框上方
  ChatMessage? _quotedMessage;

  /// 输入 @ 后选择的 Agent，发送时转给 LLM
  LlmAgent? _atAgent;

  /// 输入 @ 后是否显示 Agent 选择浮层
  bool _showAtOverlay = false;

  /// 流式 LLM 回复：占位消息 id、当前累积内容
  String? _streamingMessageId;
  String? _streamingContent;

  /// 输入框是否展开为接近全屏高度
  bool _inputExpanded = false;

  OverlayEntry? _toolbarOverlay;

  /// 右滑展示时间（从左侧滑入）、左滑拉出会话历史（endDrawer）；松手后时间弹回
  double _dragAccumDx = 0;
  double? _dragStartX;
  static const double _dragForFullTime = 80;
  static const double _dragToOpenSessionHistory = 36;
  late AnimationController _snapBackController;
  Animation<double>? _snapBackAnim;

  bool get _isDevMode => userDeveloperMode.value;

  static const Duration _messageGapThreshold = Duration(minutes: 5);

  List<_MessageEntry> _buildMessageEntries() {
    final entries = <_MessageEntry>[];
    for (var i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      if (i == 0) {
        entries.add(_MessageEntry.divider(msg.createdAt));
      } else {
        final prev = _messages[i - 1];
        if (msg.createdAt.difference(prev.createdAt) > _messageGapThreshold) {
          entries.add(_MessageEntry.divider(msg.createdAt));
        }
      }
      entries.add(_MessageEntry.bubble(msg, i));
    }
    return entries;
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentSession();
    _snapBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scrollController.addListener(_onScrollForMultiSelect);
    userDeveloperMode.addListener(_onUserDevModeChanged);
    _controller.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    final text = _controller.text;
    if (text.endsWith('@') && !_showAtOverlay) {
      setState(() => _showAtOverlay = true);
    }
  }

  void _onScrollForMultiSelect() {
    if (_multiSelectMode && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onInputChanged);
    _dismissMessageToolbar();
    _scrollController.removeListener(_onScrollForMultiSelect);
    userDeveloperMode.removeListener(_onUserDevModeChanged);
    _snapBackController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onUserDevModeChanged() {
    if (userDeveloperMode.value) {
      if (mounted) _loadCurrentSession();
    } else {
      IdeaSessionStorage.ensureCurrentSessionVisible().then((_) {
        if (mounted) _loadCurrentSession();
      });
    }
  }

  void _snapBackTime() {
    final from = _dragAccumDx;
    if (from <= 0) {
      setState(() {
        _dragAccumDx = 0;
        _dragStartX = null;
      });
      return;
    }
    _snapBackAnim = Tween<double>(begin: from, end: 0).animate(
      CurvedAnimation(parent: _snapBackController, curve: Curves.easeOut),
    );
    void listener() {
      if (mounted) setState(() => _dragAccumDx = _snapBackAnim!.value);
    }

    _snapBackAnim!.addListener(listener);
    _snapBackController.forward(from: 0).then((_) {
      _snapBackAnim?.removeListener(listener);
      if (mounted) {
        setState(() {
          _dragAccumDx = 0;
          _dragStartX = null;
        });
      }
      _snapBackController.reset();
    });
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
      var list = List<ChatMessage>.from(session.messages);
      if (!_isDevMode) list = list.where((m) => !m.isHidden).toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _messages = list;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _dismissMessageToolbar() {
    _toolbarOverlay?.remove();
    _toolbarOverlay = null;
  }

  void _showMessageToolbar(BuildContext itemContext, ChatMessage msg, int idx) {
    _dismissMessageToolbar();
    final box = itemContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final globalPos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final toolbarGlobal = Offset(globalPos.dx, globalPos.dy + size.height);

    final overlayState = Overlay.of(context);
    final overlayBox = overlayState.context.findRenderObject() as RenderBox?;
    final double left;
    final double top;
    if (overlayBox != null && overlayBox.hasSize) {
      final local = overlayBox.globalToLocal(toolbarGlobal);
      left = local.dx;
      top = local.dy;
    } else {
      left = toolbarGlobal.dx;
      top = toolbarGlobal.dy;
    }

    _toolbarOverlay = OverlayEntry(
      builder: (_) {
        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _dismissMessageToolbar();
                setState(() {});
              },
            ),
            Positioned(
              left: left,
              top: top,
              child: MessageToolbar(
                message: msg,
                isMultiSelectMode: _multiSelectMode,
                onCopy: () async {
                  await Clipboard.setData(ClipboardData(text: msg.content));
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已复制')));
                  }
                },
                onMultiSelectOrSelectToHere: () {
                  if (_multiSelectMode) {
                    _selectRangeToMessage(idx);
                  } else {
                    setState(() {
                      _multiSelectMode = true;
                      _selectedIndices.add(idx);
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _notifyMultiSelectState();
                    });
                  }
                },
                onDelete: () => _confirmDeleteMessage(msg),
                onEdit: () => _editMessage(msg),
                onQuote: () {
                  setState(() => _quotedMessage = msg);
                },
                onDismiss: _dismissMessageToolbar,
              ),
            ),
          ],
        );
      },
    );
    overlayState.insert(_toolbarOverlay!);
    setState(() {});
  }

  Future<void> _confirmDeleteMessage(ChatMessage msg) async {
    final result = await showDialog<MessageDeleteConfirmResult>(
      context: context,
      builder: (_) => const MessageDeleteConfirmDialog(),
    );
    if (result == null ||
        result == MessageDeleteConfirmResult.cancel ||
        _currentSession == null ||
        !mounted)
      return;
    final session = _currentSession!;
    if (result == MessageDeleteConfirmResult.delete) {
      final newMessages = session.messages
          .where((m) => m.id != msg.id)
          .toList();
      await IdeaSessionStorage.saveSession(
        session.copyWith(messages: newMessages, updatedAt: DateTime.now()),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已删除')));
      }
    } else {
      final newMessages = session.messages
          .map((m) => m.id == msg.id ? m.copyWith(isHidden: true) : m)
          .toList();
      await IdeaSessionStorage.saveSession(
        session.copyWith(messages: newMessages, updatedAt: DateTime.now()),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已删除')));
      }
    }
    _loadCurrentSession();
  }

  Future<void> _editMessage(ChatMessage msg) async {
    if (_currentSession == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => MessageEditDialog(
        message: msg,
        onSave: (newContent) async {
          final session = _currentSession!;
          final newMessages = session.messages
              .map((m) => m.id == msg.id ? m.copyWith(content: newContent) : m)
              .toList();
          await IdeaSessionStorage.saveSession(
            session.copyWith(messages: newMessages, updatedAt: DateTime.now()),
          );
          _loadCurrentSession();
        },
      ),
    );
  }

  /// 根据滚动位置估算当前可视的消息索引范围（用于「选择到这里」）
  static const double _avgEntryHeight = 56;

  void _selectRangeToVisibleBottom() {
    if (_selectedIndices.isEmpty || !_scrollController.hasClients) return;
    final entries = _buildMessageEntries();
    final offset = _scrollController.offset;
    final viewport = _scrollController.position.viewportDimension;
    final lastListIndex = ((offset + viewport) / _avgEntryHeight).floor().clamp(
      0,
      entries.length - 1,
    );
    final lastMsgIndex = _lastMessageIndexInEntries(entries, lastListIndex);
    final from = _selectedIndices.reduce((a, b) => a < b ? a : b);
    final to = lastMsgIndex;
    setState(() {
      for (var i = from; i <= to; i++) {
        _selectedIndices.add(i);
      }
    });
  }

  void _selectRangeToVisibleTop() {
    if (_selectedIndices.isEmpty || !_scrollController.hasClients) return;
    final entries = _buildMessageEntries();
    final offset = _scrollController.offset;
    final firstListIndex = (offset / _avgEntryHeight).floor().clamp(
      0,
      entries.length - 1,
    );
    final firstMsgIndex = _firstMessageIndexInEntries(entries, firstListIndex);
    final to = _selectedIndices.reduce((a, b) => a > b ? a : b);
    final from = firstMsgIndex;
    setState(() {
      for (var i = from; i <= to; i++) {
        _selectedIndices.add(i);
      }
    });
  }

  int _firstMessageIndexInEntries(
    List<_MessageEntry> entries,
    int startListIndex,
  ) {
    for (var i = startListIndex; i >= 0; i--) {
      if (!entries[i].isDivider && entries[i].messageIndex != null) {
        return entries[i].messageIndex!;
      }
    }
    return 0;
  }

  int _lastMessageIndexInEntries(
    List<_MessageEntry> entries,
    int endListIndex,
  ) {
    for (var i = endListIndex; i < entries.length; i++) {
      if (!entries[i].isDivider && entries[i].messageIndex != null) {
        return entries[i].messageIndex!;
      }
    }
    return _messages.length - 1;
  }

  Future<void> _switchToSession(IdeaSession session) async {
    if (session.isLocked) {
      final result = await LocalAuthService.authenticate(reason: '验证身份以查看该会话');
      if (result == LocalAuthResult.failed) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('验证未通过，无法打开该会话')));
        }
        return;
      }
    }
    await IdeaSessionStorage.setCurrentSessionId(session.id);
    _loadCurrentSession();
    if (mounted) Navigator.of(context).pop();
    _scrollToBottom();
  }

  void _addSession() {
    IdeaSessionStorage.setCurrentSessionId(null);
    _loadCurrentSession();
  }

  void _createAndSwitchToNewSession() {
    _addSession();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final quoted = _quotedMessage;
    final atAgent = _atAgent;
    setState(() {
      _quotedMessage = null;
      _atAgent = null;
      _showAtOverlay = false;
    });
    _controller.clear();
    if (_currentSession == null && atAgent == null) {
      final session = await IdeaSessionStorage.createSessionWithFirstMessage(
        text,
      );
      await IdeaSessionStorage.setCurrentSessionId(session.id);
      _loadCurrentSession();
      _scrollToBottom();
      return;
    }
    if (_currentSession == null && atAgent != null) {
      final session = await IdeaSessionStorage.createSessionWithFirstMessage(
        text,
      );
      await IdeaSessionStorage.setCurrentSessionId(session.id);
      final assistantId = '${DateTime.now().millisecondsSinceEpoch}_assistant';
      final assistantMsg = ChatMessage(
        id: assistantId,
        createdAt: DateTime.now(),
        content: '',
        role: 'assistant',
        llmAgentId: atAgent.id,
        llmAgentName: atAgent.name,
      );
      final newMessages = List<ChatMessage>.from(session.messages)
        ..add(assistantMsg);
      final updated = session.copyWith(
        messages: newMessages,
        updatedAt: DateTime.now(),
      );
      await IdeaSessionStorage.saveSession(updated);
      _loadCurrentSession();
      _scrollToBottom();
      setState(() {
        _streamingMessageId = assistantId;
        _streamingContent = '';
      });
      _requestLlmReply(updated, text, atAgent, assistantId);
      return;
    }
    final session = _currentSession!;
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      content: text,
      quotedMessageId: quoted?.id,
      quotedContent: quoted != null
          ? (quoted.content.length > 40
                ? '${quoted.content.substring(0, 40)}…'
                : quoted.content)
          : null,
    );
    List<ChatMessage> newMessages = List<ChatMessage>.from(session.messages)
      ..add(userMsg);
    if (atAgent != null) {
      final assistantId = '${DateTime.now().millisecondsSinceEpoch}_assistant';
      final assistantMsg = ChatMessage(
        id: assistantId,
        createdAt: DateTime.now(),
        content: '',
        role: 'assistant',
        llmAgentId: atAgent.id,
        llmAgentName: atAgent.name,
      );
      newMessages = List<ChatMessage>.from(newMessages)..add(assistantMsg);
      final newTitle = session.title == '未命名会话' && newMessages.isNotEmpty
          ? IdeaSessionStorage.sessionTitle(
              session.copyWith(messages: newMessages),
            )
          : session.title;
      final updated = session.copyWith(
        messages: newMessages,
        updatedAt: DateTime.now(),
        title: newTitle,
      );
      await IdeaSessionStorage.saveSession(updated);
      _loadCurrentSession();
      _scrollToBottom();
      setState(() {
        _streamingMessageId = assistantId;
        _streamingContent = '';
      });
      _requestLlmReply(updated, text, atAgent, assistantId);
      return;
    }
    final newTitle = session.title == '未命名会话' && newMessages.isNotEmpty
        ? IdeaSessionStorage.sessionTitle(
            session.copyWith(messages: newMessages),
          )
        : session.title;
    final updated = session.copyWith(
      messages: newMessages,
      updatedAt: DateTime.now(),
      title: newTitle,
    );
    await IdeaSessionStorage.saveSession(updated);
    _loadCurrentSession();
    _scrollToBottom();
  }

  Future<void> _requestLlmReply(
    IdeaSession session,
    String userContent, [
    LlmAgent? agent,
    String? assistantId,
  ]) async {
    if (!LlmApiService.isConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先在设置中配置 API 接入点和密钥')));
      }
      if (assistantId != null)
        _removeAssistantPlaceholder(session.id, assistantId);
      return;
    }
    final globalContextCount = SettingsService.current.ideaContextMessageCount;
    final contextMessages = <LlmMessage>[];
    if (session.messages.isNotEmpty) {
      int startIndex;
      final maxChars = agent?.maxContextChars;
      if (maxChars != null && maxChars > 0) {
        int totalChars = 0;
        startIndex = session.messages.length;
        for (var i = session.messages.length - 1; i >= 0; i--) {
          totalChars += session.messages[i].content.length;
          if (totalChars > maxChars) {
            startIndex = i + 1;
            break;
          }
          startIndex = i;
        }
      } else {
        startIndex = (session.messages.length - globalContextCount).clamp(0, session.messages.length);
        if (globalContextCount <= 0) startIndex = session.messages.length;
      }
      for (var i = startIndex; i < session.messages.length; i++) {
        final m = session.messages[i];
        contextMessages.add(LlmMessage(role: m.role, content: m.content));
      }
    }
    contextMessages.add(LlmMessage(role: 'user', content: userContent));
    try {
      final stream = LlmApiService.chatStreamWithAgent(
        messages: contextMessages,
        agent: agent,
      );
      await for (final chunk in stream) {
        if (!mounted) return;
        setState(() => _streamingContent = (_streamingContent ?? '') + chunk);
        _scrollToBottom();
      }
    } on LlmApiException catch (e) {
      if (mounted) {
        _showLlmErrorSnackBar(
          context,
          e.message,
          e.toString(),
          statusCode: e.statusCode,
          requestUrl: e.requestUrl,
          requestBody: e.requestBody,
          responseBody: e.responseBody,
        );
      }
      if (assistantId != null)
        _removeAssistantPlaceholder(session.id, assistantId);
    } catch (e, stack) {
      if (mounted) {
        _showLlmErrorSnackBar(
          context,
          e.toString(),
          stack.toString(),
        );
      }
      if (assistantId != null)
        _removeAssistantPlaceholder(session.id, assistantId);
    }
    if (!mounted) return;
    final content = _streamingContent ?? '';
    setState(() {
      _streamingMessageId = null;
      _streamingContent = null;
    });
    if (assistantId == null) return;
    final s = IdeaSessionStorage.getSession(session.id);
    if (s == null) return;
    final newMessages = s.messages.map((m) {
      if (m.id == assistantId) return m.copyWith(content: content);
      return m;
    }).toList();
    await IdeaSessionStorage.saveSession(
      s.copyWith(messages: newMessages, updatedAt: DateTime.now()),
    );
    _loadCurrentSession();
  }

  void _showLlmErrorSnackBar(
    BuildContext context,
    String message,
    String detailContent, {
    int? statusCode,
    String? requestUrl,
    String? requestBody,
    String? responseBody,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(child: Text(message)),
            if (_isDevMode)
              TextButton.icon(
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('查看详情'),
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LlmErrorDetailScreen(
                        title: 'Agent 返回错误',
                        errorMessage: message,
                        detailContent: detailContent,
                        statusCode: statusCode,
                        requestUrl: requestUrl,
                        requestBody: requestBody,
                        responseBody: responseBody,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeAssistantPlaceholder(
    String sessionId,
    String assistantId,
  ) async {
    final s = IdeaSessionStorage.getSession(sessionId);
    if (s == null) return;
    final newMessages = s.messages.where((m) => m.id != assistantId).toList();
    await IdeaSessionStorage.saveSession(
      s.copyWith(messages: newMessages, updatedAt: DateTime.now()),
    );
    setState(() {
      _streamingMessageId = null;
      _streamingContent = null;
    });
    _loadCurrentSession();
  }

  @override
  Widget build(BuildContext context) {
    // 延后到 build 结束后再通知父组件，避免在 build 中调用父组件 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onSessionDrawerPropsReady?.call(
        IdeaDrawerProps(
          currentSessionId: _currentSession?.id,
          sessionTitle: _currentSession?.title,
          isDevMode: _isDevMode,
          onSessionSelected: _switchToSession,
          onNewSession: _createAndSwitchToNewSession,
          onSessionsChanged: _loadCurrentSession,
        ),
      );
      final actions = _multiSelectMode
          ? [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: '取消多选',
                onPressed: () {
                  setState(() {
                    _multiSelectMode = false;
                    _selectedIndices.clear();
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _notifyMultiSelectState();
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.upload_file),
                tooltip: '导出选中',
                onPressed: _selectedIndices.isEmpty
                    ? null
                    : () {
                        final selected =
                            _selectedIndices.map((i) => _messages[i]).toList()
                              ..sort(
                                (a, b) => a.createdAt.compareTo(b.createdAt),
                              );
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (ctx) => IdeaExportSheet(
                            messages: selected,
                            onExported: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _multiSelectMode = false;
                                _selectedIndices.clear();
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) _notifyMultiSelectState();
                              });
                            },
                          ),
                        );
                      },
              ),
            ]
          : [
              if (widget.onOpenSessionHistory != null)
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: '会话历史',
                  onPressed: widget.onOpenSessionHistory,
                ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: '添加会话',
                onPressed: _addSession,
              ),
            ];
      widget.onAppBarActionsReady?.call(actions);
    });

    return Scaffold(
      body: Builder(
        builder: (scaffoldContext) {
          if (_inputExpanded) {
            return Column(children: [Expanded(child: _buildExpandedInput())]);
          }
          return Column(
            children: [
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted)
                        FocusManager.instance.primaryFocus?.unfocus();
                    });
                  },
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentSession == null
                                    ? '选择或新建一个会话开始记录想法'
                                    : '写点什么吧，记录你的想法',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: widget.onOpenSessionHistory != null
                                    ? widget.onOpenSessionHistory!
                                    : () => Scaffold.of(
                                        scaffoldContext,
                                      ).openEndDrawer(),
                                icon: const Icon(Icons.history),
                                label: const Text('会话历史'),
                              ),
                            ],
                          ),
                        )
                      : Builder(
                          builder: (context) {
                            final messageEntries = _buildMessageEntries();
                            final timeVisibility =
                                (_dragAccumDx / _dragForFullTime).clamp(
                                  0.0,
                                  1.0,
                                );
                            bool showSelectToHereAtTop = false;
                            bool showSelectToHereAtBottom = false;
                            if (_multiSelectMode &&
                                _selectedIndices.isNotEmpty &&
                                _messages.isNotEmpty &&
                                _scrollController.hasClients) {
                              final offset = _scrollController.offset;
                              final viewport =
                                  _scrollController.position.viewportDimension;
                              final firstListIndex = (offset / _avgEntryHeight)
                                  .floor()
                                  .clamp(0, messageEntries.length - 1);
                              final lastListIndex =
                                  ((offset + viewport) / _avgEntryHeight)
                                      .floor()
                                      .clamp(0, messageEntries.length - 1);
                              final firstVisibleMsg =
                                  _firstMessageIndexInEntries(
                                    messageEntries,
                                    firstListIndex,
                                  );
                              final lastVisibleMsg = _lastMessageIndexInEntries(
                                messageEntries,
                                lastListIndex,
                              );
                              final visibleHasSelected = _selectedIndices.any(
                                (i) =>
                                    i >= firstVisibleMsg && i <= lastVisibleMsg,
                              );
                              if (!visibleHasSelected) {
                                final minSelected = _selectedIndices.reduce(
                                  (a, b) => a < b ? a : b,
                                );
                                final maxSelected = _selectedIndices.reduce(
                                  (a, b) => a > b ? a : b,
                                );
                                if (maxSelected < firstVisibleMsg) {
                                  showSelectToHereAtBottom = true;
                                } else if (minSelected > lastVisibleMsg) {
                                  showSelectToHereAtTop = true;
                                }
                              }
                            }
                            return Stack(
                              children: [
                                Listener(
                                  behavior: HitTestBehavior.translucent,
                                  onPointerDown: (_) {
                                    _dragStartX = null;
                                  },
                                  onPointerUp: (_) {
                                    _snapBackTime();
                                  },
                                  onPointerCancel: (_) {
                                    _snapBackTime();
                                  },
                                  onPointerMove: (e) {
                                    _dragStartX ??= e.position.dx;
                                    final dx = e.delta.dx;
                                    final dy = e.delta.dy;
                                    final hasScrollSpace =
                                        _scrollController.hasClients &&
                                        _scrollController
                                                .position
                                                .maxScrollExtent >
                                            1;
                                    if (hasScrollSpace &&
                                        dx.abs() < 3 * dy.abs()) {
                                      return;
                                    }
                                    if (!hasScrollSpace &&
                                        dy.abs() > 2 * dx.abs()) {
                                      return;
                                    }
                                    setState(() {
                                      _dragAccumDx += dx;
                                      if (_dragAccumDx <
                                          -_dragToOpenSessionHistory) {
                                        _dragAccumDx = 0;
                                        _dragStartX = null;
                                        widget.onOpenSessionHistory?.call();
                                      }
                                    });
                                  },
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    itemCount: messageEntries.length,
                                    itemBuilder: (context, index) {
                                      final entry = messageEntries[index];
                                      if (entry.isDivider) {
                                        final timeStr = _timeFmtDivider.format(
                                          entry.dividerTime!,
                                        );
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Divider(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.outlineVariant,
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                    ),
                                                child: Text(
                                                  timeStr,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Divider(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.outlineVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      final msg = entry.message!;
                                      final idx = entry.messageIndex!;
                                      if (_multiSelectMode) {
                                        final selected = _selectedIndices
                                            .contains(idx);
                                        return Builder(
                                          builder: (itemContext) {
                                            return GestureDetector(
                                              onLongPress: () =>
                                                  _showMessageToolbar(
                                                    itemContext,
                                                    msg,
                                                    idx,
                                                  ),
                                              child: InkWell(
                                                onTap: () => setState(() {
                                                  if (selected) {
                                                    _selectedIndices.remove(
                                                      idx,
                                                    );
                                                  } else {
                                                    _selectedIndices.add(idx);
                                                  }
                                                }),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Checkbox(
                                                      value: selected,
                                                      onChanged: (_) =>
                                                          setState(() {
                                                            if (selected) {
                                                              _selectedIndices
                                                                  .remove(idx);
                                                            } else {
                                                              _selectedIndices
                                                                  .add(idx);
                                                            }
                                                          }),
                                                    ),
                                                    Expanded(
                                                      child: IdeaBubble(
                                                        message: msg,
                                                        timeStr: _timeFmtShort
                                                            .format(
                                                              msg.createdAt,
                                                            ),
                                                        showTimeAmount:
                                                            timeVisibility,
                                                        streamingContent:
                                                            msg.id ==
                                                                _streamingMessageId
                                                            ? _streamingContent
                                                            : null,
                                                        isHidden: msg.isHidden,
                                                        onOpenFullContent: (content) =>
                                                            Navigator.of(
                                                              context,
                                                            ).push(
                                                              MaterialPageRoute(
                                                                builder: (_) =>
                                                                    MessageDetailScreen(
                                                                      content:
                                                                          content,
                                                                      title: msg
                                                                          .llmAgentName,
                                                                    ),
                                                              ),
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      }
                                      return Builder(
                                        builder: (itemContext) {
                                          return GestureDetector(
                                            onLongPress: () =>
                                                _showMessageToolbar(
                                                  itemContext,
                                                  msg,
                                                  idx,
                                                ),
                                            child: IdeaBubble(
                                              message: msg,
                                              timeStr: _timeFmtShort.format(
                                                msg.createdAt,
                                              ),
                                              showTimeAmount: timeVisibility,
                                              streamingContent:
                                                  msg.id == _streamingMessageId
                                                  ? _streamingContent
                                                  : null,
                                              isHidden: msg.isHidden,
                                              onOpenFullContent: (content) =>
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          MessageDetailScreen(
                                                            content: content,
                                                            title: msg
                                                                .llmAgentName,
                                                          ),
                                                    ),
                                                  ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                                if (showSelectToHereAtTop)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: Material(
                                      elevation: 2,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHigh,
                                      child: SafeArea(
                                        bottom: false,
                                        child: InkWell(
                                          onTap: _selectRangeToVisibleTop,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.arrow_downward,
                                                  size: 20,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '选择到这里',
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (showSelectToHereAtBottom)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Material(
                                      elevation: 2,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHigh,
                                      child: SafeArea(
                                        top: false,
                                        child: InkWell(
                                          onTap: _selectRangeToVisibleBottom,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.arrow_upward,
                                                  size: 20,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '选择到这里',
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                ),
              ),
              if (_showAtOverlay)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: AgentPickerOverlay(
                    agents: AgentStorage.getAll(),
                    onAgentSelected: (agent) {
                      _controller.text = _controller.text + agent.name + ' ';
                      _controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: _controller.text.length),
                      );
                      setState(() {
                        _atAgent = agent;
                        _showAtOverlay = false;
                      });
                    },
                    onDismiss: () => setState(() => _showAtOverlay = false),
                  ),
                ),
              if (_quotedMessage != null)
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.format_quote,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _quotedMessage!.content.length > 50
                                ? '${_quotedMessage!.content.substring(0, 50)}…'
                                : _quotedMessage!.content,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: '取消引用',
                          onPressed: () =>
                              setState(() => _quotedMessage = null),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(4),
                            minimumSize: const Size(32, 32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: '记录此刻的想法…',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _inputExpanded = true),
                            icon: const Icon(Icons.unfold_more, size: 20),
                            tooltip: '展开输入',
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(4),
                              minimumSize: const Size(32, 32),
                            ),
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 4),
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
    );
  }

  Widget _buildExpandedInput() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: TextField(
            controller: _controller,
            maxLines: null,
            minLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: '记录此刻的想法…',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              alignLabelWithHint: true,
            ),
            textInputAction: TextInputAction.newline,
            onSubmitted: (_) {},
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => setState(() => _inputExpanded = false),
            heroTag: 'collapse_input',
            tooltip: '收起',
            shape: const CircleBorder(),
            child: const Icon(Icons.unfold_less),
          ),
        ),
      ],
    );
  }
}
