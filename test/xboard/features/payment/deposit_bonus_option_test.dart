import 'package:fl_clash/xboard/features/payment/pages/recharge_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DepositBonusOption', () {
    test('parses backend amount and zero bonus', () {
      final option = DepositBonusOption.tryParse('10:0');

      expect(option, isNotNull);
      expect(option!.amountInCents, 1000);
      expect(option.amountLabel, '10');
      expect(option.hasBonus, isFalse);
    });

    test('parses backend amount and visible bonus', () {
      final option = DepositBonusOption.tryParse('20:2');

      expect(option, isNotNull);
      expect(option!.amountInCents, 2000);
      expect(option.bonusInCents, 200);
      expect(option.bonusLabel, '2');
      expect(option.hasBonus, isTrue);
    });

    test('supports decimal values and rejects invalid config', () {
      final option = DepositBonusOption.tryParse('10.50:1.25');

      expect(option, isNotNull);
      expect(option!.amountInputText, '10.5');
      expect(option.bonusLabel, '1.25');
      expect(DepositBonusOption.tryParse('invalid'), isNull);
      expect(DepositBonusOption.tryParse('0:1'), isNull);
      expect(DepositBonusOption.tryParse('10:-1'), isNull);
    });
  });
}
