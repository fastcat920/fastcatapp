import 'dart:async';

import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/infrastructure/storage/storage_interface.dart';
import 'package:fl_clash/xboard/services/storage/xboard_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage extends Fake implements StorageInterface {
  final values = <String, Object>{
    'xboard_saved_email': 'a@example.test',
    'xboard_saved_password': 'old-test-password',
    'xboard_remember_password': true,
  };
  Completer<void>? readGate;
  bool failWrite = false;
  int writes = 0;

  @override
  Future<Result<String?>> getString(String key) async {
    await readGate?.future;
    return Result.success(values[key] as String?);
  }

  @override
  Future<Result<bool?>> getBool(String key) async =>
      Result.success(values[key] as bool?);

  @override
  Future<Result<bool>> setString(String key, String value) async {
    writes++;
    if (failWrite) return Result.success(false);
    values[key] = value;
    return Result.success(true);
  }
}

void main() {
  late _Storage backing;
  late XBoardStorageService storage;
  setUp(() {
    backing = _Storage();
    storage = XBoardStorageService(backing);
  });

  Future<Result<bool>> update({
    String email = 'a@example.test',
    bool Function()? current,
  }) =>
      storage.updateRememberedPassword(
        email: email,
        previousPassword: 'old-test-password',
        newPassword: 'new-test-password',
        isCurrentSession: current ?? () => true,
      );

  test('successful change replaces only the matching remembered password',
      () async {
    expect((await update(email: ' A@example.test ')).dataOrNull, isTrue);
    expect(backing.values['xboard_saved_password'], 'new-test-password');
    expect(backing.values['xboard_saved_email'], 'a@example.test');
    expect(backing.writes, 1);
  });

  test('another account or unchecked remember never overwrites credentials',
      () async {
    await update(email: 'b@example.test');
    backing.values['xboard_remember_password'] = false;
    await update();
    expect(backing.writes, 0);
  });

  test('does not overwrite credentials already changed by a later login',
      () async {
    backing.values['xboard_saved_password'] = 'later-test-password';
    await update();
    expect(backing.writes, 0);
  });

  test('late storage read checks the current session before writing', () async {
    backing.readGate = Completer<void>();
    var current = true;
    final pending = update(current: () => current);
    current = false;
    backing.readGate!.complete();
    await pending;
    expect(backing.writes, 0);
  });

  test('a local write failure is returned without claiming server failure',
      () async {
    backing.failWrite = true;
    expect((await update()).dataOrNull, isFalse);
    expect(backing.values['xboard_saved_password'], 'old-test-password');
  });
}
