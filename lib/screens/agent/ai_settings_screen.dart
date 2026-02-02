import 'package:flutter/material.dart';

import '../../services/settings_service.dart';

/// AI 接入配置页面（API 接入点、密钥、模型）
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late TextEditingController _endpointController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final p = SettingsService.current;
    _endpointController = TextEditingController(text: p.aiApiEndpoint ?? '');
    _apiKeyController = TextEditingController(text: p.aiApiKey ?? '');
    _modelController = TextEditingController(text: p.aiModel ?? '');
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await SettingsService.save(
      SettingsService.current.copyWith(
        aiApiEndpoint: _endpointController.text.trim().isEmpty
            ? null
            : _endpointController.text.trim(),
        aiApiKey: _apiKeyController.text.trim().isEmpty
            ? null
            : _apiKeyController.text.trim(),
        aiModel: _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('API 接入配置'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '接入点与密钥',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _endpointController,
                    decoration: const InputDecoration(
                      labelText: 'API 接入点',
                      hintText: 'https://api.openai.com/v1',
                      border: OutlineInputBorder(),
                      helperText: '兼容 OpenAI API 的接入点地址',
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiKeyController,
                    decoration: InputDecoration(
                      labelText: 'API 密钥',
                      hintText: 'sk-...',
                      border: const OutlineInputBorder(),
                      helperText: '密钥仅存储在本地，不会上传',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureKey ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscureKey = !_obscureKey);
                        },
                      ),
                    ),
                    obscureText: _obscureKey,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: '默认模型（可选）',
                      hintText: 'gpt-4o-mini',
                      border: OutlineInputBorder(),
                      helperText: '留空则使用 gpt-4o-mini',
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '说明',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 支持 OpenAI 及兼容 API（如 Azure、国内代理等）\n'
                    '• Agent 可单独指定模型，覆盖此处的默认模型\n'
                    '• 所有配置仅存储在本地设备',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
