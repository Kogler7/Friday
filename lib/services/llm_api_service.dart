import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/agent/llm_agent.dart';
import 'agent_storage.dart';
import 'settings_service.dart';

/// 单条消息（兼容 OpenAI Chat Completions 格式）
class LlmMessage {
  final String role; // 'system' | 'user' | 'assistant'
  final String content;

  const LlmMessage({required this.role, required this.content});

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// LLM API 调用服务，兼容 OpenAI Chat Completions 接口
/// 使用设置中的 API 接入点、密钥、模型，可被想法、即时 AI 等模块接入
class LlmApiService {
  LlmApiService._();

  static const String _defaultModel = 'gpt-4o-mini';
  static const String _defaultEndpoint = 'https://api.openai.com/v1';

  /// 检查是否已配置（有接入点和密钥）
  static bool get isConfigured {
    final p = SettingsService.current;
    final endpoint = (p.aiApiEndpoint ?? '').trim();
    final key = (p.aiApiKey ?? '').trim();
    return endpoint.isNotEmpty && key.isNotEmpty;
  }

  static String get _endpoint {
    var e = (SettingsService.current.aiApiEndpoint ?? '').trim();
    if (e.isEmpty) return _defaultEndpoint;
    if (e.endsWith('/')) e = e.substring(0, e.length - 1);
    return e;
  }

  static String get _apiKey =>
      (SettingsService.current.aiApiKey ?? '').trim();

  static String _model(String? override) {
    final m = (override ?? SettingsService.current.aiModel ?? '').trim();
    return m.isNotEmpty ? m : _defaultModel;
  }

  /// 使用指定或默认 Agent 进行非流式聊天
  static Future<LlmChatResult> chatWithAgent({
    required List<LlmMessage> messages,
    LlmAgent? agent,
    double temperature = 0.7,
  }) {
    final a = agent ?? AgentStorage.getDefault();
    return chat(
      messages: messages,
      systemPrompt: a?.systemPrompt,
      modelOverride: a?.modelOverride,
      temperature: temperature,
    );
  }

  /// 使用指定或默认 Agent 进行流式聊天
  static Stream<String> chatStreamWithAgent({
    required List<LlmMessage> messages,
    LlmAgent? agent,
    double temperature = 0.7,
  }) {
    final a = agent ?? AgentStorage.getDefault();
    return chatStream(
      messages: messages,
      systemPrompt: a?.systemPrompt,
      modelOverride: a?.modelOverride,
      temperature: temperature,
    );
  }

  /// 非流式聊天补全
  /// [messages] 对话历史，[systemPrompt] 可选系统提示（会插入到首条）
  /// [modelOverride] 可选模型覆盖（如 Agent 指定）
  static Future<LlmChatResult> chat({
    required List<LlmMessage> messages,
    String? systemPrompt,
    String? modelOverride,
    double temperature = 0.7,
  }) async {
    if (!isConfigured) {
      return LlmChatResult.fail('请先在设置中配置 API 接入点和密钥');
    }

    final body = <String, dynamic>{
      'model': _model(modelOverride),
      'messages': _buildMessages(messages, systemPrompt),
      'temperature': temperature,
    };

    try {
      final url = Uri.parse('$_endpoint/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        final err = _parseError(response);
        return LlmChatResult.fail(err);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        return LlmChatResult.fail('接口返回无有效内容');
      }
      final msg = choices[0] as Map<String, dynamic>;
      final content = (msg['message'] as Map<String, dynamic>?)?['content'] as String?;
      return LlmChatResult.success(content ?? '');
    } on Exception catch (e) {
      return LlmChatResult.fail(e.toString());
    }
  }

  /// 流式聊天补全，返回 content 增量流
  static Stream<String> chatStream({
    required List<LlmMessage> messages,
    String? systemPrompt,
    String? modelOverride,
    double temperature = 0.7,
  }) async* {
    if (!isConfigured) {
      throw LlmApiException('请先在设置中配置 API 接入点和密钥');
    }

    final body = <String, dynamic>{
      'model': _model(modelOverride),
      'messages': _buildMessages(messages, systemPrompt),
      'temperature': temperature,
      'stream': true,
    };

    final url = Uri.parse('$_endpoint/chat/completions');
    final bodyJson = jsonEncode(body);
    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $_apiKey'
      ..body = bodyJson;

    final client = http.Client();
    final response = await client.send(request);

    if (response.statusCode != 200) {
      final responseBody = await response.stream.bytesToString();
      client.close();
      throw LlmApiException(
        _parseErrorFromBody(response.statusCode, responseBody),
        statusCode: response.statusCode,
        requestUrl: url.toString(),
        requestBody: bodyJson,
        responseBody: responseBody,
      );
    }

    String buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.removeLast();
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') continue;
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final choices = json['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final delta = (choices[0] as Map<String, dynamic>)['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            }
          } catch (_) {}
        }
      }
    }
    client.close();
  }

  static List<Map<String, String>> _buildMessages(
    List<LlmMessage> messages,
    String? systemPrompt,
  ) {
    final list = <Map<String, String>>[];
    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      list.add({'role': 'system', 'content': systemPrompt.trim()});
    }
    for (final m in messages) {
      list.add(m.toJson());
    }
    return list;
  }

  static String _parseError(http.Response response) =>
      _parseErrorFromBody(response.statusCode, response.body);

  static String _parseErrorFromBody(int statusCode, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>?;
      final err = json?['error'] as Map<String, dynamic>?;
      final msg = err?['message'] as String?;
      if (msg != null) return msg;
    } catch (_) {}
    return '请求失败 (HTTP $statusCode)';
  }
}

/// 非流式调用结果
class LlmChatResult {
  final bool success;
  final String content;
  final String? error;

  LlmChatResult._({required this.success, required this.content, this.error});

  factory LlmChatResult.success(String content) =>
      LlmChatResult._(success: true, content: content);

  factory LlmChatResult.fail(String error) =>
      LlmChatResult._(success: false, content: '', error: error);
}

class LlmApiException implements Exception {
  final String message;
  /// HTTP 状态码（若为 HTTP 错误）
  final int? statusCode;
  /// 实际访问的 URL
  final String? requestUrl;
  /// 实际发送的请求体（JSON 字符串）
  final String? requestBody;
  /// 收到的 HTTP 响应体
  final String? responseBody;

  LlmApiException(
    this.message, {
    this.statusCode,
    this.requestUrl,
    this.requestBody,
    this.responseBody,
  });

  @override
  String toString() => message;
}
