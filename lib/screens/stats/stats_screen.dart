import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/activity/hourly_record.dart';
import '../../services/status_data_source.dart';
import '../../services/storage_service.dart';
import '../../widgets/dimension_chart.dart';

/// 统计页：维度统计图
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _rangeStart = DateTime.now().subtract(const Duration(days: 7));
  DateTime _rangeEnd = DateTime.now();
  String _dimension = '活动标签';
  ChartType _chartType = ChartType.bar;

  static const List<String> _dimensions = [
    '活动标签', '精力使用', '体力使用', '活动动机', '产出定性',
    '情绪状态', '精力状态', '生理状态', '注意力状态',
  ];

  @override
  void initState() {
    super.initState();
    StatusDataSource.useTestData.addListener(_onDataSourceChanged);
  }

  @override
  void dispose() {
    StatusDataSource.useTestData.removeListener(_onDataSourceChanged);
    super.dispose();
  }

  void _onDataSourceChanged() => setState(() {});

  List<HourlyRecord> _getRecordsForChart() {
    return StorageService.getRecordsInRange(_rangeStart, _rangeEnd);
  }

  String _fmt(DateTime d) => '${d.year}/${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final records = _getRecordsForChart();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (kDebugMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    StatusDataSource.isTestData ? '测试数据' : '用户数据',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('维度统计', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('时间: ', style: TextStyle(fontSize: 12)),
                          TextButton(
                            onPressed: () async {
                              final range = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                initialDateRange: DateTimeRange(
                                  start: _rangeStart,
                                  end: _rangeEnd,
                                ),
                              );
                              if (range != null) {
                                setState(() {
                                  _rangeStart = range.start;
                                  _rangeEnd = range.end;
                                });
                              }
                            },
                            child: Text('${_fmt(_rangeStart)} ~ ${_fmt(_rangeEnd)}'),
                          ),
                        ],
                      ),
                      DropdownButton<String>(
                        value: _dimension,
                        items: _dimensions
                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (v) => setState(() => _dimension = v ?? _dimension),
                      ),
                      SegmentedButton<ChartType>(
                        segments: const [
                          ButtonSegment(value: ChartType.bar, label: Text('条形')),
                          ButtonSegment(value: ChartType.line, label: Text('折线')),
                          ButtonSegment(value: ChartType.pie, label: Text('饼图')),
                        ],
                        selected: {_chartType},
                        onSelectionChanged: (s) => setState(() => _chartType = s.first),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: records.isEmpty
                            ? Center(
                                child: Text(
                                  '暂无记录',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : DimensionChart(
                                records: records,
                                dimension: _dimension,
                                chartType: _chartType,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
