import 'package:flutter/material.dart';

import '../../models/agent/llm_agent.dart';

/// 输入 @ 后弹出的 Agent 选择浮层
class AgentPickerOverlay extends StatelessWidget {
  final List<LlmAgent> agents;
  final ValueChanged<LlmAgent> onAgentSelected;
  final VoidCallback onDismiss;

  const AgentPickerOverlay({
    super.key,
    required this.agents,
    required this.onAgentSelected,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (agents.isEmpty) {
      return Material(
        elevation: 8,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '暂无可用助手，请先在设置中添加',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Material(
      elevation: 8,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      color: colorScheme.surfaceContainerHighest,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320, minWidth: 280),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '选择助手',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                itemCount: agents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final agent = agents[index];
                  final hasDesc = agent.description != null &&
                      agent.description!.trim().isNotEmpty;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onAgentSelected(agent),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer
                                    .withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.psychology_outlined,
                                size: 22,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    agent.name,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (hasDesc) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      agent.description!.trim(),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
