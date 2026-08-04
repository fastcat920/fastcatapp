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

  test('new period insufficient duration error is localized', () {
    final message = BackendMessageMapper.map(
      'You do not have enough time to renew your subscription',
      context: BackendMessageContext.newPeriod,
    );

    expect(
        message, AppLocalizations.current.xboardNewPeriodInsufficientDuration);
  });

  test('new period not allowed error is localized', () {
    final message = BackendMessageMapper.map(
      'Renewal is not allowed',
      context: BackendMessageContext.newPeriod,
    );

    expect(message, AppLocalizations.current.xboardNewPeriodNotAllowed);
  });

  test('unknown English new period error uses localized fallback', () {
    final message = BackendMessageMapper.map(
      'Unexpected backend failure',
      context: BackendMessageContext.newPeriod,
    );

    expect(message, AppLocalizations.current.xboardNewPeriodFailed);
  });

  test('Chinese new period error detail is preserved', () {
    final message = BackendMessageMapper.map(
      '当前套餐状态不支持此操作',
      context: BackendMessageContext.newPeriod,
    );

    expect(message, '当前套餐状态不支持此操作');
  });
}
