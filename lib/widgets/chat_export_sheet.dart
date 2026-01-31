import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/idea/chat_message.dart';

/// 按日期范围选择聊天记录，拼接为文本，支持复制或导出（分享）
class ChatExportSheet extends StatefulWidget {
  final List<ChatMessage> messages;
  final VoidCallback? onExported;

  const ChatExportSheet({
    super.key,
    required this.messages,
    this.onExported,
  });

  @override
  State<ChatExportSheet> createState() => _ChatExportSheetState();
}

class _ChatExportSheetState extends State<ChatExportSheet> {
  DateTime _start = DateTime.now().subtract(const Duration(days: 7));
  DateTime _end = DateTime.now();
  List<ChatMessage> _filtered = [];
  static final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  static final DateFormat _timeFmt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _applyRange();
  }

  void _applyRange() {
    final startDay = DateTime(_start.year, _start.month, _start.day);
    final endDay = DateTime(_end.year, _end.month, _end.day, 23, 59, 59, 999);
    setState(() {
      _filtered = widget.messages
          .where((m) =>
              !m.createdAt.isBefore(startDay) && !m.createdAt.isAfter(endDay))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
  }

  String _buildExportText() {
    if (_filtered.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('想法记录 ${_dateFmt.format(_start)} — ${_dateFmt.format(_end)}');
    buffer.writeln();
    for (final m in _filtered) {
      buffer.writeln(_timeFmt.format(m.createdAt));
      buffer.writeln(m.content);
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  Future<void> _copy() async {
    final text = _buildExportText();
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前范围内没有记录')),
        );
      }
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制到剪贴板')),
      );
    }
  }

  Future<void> _share() async {
    final text = _buildExportText();
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前范围内没有记录')),
        );
      }
      return;
    }
    await Share.share(
      text,
      subject: '想法记录 ${_dateFmt.format(_start)} — ${_dateFmt.format(_end)}',
    );
    widget.onExported?.call();
  }

  @override
  Widget build(BuildContext context) {
    final text = _buildExportText();
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '导出想法记录',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _start,
                          firstDate: DateTime(2020),
                          lastDate: _end,
                        );
                        if (picked != null) {
                          setState(() {
                            _start = picked;
                            if (_start.isAfter(_end)) _end = _start;
                            _applyRange();
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(_dateFmt.format(_start)),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('—'),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _end,
                          firstDate: _start,
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            _end = picked;
                            if (_end.isBefore(_start)) _start = _end;
                            _applyRange();
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(_dateFmt.format(_end)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '共 ${_filtered.length} 条',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      text.isEmpty ? '（该范围内无记录）' : text,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: text.isEmpty ? null : _copy,
                      icon: const Icon(Icons.copy),
                      label: const Text('复制'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: text.isEmpty ? null : _share,
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
