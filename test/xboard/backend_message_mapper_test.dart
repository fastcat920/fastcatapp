import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  test('generic Laravel validation error is not mapped to email format', () {
    final message = BackendMessageMapper.map(
      'The given data was invalid.',
      context: BackendMessageContext.login,
    );

    expect(message, AppLocalizations.current.backendFallbackLoginFailed);
    expect(message,
        isNot(AppLocalizations.current.backendErrorEmailFormatInvalid));
  });

  test('Chinese password validation message maps to password length error', () {
    final message = BackendMessageMapper.map(
      '密码必须大于 8 个字符',
      context: BackendMessageContext.login,
    );

    expect(message, AppLocalizations.current.backendErrorPasswordTooShort);
  });
}
