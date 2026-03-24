import '../data/repositories/repository_facade.dart';
import '../models/status/status_preset.dart';
import '../models/status/status_record_data.dart';
import 'status_preset_storage.dart';

/// 推荐结果
class RecommendationResult {
  final StatusPreset preset;
  final double probability;
  final int sampleCount;

  const RecommendationResult({
    required this.preset,
    required this.probability,
    required this.sampleCount,
  });
}

/// 历史数据不足时使用的默认时段（2:00-10:00 睡觉）
const int _defaultSleepStartHour = 2;
const int _defaultSleepEndHour = 10;

/// 根据历史推荐预设
class StatusRecommendationService {
  StatusRecommendationService._();

  static const int minSampleDays = 3;
  static const int historyDays = 7;

  /// 判断 slot 是否在默认睡觉时段（2:00-10:00）
  static bool isInDefaultSleepPeriod(DateTime slot) {
    final h = slot.hour;
    final m = slot.minute;
    final minSinceMidnight = h * 60 + m;
    final startMin = _defaultSleepStartHour * 60;
    final endMin = _defaultSleepEndHour * 60;
    return minSinceMidnight >= startMin && minSinceMidnight < endMin;
  }

  /// 获取推荐：历史 >= 3 天则按同时刻统计，否则用默认
  static RecommendationResult getRecommendation(DateTime slotStart) {
    final records = RepositoryFacade.status.getRecordsForSlotAcrossDays(
      slotStart,
      historyDays,
    );

    if (records.length >= minSampleDays) {
      final tagCounts = <String, int>{};
      for (final r in records) {
        final tag = r.primaryTag;
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
      final sorted = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sorted.isNotEmpty) {
        final topTag = sorted.first.key;
        final count = sorted.first.value;
        final preset = _presetForTag(topTag);
        if (preset != null) {
          return RecommendationResult(
            preset: preset,
            probability: count / records.length,
            sampleCount: records.length,
          );
        }
      }
    }

    return _defaultRecommendation(slotStart);
  }

  static RecommendationResult _defaultRecommendation(DateTime slotStart) {
    final presets = StatusPresetStorage.getAll();
    if (presets.isEmpty) {
      return RecommendationResult(
        preset: StatusPreset(
          id: '_fallback',
          name: '休息',
          iconCodePoint: 0xe3e8,
          colorValue: 0xFFFF9800,
          data: const StatusRecordData(tagIds: ['休息']),
        ),
        probability: 0,
        sampleCount: 0,
      );
    }
    StatusPreset preset;
    if (isInDefaultSleepPeriod(slotStart)) {
      try {
        preset = presets.firstWhere((p) => p.id == 'builtin_sleeping');
      } catch (_) {
        try {
          preset = presets.firstWhere((p) => p.data.tagIds.contains('睡眠'));
        } catch (_) {
          preset = presets.first;
        }
      }
    } else {
      try {
        preset = presets.firstWhere((p) => p.id == 'builtin_resting');
      } catch (_) {
        preset = presets.first;
      }
    }
    return RecommendationResult(preset: preset, probability: 0, sampleCount: 0);
  }

  static StatusPreset? _presetForTag(String tag) {
    for (final p in StatusPresetStorage.getAll()) {
      if (p.data.tagIds.contains(tag)) return p;
    }
    return null;
  }
}
