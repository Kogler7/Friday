import 'dart:convert';

import 'package:flutter/material.dart';

/// 尝试将字符串格式化为缩进 JSON，失败则返回原串
String _tryFormatJson(String raw) {
  if (raw.trim().isEmpty) return raw;
  try {
    final decoded = jsonDecode(raw);
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(decoded);
  } catch (_) {
    return raw;
  }
}

/// Agent 联网返回错误时，开发者模式下可打开的详细错误信息页
class LlmErrorDetailScreen extends StatelessWidget {
  final String title;
  final String errorMessage;
  final String? detailContent;
  /// HTTP 状态码
  final int? statusCode;
  /// 实际访问的 URL
  final String? requestUrl;
  /// 实际发送的请求体（JSON 字符串，会格式化展示）
  final String? requestBody;
  /// 收到的 HTTP 响应体（会尝试格式化 JSON）
  final String? responseBody;

  const LlmErrorDetailScreen({
    super.key,
    this.title = '错误详情',
    required this.errorMessage,
    this.detailContent,
    this.statusCode,
    this.requestUrl,
    this.requestBody,
    this.responseBody,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 12,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '错误信息',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                errorMessage,
                style: theme.textTheme.bodyMedium,
              ),
              if (statusCode != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  'HTTP 状态码: $statusCode',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (requestUrl != null && requestUrl!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  '实际访问的 URL',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: SelectableText(
                    requestUrl!,
                    style: mono,
                  ),
                ),
              ],
              if (requestBody != null && requestBody!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  '实际发送的请求体 (JSON)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: SelectableText(
                    _tryFormatJson(requestBody!),
                    style: mono,
                  ),
                ),
              ],
              if (responseBody != null && responseBody!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  '收到的 HTTP 响应体',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: SelectableText(
                    _tryFormatJson(responseBody!),
                    style: mono,
                  ),
                ),
              ],
              if (detailContent != null && detailContent!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  '详细内容',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: SelectableText(
                    detailContent!,
                    style: mono,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
