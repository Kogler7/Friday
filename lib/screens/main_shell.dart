import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'home_screen.dart';
import 'smart_screen.dart';
import 'status_screen.dart';
import 'todo_screen.dart';

/// 底部导航：想法、状态、智能(中)、待办、主页
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 4; // 默认主页

  static const List<_NavItem> _items = [
    _NavItem(label: '想法', icon: Icons.chat_bubble_outline),
    _NavItem(label: '状态', icon: Icons.pie_chart_outline),
    _NavItem(label: '智能', icon: Icons.mic),
    _NavItem(label: '待办', icon: Icons.check_circle_outline),
    _NavItem(label: '主页', icon: Icons.home_outlined),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const ChatScreen(),
      const StatusScreen(),
      const SmartScreen(),
      const TodoScreen(),
      const HomeScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    const int smartIndex = 2;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomAppBar(
        height: 64,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, 0, colorScheme),
            _buildNavItem(context, 1, colorScheme),
            _buildCenterSmartButton(context, colorScheme, smartIndex),
            _buildNavItem(context, 3, colorScheme),
            _buildNavItem(context, 4, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    ColorScheme colorScheme,
  ) {
    final item = _items[index];
    final selected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? _selectedIcon(item.icon) : item.icon,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _selectedIcon(IconData outline) {
    if (outline == Icons.chat_bubble_outline) return Icons.chat_bubble;
    if (outline == Icons.pie_chart_outline) return Icons.pie_chart;
    if (outline == Icons.check_circle_outline) return Icons.check_circle;
    if (outline == Icons.home_outlined) return Icons.home;
    return outline;
  }

  Widget _buildCenterSmartButton(
    BuildContext context,
    ColorScheme colorScheme,
    int smartIndex,
  ) {
    final selected = _currentIndex == smartIndex;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.primary,
          elevation: 4,
          shadowColor: colorScheme.primary.withOpacity(0.5),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => setState(() => _currentIndex = smartIndex),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.mic,
                size: 28,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem({required this.label, required this.icon});
}
