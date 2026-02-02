import 'package:flutter/material.dart';

/// 即时 AI 功能页面（占位）
/// [onBack] 若提供则用于返回，不依赖 Navigator.pop；此时顶部栏会延迟弹出
class InstantAiScreen extends StatefulWidget {
  const InstantAiScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<InstantAiScreen> createState() => _InstantAiScreenState();
}

class _InstantAiScreenState extends State<InstantAiScreen> with SingleTickerProviderStateMixin {
  bool _showAppBar = false;
  late final AnimationController _appBarController;
  late final Animation<double> _appBarAnimation;
  late final Animation<Offset> _appBarSlide;

  @override
  void initState() {
    super.initState();
    _appBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _appBarAnimation = CurvedAnimation(parent: _appBarController, curve: Curves.easeOutCubic);
    _appBarSlide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(_appBarAnimation);
    if (widget.onBack != null) {
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (mounted) {
          setState(() => _showAppBar = true);
          _appBarController.forward();
        }
      });
    } else {
      _showAppBar = true;
      _appBarController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _appBarController.dispose();
    super.dispose();
  }

  void _onAiButtonTap() {
    // 即时 AI 主入口按钮，后续接入功能
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 64,
                        color: colorScheme.primary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '即时 AI 功能',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '即将推出',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 64 + bottomPadding,
            child: Padding(
              padding: EdgeInsets.only(top: 8, bottom: bottomPadding),
              child: Center(
                child: Material(
                  color: colorScheme.primary,
                  elevation: 4,
                  shadowColor: colorScheme.primary.withValues(alpha: 0.5),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _onAiButtonTap,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.auto_awesome,
                        size: 28,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showAppBar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _appBarSlide,
                child: FadeTransition(
                  opacity: _appBarAnimation,
                  child: Container(
                    color: colorScheme.inversePrimary,
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: kToolbarHeight,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
                            ),
                            Expanded(
                              child: Text(
                                '即时 AI',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
