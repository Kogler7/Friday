import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/repositories/repository_facade.dart';
import '../../models/transfer/transfer_pairing_payload.dart';
import '../../services/desktop_transfer_session_service.dart';
import '../../services/mobile_transfer_agent_service.dart';

class TransferBridgeScreen extends StatefulWidget {
  const TransferBridgeScreen({super.key});

  @override
  State<TransferBridgeScreen> createState() => _TransferBridgeScreenState();
}

class _TransferBridgeScreenState extends State<TransferBridgeScreen> {
  final TextEditingController _relayController = TextEditingController(
    text: 'http://127.0.0.1:8787',
  );
  TransferPairingPayload? _payload;
  bool _polling = false;
  bool _scanning = false;
  bool _handlingScan = false;
  String _status = '未连接';

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void dispose() {
    _relayController.dispose();
    DesktopTransferSessionService.closeAndClear();
    super.dispose();
  }

  Future<void> _createDesktopPairing() async {
    final relay = _relayController.text.trim();
    if (relay.isEmpty) return;
    try {
      final payload = await DesktopTransferSessionService.createPairing(
        relayBaseUrl: relay,
      );
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _status = '配对码已生成，等待手机上传';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('创建配对失败：$e')));
    }
  }

  void _startPolling() {
    if (_payload == null) return;
    DesktopTransferSessionService.startPolling(
      onDataArrived: () {
        if (!mounted) return;
        final ideaCount = RepositoryFacade.idea
            .getAllSessions(includeHidden: true)
            .length;
        final todoCount = RepositoryFacade.todo.getTodos().length;
        setState(() {
          _status = '已下载数据：会话 $ideaCount 条，待办 $todoCount 条';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已接收手机数据')));
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _status = '拉取失败：$error');
      },
    );
    setState(() {
      _polling = true;
      _status = '轮询中，等待手机上传';
    });
  }

  Future<void> _stopAndClear() async {
    await DesktopTransferSessionService.closeAndClear();
    if (!mounted) return;
    setState(() {
      _payload = null;
      _polling = false;
      _status = '会话已关闭，内存数据已清理';
    });
  }

  Future<void> _handleScan(String raw) async {
    if (_handlingScan) return;
    _handlingScan = true;
    try {
      final relay = _relayController.text.trim();
      if (relay.isEmpty) throw Exception('请先填写中转服务地址');
      final payload = TransferPairingPayload.fromCompactJson(raw);
      await MobileTransferAgentService.pushSnapshot(
        relayBaseUrl: relay,
        payload: payload,
      );
      if (!mounted) return;
      setState(() {
        _status = '手机端上传完成';
        _scanning = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已上传手机数据到临时通道')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('扫码上传失败：$e')));
    } finally {
      _handlingScan = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('跨端对接')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _relayController,
            decoration: const InputDecoration(
              labelText: '中转服务地址',
              hintText: '例如 http://127.0.0.1:8787',
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('桌面端配对', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _createDesktopPairing,
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('生成配对二维码'),
                  ),
                  if (_payload != null) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: QrImageView(
                        data: _payload!.toCompactJson(),
                        version: QrVersions.auto,
                        size: 220,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      '通道: ${_payload!.channelId}\n过期: ${_payload!.expiresAt.toLocal()}',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _polling ? null : _startPolling,
                            child: const Text('开始等待下载'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _stopAndClear,
                            child: const Text('结束并清理'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '手机端扫码上传',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (!_isMobilePlatform)
                    const Text('当前平台不支持摄像头扫码，请在手机端打开此页面。')
                  else ...[
                    FilledButton.icon(
                      onPressed: () => setState(() => _scanning = !_scanning),
                      icon: Icon(
                        _scanning ? Icons.stop : Icons.qr_code_scanner,
                      ),
                      label: Text(_scanning ? '停止扫码' : '开始扫码上传'),
                    ),
                    if (_scanning) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 280,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: MobileScanner(
                            onDetect: (capture) {
                              final raw = capture.barcodes.isNotEmpty
                                  ? capture.barcodes.first.rawValue
                                  : null;
                              if (raw == null || raw.isEmpty) return;
                              _handleScan(raw);
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(title: const Text('当前状态'), subtitle: Text(_status)),
        ],
      ),
    );
  }
}
