import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TLS validation is never bypassed by application clients', () {
    final callbackFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => file.readAsStringSync().contains(
              'badCertificateCallback',
            ))
        .toList();

    expect(callbackFiles, isEmpty);
  });
}
