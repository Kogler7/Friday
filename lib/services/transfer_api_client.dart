import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/transfer/transfer_snapshot.dart';

class TransferChannelInfo {
  final String channelId;
  final String token;
  final DateTime expiresAt;

  const TransferChannelInfo({
    required this.channelId,
    required this.token,
    required this.expiresAt,
  });

  factory TransferChannelInfo.fromJson(Map<String, dynamic> json) {
    return TransferChannelInfo(
      channelId: json['channelId'] as String,
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}

class TransferApiClient {
  TransferApiClient({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Future<TransferChannelInfo> createChannel({
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final uri = Uri.parse('$_baseUrl/channel/create');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ttlSeconds': ttl.inSeconds}),
    );
    if (response.statusCode != 200) {
      throw TransferApiException('创建通道失败 (HTTP ${response.statusCode})');
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return TransferChannelInfo.fromJson(map);
  }

  Future<void> pushData({
    required String channelId,
    required String token,
    required TransferSnapshot snapshot,
  }) async {
    final uri = Uri.parse('$_baseUrl/channel/$channelId/push');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(snapshot.toJson()),
    );
    if (response.statusCode != 200) {
      throw TransferApiException('上传数据失败 (HTTP ${response.statusCode})');
    }
  }

  Future<TransferSnapshot?> pullData({
    required String channelId,
    required String token,
  }) async {
    final uri = Uri.parse('$_baseUrl/channel/$channelId/pull');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 204) return null;
    if (response.statusCode != 200) {
      throw TransferApiException('拉取数据失败 (HTTP ${response.statusCode})');
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return TransferSnapshot.fromJson(map);
  }

  Future<void> expireChannel({
    required String channelId,
    required String token,
  }) async {
    final uri = Uri.parse('$_baseUrl/channel/$channelId/expire');
    final response = await _client.post(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw TransferApiException('关闭通道失败 (HTTP ${response.statusCode})');
    }
  }

  void dispose() {
    _client.close();
  }
}

class TransferApiException implements Exception {
  final String message;
  TransferApiException(this.message);

  @override
  String toString() => message;
}
