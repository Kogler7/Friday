/// 活动标签对象，name 即 id（同名标签无区别），含描述与 hidden 状态
class ActivityTag {
  final String name;
  final String? desc;
  final bool hidden;

  const ActivityTag({required this.name, this.desc, this.hidden = false});

  String get id => name;

  ActivityTag copyWith({String? name, String? desc, bool? hidden}) {
    return ActivityTag(
      name: name ?? this.name,
      desc: desc ?? this.desc,
      hidden: hidden ?? this.hidden,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (desc != null && desc!.isNotEmpty) 'desc': desc,
        'hidden': hidden,
      };

  factory ActivityTag.fromJson(Map<String, dynamic> json) {
    return ActivityTag(
      name: json['name'] as String? ?? json['id'] as String? ?? '',
      desc: json['desc'] as String?,
      hidden: json['hidden'] as bool? ?? false,
    );
  }
}
