import 'dart:convert';

class TransferPairingPayload {
  final String channelId;
  final String token;
  final DateTime expiresAt;

  const TransferPairingPayload({
    required this.channelId,
    required this.token,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'channelId': channelId,
      'token': token,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  String toCompactJson() => jsonEncode(toJson());

  factory TransferPairingPayload.fromJson(Map<String, dynamic> json) {
    return TransferPairingPayload(
      channelId: json['channelId'] as String,
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  factory TransferPairingPayload.fromCompactJson(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return TransferPairingPayload.fromJson(map);
  }
}
