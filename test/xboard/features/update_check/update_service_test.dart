import 'package:fl_clash/xboard/features/update_check/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = UpdateService();

  test('compares semantic versions without treating build numbers as releases',
      () {
    expect(service.isNewerVersion('3.5.7', '3.5.8'), isTrue);
    expect(service.isNewerVersion('3.5.8+7', '3.5.8'), isFalse);
    expect(service.isNewerVersion('v3.5.8', '3.5.9'), isTrue);
    expect(service.isNewerVersion('3.6.0', '3.5.9'), isFalse);
  });
}
