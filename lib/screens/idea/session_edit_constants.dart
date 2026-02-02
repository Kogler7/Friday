import 'package:flutter/material.dart';

/// 会话编辑常用图标库（Material Icons，统一使用 outlined 变体）
const List<IconData> sessionIconOptions = [
  Icons.chat_bubble_outline,
  Icons.lightbulb_outline,
  Icons.note_outlined,
  Icons.edit_note_outlined,
  Icons.folder_outlined,
  Icons.star_outline,
  Icons.bookmark_outline,
  Icons.label_outline,
  Icons.work_outline,
  Icons.school_outlined,
  Icons.psychology_outlined,
  Icons.auto_awesome_outlined,
  Icons.tips_and_updates_outlined,
  Icons.menu_book_outlined,
  Icons.article_outlined,
  Icons.dashboard_outlined,
  Icons.inventory_2_outlined,
  Icons.push_pin_outlined,
];

/// 每个 outlined 图标的 codePoint -> filled 变体 codePoint 的映射
/// 用于在会话历史中用 filled 表示当前会话、outlined 表示非当前
final Map<int, int> _sessionIconOutlinedToFilled = {
  Icons.chat_bubble_outline.codePoint: Icons.chat_bubble.codePoint,
  Icons.lightbulb_outline.codePoint: Icons.lightbulb.codePoint,
  Icons.note_outlined.codePoint: Icons.note.codePoint,
  Icons.edit_note_outlined.codePoint: Icons.edit_note.codePoint,
  Icons.folder_outlined.codePoint: Icons.folder.codePoint,
  Icons.star_outline.codePoint: Icons.star.codePoint,
  Icons.bookmark_outline.codePoint: Icons.bookmark.codePoint,
  Icons.label_outline.codePoint: Icons.label.codePoint,
  Icons.work_outline.codePoint: Icons.work.codePoint,
  Icons.school_outlined.codePoint: Icons.school.codePoint,
  Icons.psychology_outlined.codePoint: Icons.psychology.codePoint,
  Icons.auto_awesome_outlined.codePoint: Icons.auto_awesome.codePoint,
  Icons.tips_and_updates_outlined.codePoint: Icons.tips_and_updates.codePoint,
  Icons.menu_book_outlined.codePoint: Icons.menu_book.codePoint,
  Icons.article_outlined.codePoint: Icons.article.codePoint,
  Icons.dashboard_outlined.codePoint: Icons.dashboard.codePoint,
  Icons.inventory_2_outlined.codePoint: Icons.inventory_2.codePoint,
  Icons.push_pin_outlined.codePoint: Icons.push_pin.codePoint,
};

/// 旧数据可能存储了 filled 变体（如 edit_note、auto_awesome），需反向映射
final Map<int, int> _sessionIconFilledToOutlined = {
  Icons.edit_note.codePoint: Icons.edit_note_outlined.codePoint,
  Icons.auto_awesome.codePoint: Icons.auto_awesome_outlined.codePoint,
};

/// codePoint -> 常量 IconData 查找表，用于 tree-shake 兼容（仅返回常量图标，不构造 IconData）
final Map<int, IconData> _sessionOutlinedCodeToIcon = {
  for (final e in sessionIconOptions) e.codePoint: e,
};
const _sessionFilledIcons = [
  Icons.chat_bubble, Icons.lightbulb, Icons.note, Icons.edit_note, Icons.folder,
  Icons.star, Icons.bookmark, Icons.label, Icons.work, Icons.school,
  Icons.psychology, Icons.auto_awesome, Icons.tips_and_updates, Icons.menu_book,
  Icons.article, Icons.dashboard, Icons.inventory_2, Icons.push_pin,
];
final Map<int, IconData> _sessionFilledCodeToIcon = {
  for (final e in _sessionFilledIcons) e.codePoint: e,
};

/// 根据存储的 iconCodePoint 获取显示图标，filled 表示当前会话
IconData sessionIconForDisplay(int? iconCodePoint, {required bool isCurrent}) {
  final codePoint = iconCodePoint ?? Icons.chat_bubble_outline.codePoint;
  int outlinedCodePoint;
  int filledCodePoint;
  if (_sessionIconOutlinedToFilled.containsKey(codePoint)) {
    outlinedCodePoint = codePoint;
    filledCodePoint = _sessionIconOutlinedToFilled[codePoint]!;
  } else if (_sessionIconFilledToOutlined.containsKey(codePoint)) {
    outlinedCodePoint = _sessionIconFilledToOutlined[codePoint]!;
    filledCodePoint = codePoint;
  } else {
    outlinedCodePoint = filledCodePoint = codePoint;
  }
  return isCurrent
      ? (_sessionFilledCodeToIcon[filledCodePoint] ?? Icons.chat_bubble)
      : (_sessionOutlinedCodeToIcon[outlinedCodePoint] ?? Icons.chat_bubble_outline);
}

/// 会话编辑常用颜色库（现代柔和配色）
const List<Color> sessionColorOptions = [
  Color(0xFF5C6BC0), // 靛蓝
  Color(0xFF42A5F5), // 蓝
  Color(0xFF26A69A), // 青绿
  Color(0xFF66BB6A), // 绿
  Color(0xFF9CCC65), // 浅绿
  Color(0xFFFFA726), // 橙
  Color(0xFFEF5350), // 红
  Color(0xFFEC407A), // 粉
  Color(0xFFAB47BC), // 紫
  Color(0xFF7E57C2), // 深紫
  Color(0xFF78909C), // 蓝灰
  Color(0xFF8D6E63), // 棕
];
