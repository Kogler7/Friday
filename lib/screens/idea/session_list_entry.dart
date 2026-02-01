import '../../models/idea/idea_session.dart';

/// 会话列表条目：分栏标题或会话项
class SessionListEntry {
  final bool isSection;
  final String? sectionLabel;
  final IdeaSession? session;

  SessionListEntry._({required this.isSection, this.sectionLabel, this.session});

  factory SessionListEntry.section(String label) =>
      SessionListEntry._(isSection: true, sectionLabel: label);
  factory SessionListEntry.session(IdeaSession s) =>
      SessionListEntry._(isSection: false, session: s);
}
