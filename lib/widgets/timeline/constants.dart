/// 离散时间粒度（分钟）：10/20/30/60/90/120/180/240
const List<int> kDiscreteTickMinutes = [10, 20, 30, 60, 90, 120, 180, 240];

/// 默认粒度档位（1h）
const int kDefaultGranularityIndex = 3;

/// 时间轴每刻度像素高度
const double kPixelsPerTick = 40.0;

/// 停止滑动后多久自动归位到当前时刻
const Duration kRecenterDelay = Duration(milliseconds: 2500);

/// 今天前后各展示多少天
const int kDaysBeforeToday = 365;
const int kDaysAfterToday = 365;

/// 粒度切换时间距过渡动画时长
const Duration kGranularityTransitionDuration = Duration(milliseconds: 280);

/// 根据粒度档位返回刻度间隔（分钟）
int tickIntervalMinutesFor(int index) =>
    kDiscreteTickMinutes[index.clamp(0, kDiscreteTickMinutes.length - 1)];

/// 根据粒度档位返回每小时像素数
double pixelsPerHourFor(int index) {
  final tick = tickIntervalMinutesFor(index);
  return (60 / tick) * kPixelsPerTick;
}

/// 根据粒度档位返回单日时间轴高度
double dayHeightFor(int index) => 24 * pixelsPerHourFor(index);

/// 粒度显示文案
String granularityLabel(int minutes) {
  if (minutes >= 60) {
    if (minutes == 60) return '1h';
    if (minutes == 90) return '1.5h';
    if (minutes == 120) return '2h';
    if (minutes == 180) return '3h';
    if (minutes == 240) return '4h';
    return '${minutes ~/ 60}h';
  }
  return '${minutes}min';
}
