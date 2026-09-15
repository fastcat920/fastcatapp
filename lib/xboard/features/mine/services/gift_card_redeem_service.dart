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

class GiftCardRedemptionRecord {
  const GiftCardRedemptionRecord({
    required this.id,
    required this.codeMasked,
    required this.type,
    required this.value,
    required this.redeemedAt,
    this.giftCardName,
    this.planName,
  });

  final int id;
  final String codeMasked;
  final int type;
  final num value;
  final int redeemedAt;
  final String? giftCardName;
  final String? planName;

  factory GiftCardRedemptionRecord.fromJson(Map<String, dynamic> json) {
    return GiftCardRedemptionRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      codeMasked: json['code_masked']?.toString() ?? '',
      type: (json['type'] as num?)?.toInt() ?? 0,
      value: json['value'] as num? ?? 0,
      redeemedAt: (json['redeemed_at'] as num?)?.toInt() ?? 0,
      giftCardName: json['giftcard_name']?.toString(),
      planName: json['plan_name']?.toString(),
    );
  }
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

  static Future<List<GiftCardRedemptionRecord>> fetchRedemptions({
    required WidgetRef ref,
  }) async {
    final sdk = await ref.read(xboardSdkProvider.future);
    final response =
        await sdk.httpService.getRequest('/user/giftcard/redemptions');
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => GiftCardRedemptionRecord.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
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
