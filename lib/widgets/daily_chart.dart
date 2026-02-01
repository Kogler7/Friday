import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/activity/hourly_record.dart';
import '../services/settings_service.dart';

/// 当日汇总：饼图（按活动标签占比）+ 柱状图（24 小时分布）
class DailyChart extends StatelessWidget {
  final List<HourlyRecord> records;
  final DateTime date;

  const DailyChart({
    super.key,
    required this.records,
    required this.date,
  });

  static const List<Color> _tagColors = [
    Color(0xFF2196F3), // 蓝
    Color(0xFFFF9800), // 橙
    Color(0xFF4CAF50), // 绿
    Color(0xFF9C27B0), // 紫
    Color(0xFF00BCD4), // 青
    Color(0xFF795548), // 棕
    Color(0xFF607D8B), // 灰
  ];

  Map<String, int> _aggregateByTag() {
    final map = <String, int>{};
    for (final r in records) {
      final tag = r.primaryTag;
      map[tag] = (map[tag] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final agg = _aggregateByTag();
    final entries = agg.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = records.length;
    final unitMin = SettingsService.isInitialized
        ? SettingsService.current.statUnitMinutes
        : 20;
    final unitLabel = unitMin == 60 ? '小时' : '单位';

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < entries.length && i < 7; i++) {
      final e = entries[i];
      sections.add(PieChartSectionData(
        value: e.value.toDouble(),
        title: '${e.value}${unitMin == 60 ? 'h' : '单'}',
        color: _tagColors[i % _tagColors.length],
        radius: 48,
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '当日汇总',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (total == 0)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                '今日暂无记录，整点会提示填写上一时段状态',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          )
        else ...[
          SizedBox(
            height: 160,
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: sections.isEmpty
                      ? const Center(child: Text('无数据'))
                      : PieChart(
                          PieChartData(
                            sections: sections,
                            sectionsSpace: 2,
                            centerSpaceRadius: 24,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < entries.length && i < 5; i++)
                        _LegendItem(
                          color: _tagColors[i % _tagColors.length],
                          label: '${entries[i].key} ${entries[i].value} $unitLabel'
                              '${unitMin == 60 ? '' : '（每单位$unitMin分钟）'}',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '24 小时分布',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (entries.isEmpty ? 1 : entries.length).toDouble() + 0.5,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 1 || idx > entries.length) return const Text('');
                        return Text(
                          entries[idx - 1].key,
                          style: const TextStyle(fontSize: 9),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: 3,
                      getTitlesWidget: (value, meta) {
                        final h = value.toInt();
                        if (h < 0 || h > 23) return const Text('');
                        return Text('$h', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(24, (i) {
                  final list = records.where((rec) => rec.hourOfDay == i).toList();
                  list.sort((a, b) => a.hourStart.compareTo(b.hourStart));
                  final r = list.isEmpty ? null : list.last;
                  Color color = Colors.grey.withValues(alpha: 0.2);
                  double value = 0;
                  if (r != null) {
                    final tag = r.primaryTag;
                    final idx = entries.indexWhere((e) => e.key == tag);
                    value = idx >= 0 ? idx + 1.0 : 0.5;
                    color = idx >= 0 ? _tagColors[idx % _tagColors.length] : Colors.grey;
                  }
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        color: color,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    ],
                    showingTooltipIndicators: [],
                  );
                }),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
