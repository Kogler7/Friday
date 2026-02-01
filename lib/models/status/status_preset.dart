import 'package:flutter/material.dart';

import 'status_record_data.dart';

/// 状态记录预设，可设置图标和颜色，快速填充表单，可置顶
class StatusPreset {
  final String id;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final StatusRecordData data;
  final bool pinned;

  const StatusPreset({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    required this.data,
    this.pinned = false,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  Color get color => Color(colorValue);

  StatusPreset copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    int? colorValue,
    StatusRecordData? data,
    bool? pinned,
  }) =>
      StatusPreset(
        id: id ?? this.id,
        name: name ?? this.name,
        iconCodePoint: iconCodePoint ?? this.iconCodePoint,
        colorValue: colorValue ?? this.colorValue,
        data: data ?? this.data,
        pinned: pinned ?? this.pinned,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
        'data': data.toJson(),
        if (pinned) 'pinned': pinned,
      };

  factory StatusPreset.fromJson(Map<String, dynamic> json) {
    return StatusPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      iconCodePoint: (json['iconCodePoint'] as num?)?.toInt() ?? Icons.bookmark.codePoint,
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF2196F3,
      data: StatusRecordData.fromJson(
        (json['data'] as Map<String, dynamic>?) ?? {},
      ),
      pinned: json['pinned'] as bool? ?? false,
    );
  }
}
