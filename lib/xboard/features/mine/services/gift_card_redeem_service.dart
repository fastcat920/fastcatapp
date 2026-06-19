import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';
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
        message: _failureMessage(l10n, BackendMessageMapper.rawMessage(error)),
      );
    }
  }

  static String _failureMessage(AppLocalizations l10n, String? rawMessage) {
    if (BackendMessageMapper.matchesGiftCardAlreadyUsed(rawMessage)) {
      return l10n.xboardGiftCardAlreadyUsedByUser;
    }
    if (BackendMessageMapper.matchesGiftCardNotFound(rawMessage)) {
      return l10n.xboardGiftCardNotFound;
    }

    final message = BackendMessageMapper.map(
      rawMessage,
      context: BackendMessageContext.giftCard,
      fallback: l10n.xboardRedeemFailed,
    );
    if (message.isEmpty || message == l10n.xboardRedeemFailed) {
      return l10n.xboardRedeemFailed;
    }
    return l10n.xboardRedeemFailedWithError(message);
  }
}
