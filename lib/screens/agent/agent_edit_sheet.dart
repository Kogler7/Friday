import 'package:flutter/material.dart';

import '../../models/agent/llm_agent.dart';
import '../../services/agent_storage.dart';

/// Agent 编辑底部弹窗：创建或编辑 Agent
class AgentEditSheet extends StatefulWidget {
  const AgentEditSheet({super.key, this.agent});

  final LlmAgent? agent;

  @override
  State<AgentEditSheet> createState() => _AgentEditSheetState();
}

class _AgentEditSheetState extends State<AgentEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _systemPromptController;
  late final TextEditingController _modelOverrideController;

  bool get _isEdit => widget.agent != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.agent?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.agent?.description ?? '');
    _systemPromptController =
        TextEditingController(text: widget.agent?.systemPrompt ?? '');
    _modelOverrideController =
        TextEditingController(text: widget.agent?.modelOverride ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _systemPromptController.dispose();
    _modelOverrideController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 Agent 名称')),
      );
      return;
    }

    final agent = LlmAgent(
      id: widget.agent?.id ?? AgentStorage.generateId(),
      name: name,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      systemPrompt: _systemPromptController.text.trim().isEmpty
          ? null
          : _systemPromptController.text.trim(),
      modelOverride: _modelOverrideController.text.trim().isEmpty
          ? null
          : _modelOverrideController.text.trim(),
      createdAt: widget.agent?.createdAt ?? DateTime.now(),
    );

    Navigator.pop(context, agent);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  Text(
                    _isEdit ? '编辑 Agent' : '新建 Agent',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _save,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
            // 表单
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '名称 *',
                      hintText: '如：写作助手',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: '描述（可选）',
                      hintText: '简要描述 Agent 的用途',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _systemPromptController,
                    decoration: const InputDecoration(
                      labelText: '系统提示词（可选）',
                      hintText: '定义 Agent 的角色与行为规范',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    minLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _modelOverrideController,
                    decoration: const InputDecoration(
                      labelText: '模型覆盖（可选）',
                      hintText: '如：gpt-4o，留空使用默认模型',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '提示：系统提示词会作为对话的第一条消息发送给 AI，用于定义 Agent 的角色和行为。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
