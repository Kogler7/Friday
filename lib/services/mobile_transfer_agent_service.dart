import '../data/repositories/repository_facade.dart';
import '../models/transfer/transfer_pairing_payload.dart';

class MobileTransferAgentService {
  MobileTransferAgentService._();

  static Future<void> pushSnapshot({
    required String relayBaseUrl,
    required TransferPairingPayload payload,
  }) async {
    RepositoryFacade.configureTransferClient(baseUrl: relayBaseUrl);
    await RepositoryFacade.pushLocalSnapshot(
      channelId: payload.channelId,
      token: payload.token,
    );
  }
}
