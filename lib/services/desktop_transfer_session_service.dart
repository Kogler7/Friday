import 'dart:async';

import '../data/repositories/repository_facade.dart';
import '../models/transfer/transfer_pairing_payload.dart';
import 'transfer_api_client.dart';

class DesktopTransferSessionService {
  DesktopTransferSessionService._();

  static Timer? _pollTimer;
  static TransferPairingPayload? _activePayload;

  static TransferPairingPayload? get activePayload => _activePayload;

  static Future<TransferPairingPayload> createPairing({
    required String relayBaseUrl,
    Duration ttl = const Duration(minutes: 5),
  }) async {
    RepositoryFacade.configureTransferClient(baseUrl: relayBaseUrl);
    final info = await RepositoryFacade.createTransferChannel(ttl: ttl);
    _activePayload = TransferPairingPayload(
      channelId: info.channelId,
      token: info.token,
      expiresAt: info.expiresAt,
    );
    return _activePayload!;
  }

  static void startPolling({
    Duration interval = const Duration(seconds: 2),
    void Function()? onDataArrived,
    void Function(Object error)? onError,
  }) {
    final payload = _activePayload;
    if (payload == null) return;
    _pollTimer?.cancel();
    RepositoryFacade.switchMode(RepositoryMode.remote);
    _pollTimer = Timer.periodic(interval, (_) async {
      if (DateTime.now().isAfter(payload.expiresAt)) {
        await closeAndClear();
        return;
      }
      try {
        final pulled = await RepositoryFacade.pullRemoteSnapshot(
          channelId: payload.channelId,
          token: payload.token,
        );
        if (pulled) onDataArrived?.call();
      } catch (e) {
        onError?.call(e);
      }
    });
  }

  static Future<void> closeAndClear() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    final payload = _activePayload;
    if (payload != null) {
      try {
        await RepositoryFacade.expireTransferChannel(
          channelId: payload.channelId,
          token: payload.token,
        );
      } on TransferApiException {
        // 会话清理以本地为主，通道关闭失败不阻断。
      }
    }
    _activePayload = null;
    RepositoryFacade.clearRemoteCache();
    RepositoryFacade.switchMode(RepositoryMode.local);
  }
}
