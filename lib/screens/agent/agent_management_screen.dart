import 'package:flutter/material.dart';

import '../../models/agent/llm_agent.dart';
import '../../services/agent_storage.dart';
import 'agent_edit_sheet.dart';

/// Agent 管理页面：列表展示、添加、编辑、删除、设为默认
class AgentManagementScreen extends StatefulWidget {
  const AgentManagementScreen({super.key});

  @override
  State<AgentManagementScreen> createState() => _AgentManagementScreenState();
}

class _AgentManagementScreenState extends State<AgentManagementScreen> {
  List<LlmAgent> _agents = [];
  String? _defaultAgentId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _agents = AgentStorage.getAll();
      _defaultAgentId = AgentStorage.getDefault()?.id;
    });
  }

  Future<void> _addAgent() async {
    final result = await showModalBottomSheet<LlmAgent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const AgentEditSheet(),
    );
    if (result != null) {
      await AgentStorage.save(result);
      _refresh();
    }
  }

  Future<void> _editAgent(LlmAgent agent) async {
    final result = await showModalBottomSheet<LlmAgent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AgentEditSheet(agent: agent),
    );
    if (result != null) {
      await AgentStorage.save(result);
      _refresh();
    }
  }

  Future<void> _deleteAgent(LlmAgent agent) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除 Agent'),
        content: Text('确定要删除「${agent.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AgentStorage.delete(agent.id);
      _refresh();
    }
  }

  Future<void> _setDefault(LlmAgent agent) async {
    await AgentStorage.setDefault(agent.id);
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将「${agent.name}」设为默认')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent 管理'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: _agents.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无 Agent',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _addAgent,
                    icon: const Icon(Icons.add),
                    label: const Text('添加 Agent'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _agents.length,
              itemBuilder: (context, index) {
                final agent = _agents[index];
                final isDefault = agent.id == _defaultAgentId;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDefault
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.smart_toy,
                        color: isDefault
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(child: Text(agent.name)),
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '默认',
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: agent.description != null
                        ? Text(
                            agent.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : (agent.modelOverride != null
                            ? Text(
                                '模型: ${agent.modelOverride}',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              )
                            : null),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _editAgent(agent);
                          case 'default':
                            _setDefault(agent);
                          case 'delete':
                            _deleteAgent(agent);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: 12),
                              Text('编辑'),
                            ],
                          ),
                        ),
                        if (!isDefault)
                          const PopupMenuItem(
                            value: 'default',
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, size: 20),
                                SizedBox(width: 12),
                                Text('设为默认'),
                              ],
                            ),
                          ),
                        if (agent.id != 'default')
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 20),
                                SizedBox(width: 12),
                                Text('删除'),
                              ],
                            ),
                          ),
                      ],
                    ),
                    onTap: () => _editAgent(agent),
                  ),
                );
              },
            ),
      floatingActionButton: _agents.isNotEmpty
          ? FloatingActionButton(
              onPressed: _addAgent,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
