import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/build_defines.dart';

void main() {
  final values = {
    'REMOTE_CONFIG_PUBLIC_KEY': base64.encode(List<int>.filled(32, 7)),
    'FASTCAT_KEY_CURRENT': base64.encode(List<int>.filled(32, 11)),
    'FASTCAT_KEY_NEXT': base64.encode(List<int>.filled(32, 19)),
    'XOR_KEY': 'test=value==',
    'APP_NAME': '快猫 Test',
    'EMPTY': '',
  };
  List<String> arguments(Map<String, String> values) => values.entries
      .map((entry) => '--dart-define=${entry.key}=${entry.value}')
      .toList();
  String cmake(Map<String, String> values) =>
      'set(FLUTTER_TOOL_ENVIRONMENT\n "DART_DEFINES=${values.entries.map((entry) => base64.encode(utf8.encode('${entry.key}=${entry.value}'))).join(',')}"\n)';

  test('JSON transport preserves padding, embedded equals, spaces and Unicode',
      () {
    final decoded = jsonDecode(jsonEncode(dartDefinesToMap(arguments(values))));
    expect(decoded, values);
    expect(base64.decode(decoded['REMOTE_CONFIG_PUBLIC_KEY']).length, 32);
    expect(base64.decode(decoded['FASTCAT_KEY_CURRENT']).length, 32);
    expect(base64.decode(decoded['FASTCAT_KEY_NEXT']).length, 32);
  });

  test('rejects malformed assignments', () {
    expect(
        () => dartDefinesToMap(['--dart-define=missing']), throwsArgumentError);
    expect(
        () => dartDefinesToMap(['--dart-define==value']), throwsArgumentError);
    expect(() => dartDefinesToMap(['--other=value']), throwsArgumentError);
  });

  test('verifies actual Flutter compilation inputs, allowing extra metadata',
      () {
    verifyCompiledDartDefines(
        cmake({...values, 'APP_VERSION': '3.6.0'}), values);
  });

  test('rejects the distributor padding regression without exposing values',
      () {
    final broken = {...values};
    broken['REMOTE_CONFIG_PUBLIC_KEY'] =
        values['REMOTE_CONFIG_PUBLIC_KEY']!.replaceAll('=', '');
    expect(
        () => verifyCompiledDartDefines(cmake(broken), values),
        throwsA(isA<StateError>().having((e) => e.message, 'safe error',
            'Flutter build parameter mismatch: REMOTE_CONFIG_PUBLIC_KEY')));
    expect(() => verifyCompiledDartDefines('', values), throwsStateError);
    final missing = {...values}..remove('XOR_KEY');
    expect(() => verifyCompiledDartDefines(cmake(missing), values),
        throwsStateError);
  });
}
