import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 单侧滑动的配置：图标、圆形背景色、图标色、松手过阈值或点击时回调
class SwipeActionConfig {
  final IconData icon;
  final Color backgroundColor;
  final Color? iconColor;
  final VoidCallback? onTrigger;

  const SwipeActionConfig({
    required this.icon,
    required this.backgroundColor,
    this.iconColor,
    this.onTrigger,
  });
}

/// 通用左右滑条目：左滑/右滑展示圆形动画与图标，松手过阈值或点击图标触发回调。
/// 使用 [ValueNotifier] 驱动偏移，避免 setState 导致手势丢失。
class SlidableActionTile extends StatefulWidget {
  /// 主内容（会随滑动平移）
  final Widget child;

  /// 左滑时的动作（图标与圆形颜色）；为 null 则不可左滑
  final SwipeActionConfig? leftAction;

  /// 右滑时的动作；为 null 则不可右滑
  final SwipeActionConfig? rightAction;

  /// 左滑松手过此比例宽度时触发 [leftAction] 回调
  final double leftTriggerRatio;

  /// 右滑松手过此比例宽度时触发 [rightAction] 回调
  final double rightTriggerRatio;

  /// 最大滑动比例（相对宽度）
  final double maxSwipeRatio;

  /// 条目固定高度；在 ListView 中建议显式指定
  final double height;

  const SlidableActionTile({
    super.key,
    required this.child,
    this.leftAction,
    this.rightAction,
    this.leftTriggerRatio = 0.45,
    this.rightTriggerRatio = 0.45,
    this.maxSwipeRatio = 0.75,
    this.height = 56,
  });

  @override
  State<SlidableActionTile> createState() => _SlidableActionTileState();
}

class _SlidableActionTileState extends State<SlidableActionTile>
    with SingleTickerProviderStateMixin {
  static const double _actionWidth = 48;

  final ValueNotifier<double> _dragOffset = ValueNotifier<double>(0);
  late AnimationController _animController;
  late Animation<double> _animOffset;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _dragOffset.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onDragEnd(double width) {
    final value = _dragOffset.value;

    if (value > width * widget.rightTriggerRatio && widget.rightAction != null) {
      widget.rightAction!.onTrigger?.call();
      _dragOffset.value = 0;
      return;
    }
    if (value < -width * widget.leftTriggerRatio && widget.leftAction != null) {
      widget.leftAction!.onTrigger?.call();
      _dragOffset.value = 0;
      return;
    }
    _animateBack(value);
  }

  void _animateBack(double startOffset) {
    _animOffset = Tween<double>(begin: startOffset, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    void listener() {
      if (mounted) _dragOffset.value = _animOffset.value;
    }
    _animController.addListener(listener);
    _animController.forward(from: 0).then((_) {
      _animController.removeListener(listener);
      if (mounted) _dragOffset.value = 0;
      _animController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : widget.height;
          final maxSwipe = w * widget.maxSwipeRatio;
          final maxRadius = math.sqrt(w * w + (h / 2) * (h / 2)) + 20;
          final iconCenterX = _actionWidth / 2;

          final canLeft = widget.leftAction != null;
          final canRight = widget.rightAction != null;

          return ClipRect(
            clipBehavior: Clip.hardEdge,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                var v = _dragOffset.value + details.delta.dx;
                if (!canRight) v = v.clamp(-maxSwipe, 0.0);
                if (!canLeft) v = v.clamp(0.0, maxSwipe);
                if (canLeft && canRight) v = v.clamp(-maxSwipe, maxSwipe);
                _dragOffset.value = v;
              },
              onHorizontalDragEnd: (_) => _onDragEnd(w),
              onHorizontalDragCancel: () => _onDragEnd(w),
              behavior: HitTestBehavior.opaque,
              child: ValueListenableBuilder<double>(
                valueListenable: _dragOffset,
                builder: (context, offset, _) {
                  final tRight = offset <= 0
                      ? 0.0
                      : (offset / maxSwipe).clamp(0.0, 1.0);
                  final tLeft = offset >= 0
                      ? 0.0
                      : (-offset / maxSwipe).clamp(0.0, 1.0);
                  final radiusRight =
                      maxRadius * math.pow(tRight, 2).toDouble();
                  final radiusLeft = maxRadius * math.pow(tLeft, 2).toDouble();
                  final leftConfig = widget.leftAction;
                  final rightConfig = widget.rightAction;

                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      if (offset < 0 && leftConfig != null) ...[
                        Positioned(
                          left: w - iconCenterX - radiusLeft,
                          top: h / 2 - radiusLeft,
                          width: radiusLeft * 2,
                          height: radiusLeft * 2,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: leftConfig.backgroundColor,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: _actionWidth,
                          child: Material(
                            color: Colors.transparent,
                            child: Center(
                              child: IconButton(
                                icon: Icon(
                                  leftConfig.icon,
                                  color: leftConfig.iconColor ??
                                      _contrastColor(leftConfig.backgroundColor),
                                  size: 22,
                                ),
                                onPressed: () {
                                  leftConfig.onTrigger?.call();
                                  _dragOffset.value = 0;
                                },
                                style: IconButton.styleFrom(
                                  foregroundColor: leftConfig.iconColor ??
                                      _contrastColor(leftConfig.backgroundColor),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (offset > 0 && rightConfig != null) ...[
                        Positioned(
                          left: iconCenterX - radiusRight,
                          top: h / 2 - radiusRight,
                          width: radiusRight * 2,
                          height: radiusRight * 2,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: rightConfig.backgroundColor,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: _actionWidth,
                          child: Center(
                            child: Icon(
                              rightConfig.icon,
                              color: rightConfig.iconColor ??
                                  _contrastColor(rightConfig.backgroundColor),
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                      Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        bottom: 0,
                        child: Transform.translate(
                          offset: Offset(offset, 0),
                          child: widget.child,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  static Color _contrastColor(Color bg) {
    return bg.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;
  }
}
