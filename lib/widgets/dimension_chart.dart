import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/activity/hourly_record.dart';
import '../models/status/status_enums.dart';

enum ChartType { bar, line, pie }

/// 按维度统计的图表
class DimensionChart extends StatelessWidget {
  final List<HourlyRecord> records;
  final String dimension;
  final ChartType chartType;

  const DimensionChart({
    super.key,
    required this.records,
    required this.dimension,
    required this.chartType,
  });

  Map<String, int> _aggregate() {
    final map = <String, int>{};
    for (final r in records) {
      final key = _valueForDimension(r);
      if (key.isEmpty) continue;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  String _valueForDimension(HourlyRecord r) {
    switch (dimension) {
      case '活动标签':
        return r.data.tagIds.isNotEmpty ? r.data.tagIds.first : '';
      case '精力使用':
        return r.data.energyUsage?.displayName ?? '';
      case '体力使用':
        return r.data.physicalUsage?.displayName ?? '';
      case '活动动机':
        return r.data.activityMotivation?.displayName ?? '';
      case '产出定性':
        return r.data.outputQuality?.displayName ?? '';
      case '情绪状态':
        return r.data.emotionalState?.displayName ?? '';
      case '精力状态':
        return r.data.energyState?.displayName ?? '';
      case '生理状态':
        return r.data.physicalState?.displayName ?? '';
      case '注意力状态':
        return r.data.attentionState?.displayName ?? '';
      default:
        return r.primaryTag;
    }
  }

  static const _colors = [
    Color(0xFF2196F3), Color(0xFFFF9800), Color(0xFF4CAF50),
    Color(0xFF9C27B0), Color(0xFF00BCD4), Color(0xFF795548),
    Color(0xFF607D8B), Color(0xFFE91E63),
  ];

  @override
  Widget build(BuildContext context) {
    final agg = _aggregate();
    final entries = agg.entries.where((e) => e.key.isNotEmpty).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('暂无数据')),
      );
    }

    switch (chartType) {
      case ChartType.pie:
        return _buildPie(entries);
      case ChartType.bar:
        return _buildBar(entries);
      case ChartType.line:
        return _buildLine(entries);
    }
  }

  Widget _buildPie(List<MapEntry<String, int>> entries) {
    final sections = entries.take(7).toList().asMap().entries.map((e) {
      final i = e.key;
      final entry = e.value;
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${entry.value}',
        color: _colors[i % _colors.length],
        radius: 48,
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
      );
    }).toList();
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 24,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.take(5).toList().asMap().entries.map((e) {
                final i = e.key;
                final entry = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _colors[i % _colors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${entry.key} ${entry.value}',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(List<MapEntry<String, int>> entries) {
    final maxY = entries.isEmpty ? 1.0 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() + 2;
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= entries.length) return const Text('');
                  final label = entries[idx].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      label.length > 3 ? '${label.substring(0, 2)}…' : label,
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: entries.asMap().entries.map((e) {
            final i = e.key;
            final entry = e.value;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entry.value.toDouble(),
                  color: _colors[i % _colors.length],
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
              showingTooltipIndicators: [],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLine(List<MapEntry<String, int>> entries) {
    final maxY = entries.isEmpty ? 1.0 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() + 2;
    final spots = entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value.toDouble())).toList();
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (entries.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          lineTouchData: LineTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt().clamp(0, entries.length - 1);
                  if (idx >= entries.length) return const Text('');
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      entries[idx].key,
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: _colors[0],
              barWidth: 2,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
