import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GiftCardRedeemResult {
  const GiftCardRedeemResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class GiftCardRedeemService {
  const GiftCardRedeemService._();

  static Future<GiftCardRedeemResult> redeem({
    required WidgetRef ref,
    required AppLocalizations l10n,
    required String code,
  }) async {
    try {
      final sdk = await ref.read(xboardSdkProvider.future);
      final isV2Board = XBoardConfig.provider.getPanelType() == 'v2board';
      final endpoint =
          isV2Board ? '/user/redeemgiftcard' : '/user/gift-card/redeem';
      final body = isV2Board ? {'giftcard': code} : {'code': code};
      final response = await sdk.httpService.postRequest(endpoint, body);
      final data = response['data'];
      final success = data != null && data != false;
      final apiMessage = response['message']?.toString();

      if (!success) {
        return GiftCardRedeemResult(
          success: false,
          message: _failureMessage(l10n, apiMessage),
        );
      }

      await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo(
            importProfile: false,
          );
      return GiftCardRedeemResult(
        success: true,
        message: l10n.xboardGiftCardRedeemSuccessRefreshed,
      );
    } catch (error) {
      return GiftCardRedeemResult(
        success: false,
        message: _failureMessage(l10n, error.toString()),
      );
    }
  }

  static String _failureMessage(AppLocalizations l10n, String? rawMessage) {
    final message = rawMessage?.trim() ?? '';
    final lowerMessage = message.toLowerCase();
    if (_matchesAlreadyUsed(message, lowerMessage)) {
      return l10n.xboardGiftCardAlreadyUsedByUser;
    }
    if (_matchesNotFound(message, lowerMessage)) {
      return l10n.xboardGiftCardNotFound;
    }
    if (message.isEmpty) {
      return l10n.xboardRedeemFailed;
    }
    return l10n.xboardRedeemFailedWithError(message);
  }

  static bool _matchesAlreadyUsed(String message, String lowerMessage) {
    return message.contains('已被') ||
        message.contains('已使用') ||
        lowerMessage.contains('already used') ||
        lowerMessage.contains('has been used') ||
        lowerMessage.contains('used by');
  }

  static bool _matchesNotFound(String message, String lowerMessage) {
    return message.contains('不存在') ||
        message.contains('无效') ||
        lowerMessage.contains('not exist') ||
        lowerMessage.contains('not found') ||
        lowerMessage.contains('invalid');
  }
}
