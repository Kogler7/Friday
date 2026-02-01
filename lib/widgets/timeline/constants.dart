/// 离散时间粒度（分钟）：10/20/30/60/90/120/180/240，以及特殊档位 周天/月天
const List<int> kDiscreteTickMinutes = [10, 20, 30, 60, 90, 120, 180, 240];

/// 周天粒度索引：每刻度=一天，仅全天事件，横向罗列
const int kWeekDayGranularityIndex = 8;

/// 月天粒度索引：每刻度=一天，仅全天事件，按月份日历渲染
const int kMonthDayGranularityIndex = 9;

/// 总粒度档位数
const int kGranularityCount = 10;

/// 默认粒度档位（1h）
const int kDefaultGranularityIndex = 3;

/// 时间轴每刻度像素高度
const double kPixelsPerTick = 40.0;

/// 周天模式：每天一行的高度
const double kWeekDayRowHeight = 72.0;

/// 月天模式：每个日期格子的最小高度
const double kMonthDayCellMinHeight = 80.0;

/// 停止滑动后多久自动归位到当前时刻
const Duration kRecenterDelay = Duration(milliseconds: 2500);

/// 今天前后各展示多少天
const int kDaysBeforeToday = 365;
const int kDaysAfterToday = 365;

/// 粒度切换时间距过渡动画时长
const Duration kGranularityTransitionDuration = Duration(milliseconds: 280);

/// 是否为周天模式
bool isWeekDayMode(int index) => index == kWeekDayGranularityIndex;

/// 是否为月天模式
bool isMonthDayMode(int index) => index == kMonthDayGranularityIndex;

/// 是否为特殊粒度（周天/月天，非小时刻度）
bool isSpecialGranularityMode(int index) =>
    index == kWeekDayGranularityIndex || index == kMonthDayGranularityIndex;

/// 根据粒度档位返回刻度间隔（分钟）
int tickIntervalMinutesFor(int index) {
  if (index == kWeekDayGranularityIndex || index == kMonthDayGranularityIndex) {
    return 24 * 60; // 一天
  }
  return kDiscreteTickMinutes[index.clamp(0, kDiscreteTickMinutes.length - 1)];
}

/// 根据粒度档位返回每小时像素数
double pixelsPerHourFor(int index) {
  if (index == kWeekDayGranularityIndex) {
    return kWeekDayRowHeight / 24;
  }
  if (index == kMonthDayGranularityIndex) {
    return kMonthDayCellMinHeight / 24; // 仅用于兼容
  }
  final tick = tickIntervalMinutesFor(index);
  return (60 / tick) * kPixelsPerTick;
}

/// 根据粒度档位返回单日时间轴高度
double dayHeightFor(int index) {
  if (index == kWeekDayGranularityIndex) return kWeekDayRowHeight;
  if (index == kMonthDayGranularityIndex) return kMonthDayCellMinHeight;
  return 24 * pixelsPerHourFor(index);
}

/// 粒度显示文案（传入粒度索引）
String granularityLabelForIndex(int index) {
  if (index == kWeekDayGranularityIndex) return '周天';
  if (index == kMonthDayGranularityIndex) return '月天';
  final minutes = tickIntervalMinutesFor(index);
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

