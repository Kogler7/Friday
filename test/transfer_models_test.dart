import 'package:flutter_test/flutter_test.dart';
import 'package:friday/models/activity/hourly_record.dart';
import 'package:friday/models/event/todo_item.dart';
import 'package:friday/models/idea/chat_message.dart';
import 'package:friday/models/idea/idea_session.dart';
import 'package:friday/models/status/status_record_data.dart';
import 'package:friday/models/transfer/transfer_pairing_payload.dart';
import 'package:friday/models/transfer/transfer_snapshot.dart';

void main() {
  test('TransferPairingPayload should roundtrip compact json', () {
    final payload = TransferPairingPayload(
      channelId: 'ch_123',
      token: 'token_abc',
      expiresAt: DateTime.parse('2026-01-01T10:00:00Z'),
    );

    final raw = payload.toCompactJson();
    final parsed = TransferPairingPayload.fromCompactJson(raw);

    expect(parsed.channelId, payload.channelId);
    expect(parsed.token, payload.token);
    expect(parsed.expiresAt.toUtc(), payload.expiresAt.toUtc());
  });

  test('TransferSnapshot should roundtrip json', () {
    final now = DateTime.parse('2026-01-01T10:00:00Z');
    final session = IdeaSession(
      id: 's1',
      title: '会话',
      createdAt: now,
      updatedAt: now,
      messages: [ChatMessage(id: 'm1', createdAt: now, content: 'hello')],
    );
    final snapshot = TransferSnapshot(
      ideaSessions: {'s1': session},
      currentIdeaSessionId: 's1',
      todos: [
        TodoItem(id: 't1', title: 'todo', completed: false, createdAt: now),
      ],
      statusByDate: {
        '2026-01-01': [
          HourlyRecord(hourStart: now, data: const StatusRecordData()),
        ],
      },
    );

    final json = snapshot.toJson();
    final parsed = TransferSnapshot.fromJson(json);

    expect(parsed.currentIdeaSessionId, 's1');
    expect(parsed.ideaSessions['s1']?.messages.length, 1);
    expect(parsed.todos.length, 1);
    expect(parsed.statusByDate['2026-01-01']?.length, 1);
  });
}
