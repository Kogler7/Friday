import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// 消息全文详情：Markdown 渲染，用于长消息折叠后点击展开
class MessageDetailScreen extends StatelessWidget {
  final String content;
  final String? title;

  const MessageDetailScreen({
    super.key,
    required this.content,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? '消息详情'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Markdown(
          data: content,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyLarge,
            h1: theme.textTheme.headlineMedium,
            h2: theme.textTheme.headlineSmall,
            h3: theme.textTheme.titleLarge,
            listBullet: theme.textTheme.bodyLarge,
            blockquote: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            code: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
      ),
    );
  }
}
