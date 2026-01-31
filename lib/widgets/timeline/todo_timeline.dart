import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

import '../../models/event/todo_item.dart';
import 'constants.dart';
import 'models.dart';
import 'painters.dart';

/// 可缩放、可滑动、多日、自动归位、一键还原的时间轴
class TodoTimeline extends StatefulWidget {
  final List<TodoItem> items;
  final DateTime today;
  final VoidCallback? onRefresh;
  final void Function(TodoItem)? onItemTap;

  const TodoTimeline({
    super.key,
    required this.items,
    required this.today,
    this.onRefresh,
    this.onItemTap,
  });

  @override
  State<TodoTimeline> createState() => _TodoTimelineState();
}

class _TodoTimelineState extends State<TodoTimeline>
    with TickerProviderStateMixin {
  int get _daysCount => kDaysBeforeToday + 1 + kDaysAfterToday;
  int get _todayIndex => kDaysBeforeToday;

  final ScrollController _scrollController = ScrollController();
  int _granularityIndex = kDefaultGranularityIndex;
  Timer? _recenterTimer;

  /// 粒度过渡动画：目标档位非空时表示正在动画中
  int? _animatingToGranularityIndex;
  double _granularityAnimationT = 0.0;
  late AnimationController _granularityAnimationController;
  late Animation<double> _granularityAnimation;

  /// 双指缩放
  final Map<int, Offset> _pointerPositions = {};
  double? _pinchStartDistance;
  int _granularityAtPinchStart = kDefaultGranularityIndex;
  double? _pinchAnchorViewportY;
  int? _pinchAnchorDayIndex;
  int? _pinchAnchorMinuteOfDay;
  final GlobalKey _scrollContentKey = GlobalKey();
  bool _pinchStepApplied = false;
  int? _pendingGranularityIndex;
  bool _scaleUpdateScheduled = false;

  /// 当前用于布局的日高与每小时像素（动画中在源与目标间插值，刻度线平移而非拉伸）
  double get _displayDayHeight {
    if (_animatingToGranularityIndex == null) return dayHeightFor(_granularityIndex);
    final t = _granularityAnimationT;
    return lerpDouble(
      dayHeightFor(_granularityIndex),
      dayHeightFor(_animatingToGranularityIndex!),
      t,
    )!;
  }

  double get _displayPixelsPerHour {
    if (_animatingToGranularityIndex == null) return pixelsPerHourFor(_granularityIndex);
    final t = _granularityAnimationT;
    return lerpDouble(
      pixelsPerHourFor(_granularityIndex),
      pixelsPerHourFor(_animatingToGranularityIndex!),
      t,
    )!;
  }

  /// 过渡中文字透明度：前一半渐隐，后一半渐显
  static double _textOpacityForTransition(double? t) {
    if (t == null) return 1.0;
    if (t < 0.5) return (1.0 - 2 * t).clamp(0.0, 1.0);
    return (2 * (t - 0.5)).clamp(0.0, 1.0);
  }

  int get _tickIntervalMinutes => tickIntervalMinutesFor(_granularityIndex);

  static const List<Color> _palette = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFFFA726),
    Color(0xFFAB47BC),
  ];

  static Color _colorForItem(TodoItem item) {
    final i = item.id.hashCode.abs() % _palette.length;
    return _palette[i];
  }

  static bool _isSameDay(DateTime? a, DateTime day) {
    if (a == null) return false;
    return a.year == day.year && a.month == day.month && a.day == day.day;
  }

  static int _toMinutesOfDay(DateTime d) => d.hour * 60 + d.minute;

  static (DateTime start, DateTime end) _dayRange(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return (start, start.add(const Duration(days: 1)));
  }

  List<TimelineSegment> _segmentsForDay(DateTime day) {
    final segments = <TimelineSegment>[];
    final (dayStart, dayEnd) = _dayRange(day);

    for (final item in widget.items) {
      final color = _colorForItem(item);
      if (_isSameDay(item.reminderAt, day) || _isSameDay(item.dueDate, day)) {
        segments.add(TimelineSegment(
          item: item,
          startMinute: 0,
          endMinute: 24 * 60,
          isFullDay: true,
          color: color,
          opacity: 0.2,
        ));
      }
      final start = item.scheduledStart;
      final end = item.scheduledEnd;
      if (start != null && end != null &&
          start.isBefore(dayEnd) && end.isAfter(dayStart)) {
        final startMinute = start.isBefore(dayStart)
            ? 0
            : _toMinutesOfDay(start);
        final endMinute = end.isAfter(dayEnd)
            ? 24 * 60
            : _toMinutesOfDay(end);
        final duration = (endMinute - startMinute).clamp(1, 1440);
        final opacity = (0.25 + 0.75 * (1 - duration / 1440)).clamp(0.2, 0.95);
        segments.add(TimelineSegment(
          item: item,
          startMinute: startMinute,
          endMinute: endMinute,
          isFullDay: false,
          color: color,
          opacity: opacity,
        ));
      }
    }
    segments.sort((a, b) {
      if (a.isFullDay != b.isFullDay) return a.isFullDay ? -1 : 1;
      return a.startMinute.compareTo(b.startMinute);
    });
    return segments;
  }

  double _offsetOfNow() {
    final now = DateTime.now();
    final todayStart = DateTime(widget.today.year, widget.today.month, widget.today.day);
    if (now.isBefore(todayStart) || !now.isBefore(todayStart.add(const Duration(days: 1)))) {
      return _todayIndex * _displayDayHeight + _displayDayHeight * 0.5;
    }
    final blockStart = _todayIndex * _displayDayHeight;
    final nowMinutes = _toMinutesOfDay(now);
    return blockStart + (nowMinutes / 60) * _displayPixelsPerHour;
  }

  static double _pointerDistance(Map<int, Offset> positions) {
    if (positions.length < 2) return 0;
    final list = positions.values.toList();
    return (list[0] - list[1]).distance;
  }

  void _onPointerDown(PointerDownEvent e) {
    setState(() {
      _pointerPositions[e.pointer] = e.position;
      if (_pointerPositions.length == 2) {
        _pinchStartDistance = _pointerDistance(_pointerPositions);
        _granularityAtPinchStart = _granularityIndex;
        final list = _pointerPositions.values.toList();
        final centerGlobal = Offset(
          (list[0].dx + list[1].dx) / 2,
          (list[0].dy + list[1].dy) / 2,
        );
        final box = _scrollContentKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize && _scrollController.hasClients) {
          final local = box.globalToLocal(centerGlobal);
          _pinchAnchorViewportY = local.dy.clamp(0.0, box.size.height);
          final contentY = _scrollController.offset + _pinchAnchorViewportY!;
          final dayH = _displayDayHeight;
          _pinchAnchorDayIndex = (contentY / dayH).floor().clamp(0, _daysCount - 1);
          final yInDay = contentY - _pinchAnchorDayIndex! * dayH;
          _pinchAnchorMinuteOfDay = (yInDay / dayH * 24 * 60).round().clamp(0, 24 * 60);
        } else {
          _pinchAnchorViewportY = null;
          _pinchAnchorDayIndex = null;
          _pinchAnchorMinuteOfDay = null;
        }
      }
    });
  }

  void _syncScrollToAnchor() {
    if (_pinchAnchorViewportY == null ||
        _pinchAnchorDayIndex == null ||
        _pinchAnchorMinuteOfDay == null ||
        !_scrollController.hasClients) return;
    final anchorV = _pinchAnchorViewportY!;
    final anchorDay = _pinchAnchorDayIndex!;
    final anchorMin = _pinchAnchorMinuteOfDay!;
    final newContentY = anchorDay * _displayDayHeight +
        (anchorMin / 60.0) * _displayPixelsPerHour;
    final target = (newContentY - anchorV).clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(target);
  }

  void _onPointerMove(PointerMoveEvent e) {
    _pointerPositions[e.pointer] = e.position;
    if (_pinchStepApplied) return;
    if (_pointerPositions.length >= 2 && _pinchStartDistance != null && _pinchStartDistance! > 8) {
      final d = _pointerDistance(_pointerPositions);
      if (d > 0) {
        final ratio = d / _pinchStartDistance!;
        final step = ratio > 1.2 ? -1 : (ratio < 0.8 ? 1 : 0);
        if (step != 0) {
          final next = (_granularityAtPinchStart + step).clamp(0, kDiscreteTickMinutes.length - 1);
          if (next != _granularityIndex && _animatingToGranularityIndex == null) {
            _pinchStepApplied = true;
            _pendingGranularityIndex = next;
            if (!_scaleUpdateScheduled) {
              _scaleUpdateScheduled = true;
              SchedulerBinding.instance.scheduleFrameCallback((_) {
                if (!mounted) return;
                final p = _pendingGranularityIndex;
                _pendingGranularityIndex = null;
                _scaleUpdateScheduled = false;
                if (p != null && p != _granularityIndex) {
                  final anchorV = _pinchAnchorViewportY;
                  final anchorDay = _pinchAnchorDayIndex;
                  final anchorMin = _pinchAnchorMinuteOfDay;
                  if (anchorV != null && anchorDay != null && anchorMin != null &&
                      _scrollController.hasClients) {
                    _animatingToGranularityIndex = p;
                    _granularityAnimationController.forward(from: 0);
                  } else {
                    setState(() {
                      _granularityIndex = p;
                      _granularityAtPinchStart = p;
                    });
                  }
                }
              });
            }
          }
        }
      }
    }
  }

  void _onPointerUpOrCancel(PointerEvent e) {
    setState(() {
      _pointerPositions.remove(e.pointer);
      if (_pointerPositions.length < 2) {
        _pinchStartDistance = null;
        _pinchAnchorViewportY = null;
        _pinchAnchorDayIndex = null;
        _pinchAnchorMinuteOfDay = null;
        _pinchStepApplied = false;
      }
    });
  }

  void _animateToNow() {
    if (!mounted || !_scrollController.hasClients) return;
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = (_offsetOfNow() - viewportHeight / 2).clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _scheduleRecenter() {
    _recenterTimer?.cancel();
    _recenterTimer = Timer(kRecenterDelay, () {
      if (mounted && _scrollController.hasClients) _animateToNow();
    });
  }

  void _resetZoomAndRecenter() {
    setState(() => _granularityIndex = kDefaultGranularityIndex);
    _animatingToGranularityIndex = null;
    _granularityAnimationT = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) _animateToNow();
    });
  }

  @override
  void initState() {
    super.initState();
    _granularityAnimationController = AnimationController(
      vsync: this,
      duration: kGranularityTransitionDuration,
    );
    _granularityAnimation = CurvedAnimation(
      parent: _granularityAnimationController,
      curve: Curves.easeInOut,
    );
    _granularityAnimation.addListener(() {
      if (!mounted) return;
      setState(() => _granularityAnimationT = _granularityAnimation.value);
      _syncScrollToAnchor();
    });
    _granularityAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() {
          _granularityIndex = _animatingToGranularityIndex!;
          _granularityAtPinchStart = _granularityIndex;
          _animatingToGranularityIndex = null;
          _granularityAnimationT = 0;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncScrollToAnchor();
        });
      }
    });
    _scrollController.addListener(_scheduleRecenter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureInitialScroll();
    });
  }

  @override
  void dispose() {
    _recenterTimer?.cancel();
    _granularityAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _initialScrollDone = false;

  void _ensureInitialScroll() {
    if (!mounted || _initialScrollDone || !_scrollController.hasClients) return;
    _initialScrollDone = true;
    final viewportHeight = _scrollController.position.viewportDimension;
    final target = (_offsetOfNow() - viewportHeight / 2).clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('M月d日');
    final timeFmt = DateFormat('HH:mm');
    final now = DateTime.now();
    final tickCount = 24 * 60 ~/ tickIntervalMinutesFor(_granularityIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.maxHeight.isFinite;
        final timelineHeight = hasBoundedHeight
            ? null
            : (MediaQuery.sizeOf(context).height * 0.6).clamp(320.0, 700.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Text(
                    '时间轴',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '粒度 ${granularityLabel(tickIntervalMinutesFor(_granularityIndex))}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (widget.onRefresh != null)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: widget.onRefresh,
                      tooltip: '刷新',
                    ),
                  IconButton(
                    icon: const Icon(Icons.restore, size: 20),
                    onPressed: _resetZoomAndRecenter,
                    tooltip: '还原：缩放与位置',
                  ),
                ],
              ),
            ),
            if (hasBoundedHeight)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, innerConstraints) => _buildTimelineContent(
                    context,
                    theme,
                    dateFmt,
                    timeFmt,
                    now,
                    tickCount,
                  ),
                ),
              )
            else
              SizedBox(
                height: timelineHeight,
                child: _buildTimelineContent(
                  context,
                  theme,
                  dateFmt,
                  timeFmt,
                  now,
                  tickCount,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTimelineContent(
    BuildContext context,
    ThemeData theme,
    DateFormat dateFmt,
    DateFormat timeFmt,
    DateTime now,
    int tickCount,
  ) {
    final isPinching = _pointerPositions.length >= 2;
    final animationT = _animatingToGranularityIndex != null ? _granularityAnimationT : null;
    return Listener(
      key: _scrollContentKey,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUpOrCancel,
      onPointerCancel: _onPointerUpOrCancel,
      child: Stack(
        children: [
          AbsorbPointer(
            absorbing: isPinching,
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              itemCount: _daysCount,
              itemExtent: _displayDayHeight,
              itemBuilder: (context, dayIndex) => RepaintBoundary(
                child: _buildDayRow(
                  context,
                  dayIndex,
                  theme,
                  dateFmt,
                  now,
                  tickCount,
                  animationT: animationT,
                ),
              ),
            ),
          ),
          if (_isSameDay(now, widget.today))
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(
                child: Opacity(
                  opacity: _textOpacityForTransition(animationT),
                  child: Material(
                    color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: _animateToNow,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(
                          '当前 ${timeFmt.format(now)}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
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

  /// 时间标签列：标签中心对准右侧刻度线（负 Y 偏移使中心对齐而非顶部对齐）
  Widget _buildTimeLabels(
    int tickCount,
    double tickHeight,
    ThemeData theme, {
    double? animationT,
  }) {
    const maxLabels = 24;
    final step = tickCount > maxLabels ? (tickCount / maxLabels).ceil() : 1;
    final count = (tickCount / step).ceil();
    final labelHeight = tickHeight * step;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final textOpacity = _textOpacityForTransition(animationT);
    return SizedBox(
      height: _displayDayHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(count, (j) {
          final i = j * step;
          final min = i * _tickIntervalMinutes;
          final h = min ~/ 60, m = min % 60;
          // 刻度线在 j*step 处；标签中心对准该刻度，故 top = 刻度 y - 半高
          final tickY = j * step * tickHeight;
          final top = tickY - labelHeight / 2;
          return Positioned(
            left: 0,
            right: 0,
            top: top,
            height: labelHeight,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Opacity(
                  opacity: textOpacity,
                  child: Text(
                    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
                    style: textStyle,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayRow(
    BuildContext context,
    int dayIndex,
    ThemeData theme,
    DateFormat dateFmt,
    DateTime now,
    int tickCount, {
    double? animationT,
  }) {
    final day = widget.today.add(Duration(days: dayIndex - _todayIndex));
    final isToday = _isSameDay(now, day);
    final dayLabel = dayIndex == _todayIndex ? '今天' : dateFmt.format(day);
    final segments = _segmentsForDay(day);
    final tickHeight = _displayPixelsPerHour * (tickIntervalMinutesFor(_granularityIndex) / 60);
    final textOpacity = _textOpacityForTransition(animationT);
    return SizedBox(
      height: _displayDayHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: _buildTimeLabels(tickCount, tickHeight, theme, animationT: animationT),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: TimelineGridPainter(
                      tickHeight: tickHeight,
                      tickCount: tickCount,
                      lineColor: theme.colorScheme.outline.withOpacity(0.12),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 4,
                  child: Opacity(
                    opacity: textOpacity,
                    child: Text(
                      dayLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isToday ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                ...segments.map((s) {
                  final top = s.startMinute / 60 * _displayPixelsPerHour;
                  final height = (s.endMinute - s.startMinute) / 60 * _displayPixelsPerHour;
                  return Positioned(
                    left: 4,
                    right: 4,
                    top: top,
                    height: height.clamp(4.0, double.infinity),
                    child: Material(
                      color: s.color.withOpacity(s.opacity),
                      borderRadius: BorderRadius.circular(8),
                      elevation: 0,
                      child: InkWell(
                        onTap: () => widget.onItemTap?.call(s.item),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Opacity(
                              opacity: textOpacity,
                              child: Text(
                                s.item.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(offset: Offset(0, 0.5), blurRadius: 1, color: Colors.black26),
                                    Shadow(offset: Offset(0, 0.5), blurRadius: 2, color: Colors.black12),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (isToday) ...[_buildNowLine(theme), _buildNowDot(theme)],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNowLine(ThemeData theme) {
    final now = DateTime.now();
    final nowMinutes = _toMinutesOfDay(now);
    final lineCenterY = nowMinutes / 60 * _displayPixelsPerHour;
    return Positioned(
      left: 0,
      right: 0,
      top: lineCenterY - 1,
      height: 2,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.error,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.error.withOpacity(0.4),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNowDot(ThemeData theme) {
    final now = DateTime.now();
    final nowMinutes = _toMinutesOfDay(now);
    final dotCenterY = nowMinutes / 60 * _displayPixelsPerHour;
    const dotSize = 10.0;
    return Positioned(
      left: 0,
      top: dotCenterY - dotSize / 2,
      child: Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.surface,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.error.withOpacity(0.5),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}
