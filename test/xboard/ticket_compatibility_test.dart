import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/src/panels/xboard/models/xboard_ticket_models.dart';

void main() {
  final message = {
    'id': 1,
    'ticket_id': 477,
    'is_me': false,
    'message': 'fixture reply',
    'created_at': 1,
    'updated_at': 1
  };
  final header = {
    'id': 477,
    'user_id': 1,
    'level': 1,
    'status': 1,
    'reply_status': 0,
    'subject': 'fixture ticket',
    'created_at': 1,
    'updated_at': 1
  };

  test('message authors override inverted is_me and normalize numeric IDs', () {
    final detail = TicketDetail.fromJson({
      ...header,
      'message': [
        {...message, 'id': 1, 'user_id': '99', 'is_me': true},
        {...message, 'id': 2, 'user_id': '1', 'is_me': false},
      ]
    });
    expect(detail.messages[0].isMe, isFalse);
    expect(detail.messages[1].isMe, isTrue);
  });
  test('XBoard/V2Board singular message field retains historical replies', () {
    final detail = TicketDetail.fromJson({
      ...header,
      'message': [message]
    });
    expect(detail.messages.single.message, 'fixture reply');
    expect(detail.status, 1);
  });
  test('plural messages remains compatible and empty ticket stays empty', () {
    expect(
        TicketDetail.fromJson({
          ...header,
          'messages': [message]
        }).messages.length,
        1);
    expect(TicketDetail.fromJson({...header, 'message': 'preview'}).messages,
        isEmpty);
  });
}
