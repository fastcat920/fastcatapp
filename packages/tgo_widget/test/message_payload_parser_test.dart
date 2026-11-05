import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tgo_widget/src/models/message.dart';

void main() {
  group('MessagePayloadParser', () {
    const body = '{"type":1,"content":"人工客服已接入"}';

    test('parses map payloads', () {
      final payload = MessagePayloadParser.parse(jsonDecode(body));
      expect((payload as TextPayload).content, '人工客服已接入');
    });

    test('parses ordinary JSON payloads', () {
      final payload = MessagePayloadParser.parse(body);
      expect((payload as TextPayload).content, '人工客服已接入');
    });

    test('parses Base64 JSON payloads', () {
      final payload =
          MessagePayloadParser.parse(base64Encode(utf8.encode(body)));
      expect((payload as TextPayload).content, '人工客服已接入');
    });

    test('parses Base64URL JSON payloads without padding', () {
      final encoded = base64Url.encode(utf8.encode(body)).replaceAll('=', '');
      final payload = MessagePayloadParser.parse(encoded);
      expect((payload as TextPayload).content, '人工客服已接入');
    });

    test('preserves ordinary text and malformed Base64-looking text', () {
      for (final text in ['你好，欢迎咨询', 'eyJub3QtdmFsaWQtanNvbiI6dHJ1ZX0=']) {
        final payload = MessagePayloadParser.parse(text);
        expect((payload as TextPayload).content, text);
      }
    });

    test('preserves JSON object content when envelope has no type', () {
      final payload = MessagePayloadParser.parse('{"content":"hello"}');
      expect((payload as TextPayload).content, 'hello');
    });
  });
}
