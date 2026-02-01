import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/idea/chat_message.dart';

/// 导出格式：每条消息「时间+换行+内容」或 多条拼接（可设分隔符）
enum IdeaExportFormat {
  /// 每条：时间 + 换行 + 消息内容
  timeAndContentPerMessage,
  /// 多条拼接，中间用分隔符
  concatenatedWithSeparator,
}

/// 想法多选导出：选择格式（每条时间+内容 / 多条拼接+分隔符），复制或分享
class IdeaExportSheet extends StatefulWidget {
  final List<ChatMessage> messages;
  final VoidCallback? onExported;

  const IdeaExportSheet({
    super.key,
    required this.messages,
    this.onExported,
  });

  @override
  State<IdeaExportSheet> createState() => _IdeaExportSheetState();
}

class _IdeaExportSheetState extends State<IdeaExportSheet> {
  IdeaExportFormat _format = IdeaExportFormat.timeAndContentPerMessage;
  final TextEditingController _separatorController = TextEditingController(text: '。');
  static final DateFormat _timeFmt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void dispose() {
    _separatorController.dispose();
    super.dispose();
  }

  String _buildExportText() {
    final list = widget.messages;
    if (list.isEmpty) return '';
    switch (_format) {
      case IdeaExportFormat.timeAndContentPerMessage:
        final buffer = StringBuffer();
        for (final m in list) {
          buffer.writeln(_timeFmt.format(m.createdAt));
          buffer.writeln(m.content);
          buffer.writeln();
        }
        return buffer.toString().trimRight();
      case IdeaExportFormat.concatenatedWithSeparator:
        final sep = _separatorController.text.isEmpty ? '。' : _separatorController.text;
        return list.map((m) => m.content).join(sep);
    }
  }

  Future<void> _copy() async {
    final text = _buildExportText();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制到剪贴板')),
      );
    }
  }

  Future<void> _share() async {
    final text = _buildExportText();
    if (text.isEmpty) return;
    await Share.share(text, subject: '想法记录');
    widget.onExported?.call();
  }

  @override
  Widget build(BuildContext context) {
    final text = _buildExportText();
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '导出格式',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              RadioListTile<IdeaExportFormat>(
                value: IdeaExportFormat.timeAndContentPerMessage,
                groupValue: _format,
                onChanged: (v) => setState(() => _format = v!),
                title: const Text('每条消息：时间 + 换行 + 消息内容'),
                dense: true,
              ),
              RadioListTile<IdeaExportFormat>(
                value: IdeaExportFormat.concatenatedWithSeparator,
                groupValue: _format,
                onChanged: (v) => setState(() => _format = v!),
                title: const Text('多条消息拼接'),
                dense: true,
              ),
              if (_format == IdeaExportFormat.concatenatedWithSeparator) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
                  child: TextField(
                    controller: _separatorController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: '分隔符',
                      hintText: '。',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '共 ${widget.messages.length} 条',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      text.isEmpty ? '（无内容）' : text,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy),
                      label: const Text('复制'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _share,
                      icon: const Icon(Icons.share),
                      label: const Text('导出 / 分享'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
