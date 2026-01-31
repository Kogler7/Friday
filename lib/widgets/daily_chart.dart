import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/activity_state.dart';
import '../models/hourly_record.dart';
import '../services/settings_service.dart';

/// 当日汇总：饼图（工作/休息/娱乐占比，按统计单位计数）+ 柱状图（24 小时分布）
class DailyChart extends StatelessWidget {
  final List<HourlyRecord> records;
  final DateTime date;

  const DailyChart({
    super.key,
    required this.records,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final work = records.where((r) => r.state == ActivityState.working).length;
    final rest = records.where((r) => r.state == ActivityState.resting).length;
    final entertainment =
        records.where((r) => r.state == ActivityState.entertainment).length;
    final total = records.length;
    final unitMin = SettingsService.isInitialized
        ? SettingsService.current.statUnitMinutes
        : 20;
    final unitLabel = unitMin == 60 ? '小时' : '单位';
    final sections = <PieChartSectionData>[];
    if (work > 0) {
      sections.add(PieChartSectionData(
        value: work.toDouble(),
        title: '$work${unitMin == 60 ? 'h' : '单'}',
        color: Colors.blue,
        radius: 48,
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
      ));
    }
    if (rest > 0) {
      sections.add(PieChartSectionData(
        value: rest.toDouble(),
        title: '$rest${unitMin == 60 ? 'h' : '单'}',
        color: Colors.orange,
        radius: 48,
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
      ));
    }
    if (entertainment > 0) {
      sections.add(PieChartSectionData(
        value: entertainment.toDouble(),
        title: '$entertainment${unitMin == 60 ? 'h' : '单'}',
        color: Colors.green,
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
                      :                       PieChart(
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
                      _LegendItem(
                        color: Colors.blue,
                        label: '工作 $work $unitLabel${unitMin == 60 ? '' : '（每单位$unitMin分钟）'}',
                      ),
                      _LegendItem(
                        color: Colors.orange,
                        label: '休息 $rest $unitLabel${unitMin == 60 ? '' : '（每单位$unitMin分钟）'}',
                      ),
                      _LegendItem(
                        color: Colors.green,
                        label: '娱乐 $entertainment $unitLabel${unitMin == 60 ? '' : '（每单位$unitMin分钟）'}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '24 小时分布（蓝=工作 橙=休息 绿=娱乐）',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 3.5,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final v = value.toInt();
                        if (v == 0) return const Text('');
                        if (v == 1) return const Text('娱乐', style: TextStyle(fontSize: 10));
                        if (v == 2) return const Text('休息', style: TextStyle(fontSize: 10));
                        if (v == 3) return const Text('工作', style: TextStyle(fontSize: 10));
                        return const Text('');
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
                    switch (r.state) {
                      case ActivityState.working:
                        color = Colors.blue;
                        value = 3;
                        break;
                      case ActivityState.resting:
                        color = Colors.orange;
                        value = 2;
                        break;
                      case ActivityState.entertainment:
                        color = Colors.green;
                        value = 1;
                        break;
                    }
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
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
