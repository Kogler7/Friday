import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../constants/app_config.dart' show userDeveloperMode;
import '../../models/idea/chat_message.dart';
import '../../models/idea/idea_session.dart';
import '../../services/local_auth_service.dart';
import '../../services/idea_session_storage.dart';
import 'idea_bubble.dart';
import 'idea_export_sheet.dart';

/// 供 MainShell 渲染会话历史 endDrawer 时使用的属性
class IdeaDrawerProps {
  final String? currentSessionId;
  final bool isDevMode;
  final ValueChanged<IdeaSession> onSessionSelected;
  final VoidCallback onNewSession;
  final VoidCallback onSessionsChanged;

  const IdeaDrawerProps({
    required this.currentSessionId,
    required this.isDevMode,
    required this.onSessionSelected,
    required this.onNewSession,
    required this.onSessionsChanged,
  });
}

/// 想法页：多会话管理，左侧抽屉为个人页、右侧 endDrawer 为会话历史（AppBar 右侧按钮或左滑唤起）；右滑展示消息时间
class IdeaScreen extends StatefulWidget {
  final void Function(IdeaDrawerProps)? onSessionDrawerPropsReady;
  final void Function(List<Widget>)? onAppBarActionsReady;
  final VoidCallback? onOpenSessionHistory;

  const IdeaScreen({
    super.key,
    this.onSessionDrawerPropsReady,
    this.onAppBarActionsReady,
    this.onOpenSessionHistory,
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

  _MessageEntry._({this.isDivider = false, this.dividerTime, this.message, this.messageIndex});

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
  static final DateFormat _timeFmtFull = DateFormat('yyyy-MM-dd HH:mm');

  /// 多选模式：左侧复选框，选中后可导出
  bool _multiSelectMode = false;
  final Set<int> _selectedIndices = <int>{};

  /// 输入框是否展开为接近全屏高度
  bool _inputExpanded = false;

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
    userDeveloperMode.addListener(_onUserDevModeChanged);
  }

  @override
  void dispose() {
    userDeveloperMode.removeListener(_onUserDevModeChanged);
    _snapBackController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onUserDevModeChanged() {
    if (userDeveloperMode.value) return;
    IdeaSessionStorage.ensureCurrentSessionVisible().then((_) {
      if (mounted) _loadCurrentSession();
    });
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
      if (mounted) setState(() {
        _dragAccumDx = 0;
        _dragStartX = null;
      });
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
      _messages = List.from(session.messages)..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
  }

  Future<void> _switchToSession(IdeaSession session) async {
    if (session.isLocked) {
      final result = await LocalAuthService.authenticate(
        reason: '验证身份以查看该会话',
      );
      if (result == LocalAuthResult.failed) {
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
    _controller.clear();
    if (_currentSession == null) {
      final session = await IdeaSessionStorage.createSessionWithFirstMessage(
        text,
      );
      await IdeaSessionStorage.setCurrentSessionId(session.id);
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
      return;
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

  @override
  Widget build(BuildContext context) {
    // 延后到 build 结束后再通知父组件，避免在 build 中调用父组件 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onSessionDrawerPropsReady?.call(IdeaDrawerProps(
        currentSessionId: _currentSession?.id,
        isDevMode: _isDevMode,
        onSessionSelected: _switchToSession,
        onNewSession: _createAndSwitchToNewSession,
        onSessionsChanged: _loadCurrentSession,
      ));
      final actions = _multiSelectMode
          ? [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: '取消多选',
                onPressed: () => setState(() {
                  _multiSelectMode = false;
                  _selectedIndices.clear();
                }),
              ),
              IconButton(
                icon: const Icon(Icons.upload_file),
                tooltip: '导出选中',
                onPressed: _selectedIndices.isEmpty
                    ? null
                    : () {
                        final selected = _selectedIndices
                            .map((i) => _messages[i])
                            .toList()
                          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
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
              if (_messages.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: '多选',
                  onPressed: () => setState(() => _multiSelectMode = true),
                ),
            ];
      widget.onAppBarActionsReady?.call(actions);
    });

    return Scaffold(
      body: Builder(
        builder: (scaffoldContext) {
          if (_inputExpanded) {
            return Column(
              children: [
                Expanded(child: _buildExpandedInput()),
              ],
            );
          }
          return Column(
            children: [
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
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
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: widget.onOpenSessionHistory != null
                                    ? widget.onOpenSessionHistory!
                                    : () => Scaffold.of(scaffoldContext).openEndDrawer(),
                                icon: const Icon(Icons.history),
                                label: const Text('会话历史'),
                              ),
                            ],
                          ),
                        )
                      : Builder(
                        builder: (context) {
                          final messageEntries = _buildMessageEntries();
                          final timeVisibility = (_dragAccumDx / _dragForFullTime)
                              .clamp(0.0, 1.0);
                          return Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (_) {
                              _dragStartX = null;
                            },
                            onPointerMove: (e) {
                              _dragStartX ??= e.position.dx;
                              final dx = e.delta.dx;
                              final dy = e.delta.dy;
                              if (dy.abs() > 2 * dx.abs()) return;
                              setState(() {
                                _dragAccumDx += dx;
                                if (_dragAccumDx < -_dragToOpenSessionHistory) {
                                  _dragAccumDx = 0;
                                  _dragStartX = null;
                                  widget.onOpenSessionHistory?.call();
                                }
                              });
                            },
                            onPointerUp: (_) {
                              _snapBackTime();
                            },
                            onPointerCancel: (_) {
                              _snapBackTime();
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
                              final timeStr =
                                  _timeFmtFull.format(entry.dividerTime!);
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: Divider(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
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
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final msg = entry.message!;
                            final idx = entry.messageIndex!;
                            if (_multiSelectMode) {
                              final selected = _selectedIndices.contains(idx);
                              return InkWell(
                                onTap: () => setState(() {
                                  if (selected) {
                                    _selectedIndices.remove(idx);
                                  } else {
                                    _selectedIndices.add(idx);
                                  }
                                }),
                                child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Checkbox(
                                        value: selected,
                                        onChanged: (_) => setState(() {
                                          if (selected) {
                                            _selectedIndices.remove(idx);
                                          } else {
                                            _selectedIndices.add(idx);
                                          }
                                        }),
                                      ),
                                      Expanded(
                                        child: IdeaBubble(
                                          message: msg,
                                          timeStr: _timeFmtFull.format(msg.createdAt),
                                          showTimeAmount: timeVisibility,
                                        ),
                                      ),
                                    ],
                                ),
                              );
                            }
                            return GestureDetector(
                              onLongPress: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: msg.content),
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已复制')),
                                  );
                                }
                              },
                              child: IdeaBubble(
                                message: msg,
                                timeStr: _timeFmtFull.format(msg.createdAt),
                                showTimeAmount: timeVisibility,
                              ),
                            );
                          },
                            ),
                          );
                        },
                      ),
                ),
              ),
              const Divider(height: 1),
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
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => setState(() => _inputExpanded = true),
                      icon: const Icon(Icons.unfold_more),
                      tooltip: '展开输入',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: TextField(
              controller: _controller,
              maxLines: null,
              minLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: '记录想法…',
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
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => setState(() => _inputExpanded = false),
                icon: const Icon(Icons.unfold_less),
                tooltip: '收起',
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
  }
}
