import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/core/exceptions/xboard_exception.dart'
    as app_exceptions;
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart' as sdk;

enum BackendMessageContext {
  login,
  register,
  emailVerify,
  giftCard,
  withdraw,
  transfer,
  password,
  coupon,
  order,
  ticket,
  generic,
}

class BackendMessageMapper {
  const BackendMessageMapper._();

  static String mapError(
    Object? error, {
    BackendMessageContext context = BackendMessageContext.generic,
    String? fallback,
  }) {
    return map(
      rawMessage(error),
      context: context,
      fallback: fallback,
    );
  }

  static String map(
    String? rawMessage, {
    BackendMessageContext context = BackendMessageContext.generic,
    String? fallback,
  }) {
    final raw = normalizeRaw(rawMessage);
    if (raw.isEmpty) {
      return fallback ?? _defaultFallback(context);
    }

    final mapped = _mapExact(raw) ??
        _mapPattern(raw, context) ??
        _mapChinesePattern(raw, context);
    if (mapped != null && mapped.isNotEmpty) {
      return mapped;
    }

    return raw;
  }

  static String rawMessage(Object? error) {
    if (error == null) return '';
    if (error is sdk.XBoardException) return error.message;
    if (error is app_exceptions.XBoardException) return error.message;
    return error.toString();
  }

  static String normalizeRaw(String? rawMessage) {
    var message = rawMessage?.trim() ?? '';
    if (message.isEmpty) return '';

    message = message.replaceFirst(RegExp(r'^Exception:\s*'), '');
    message = message.replaceFirst(RegExp(r'^Error:\s*'), '');
    message = message.replaceFirst(RegExp(r'^ApiException:\s*'), '');
    message = message.replaceFirst(RegExp(r'^NetworkException:\s*'), '');
    message = message.replaceFirst(RegExp(r'^AuthException:\s*'), '');
    message = message.replaceFirst(RegExp(r'^XBoardException:\s*'), '');
    message =
        message.replaceFirst(RegExp(r'^XBoardException\([^)]*\):\s*'), '');
    message = message.replaceFirst(RegExp(r'^V2Board\s+[^:：]+[:：]\s*'), '');
    message = message.replaceFirst(RegExp(r'^XBoard\s+[^:：]+[:：]\s*'), '');
    message = message.replaceFirst(RegExp(r'（错误码:\s*\d+）$'), '');
    return message.trim();
  }

  static bool matchesGiftCardAlreadyUsed(String? rawMessage) {
    final raw = normalizeRaw(rawMessage);
    final lower = raw.toLowerCase();
    return raw.contains('已被') ||
        raw.contains('已使用') ||
        _containsAny(lower, const [
          'already used',
          'has already been used',
          'has been used',
          'used by this user',
        ]) ||
        RegExp(r'\bused\b').hasMatch(lower);
  }

  static bool matchesGiftCardNotFound(String? rawMessage) {
    final raw = normalizeRaw(rawMessage);
    final lower = raw.toLowerCase();
    return raw.contains('不存在') ||
        raw.contains('无效') ||
        _containsAny(lower, const [
          'does not exist',
          'not exist',
          'not found',
          'invalid',
        ]);
  }

  static String? _mapExact(String raw) {
    final l10n = AppLocalizations.current;
    final normalized = raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    final exact = <String, String Function(AppLocalizations)>{
      'incorrect email or password': (l10n) =>
          l10n.backendErrorIncorrectEmailOrPassword,
      'your account has been suspended': (l10n) =>
          l10n.backendErrorAccountSuspended,
      'email can not be empty': (l10n) => l10n.backendErrorEmailEmpty,
      'email format is incorrect': (l10n) =>
          l10n.backendErrorEmailFormatInvalid,
      'password can not be empty': (l10n) => l10n.backendErrorPasswordEmpty,
      'password must be greater than 8 digits': (l10n) =>
          l10n.backendErrorPasswordTooShort,
      'please enter the correct verification code': (l10n) =>
          l10n.backendErrorVerificationCodeInvalid,
      'verification code is incorrect': (l10n) =>
          l10n.backendErrorVerificationCodeInvalid,
      'invalid verification code': (l10n) =>
          l10n.backendErrorVerificationCodeInvalid,
      'invite code is invalid': (l10n) => l10n.backendErrorInviteCodeInvalid,
      'invite code does not exist': (l10n) =>
          l10n.backendErrorInviteCodeNotFound,
      'email already exists': (l10n) => l10n.backendErrorEmailExists,
      'giftcard cannot be empty': (l10n) => l10n.backendErrorGiftCardEmpty,
      'the user does not exist': (l10n) => l10n.backendErrorUserNotFound,
      'the gift card does not exist': (l10n) =>
          l10n.backendErrorGiftCardNotFound,
      'the gift card is not yet valid': (l10n) =>
          l10n.backendErrorGiftCardNotYetValid,
      'the gift card has expired': (l10n) => l10n.backendErrorGiftCardExpired,
      'the gift card usage limit has been reached': (l10n) =>
          l10n.backendErrorGiftCardLimitReached,
      'the gift card has already been used by this user': (l10n) =>
          l10n.backendErrorGiftCardAlreadyUsedByUser,
      'not suitable gift card type': (l10n) =>
          l10n.backendErrorGiftCardTypeNotSuitable,
      'unknown gift card type': (l10n) => l10n.backendErrorGiftCardTypeUnknown,
      'save failed': (l10n) => l10n.backendErrorSaveFailed,
      'the withdrawal method cannot be empty': (l10n) =>
          l10n.backendErrorWithdrawalMethodEmpty,
      'the withdrawal account cannot be empty': (l10n) =>
          l10n.backendErrorWithdrawalAccountEmpty,
      'user.ticket.withdraw.not_support_withdraw': (l10n) =>
          l10n.backendErrorWithdrawNotSupported,
      'unsupported withdrawal method': (l10n) =>
          l10n.backendErrorWithdrawalMethodUnsupported,
      'failed to open ticket': (l10n) => l10n.backendErrorFailedToOpenTicket,
      'insufficient commission balance': (l10n) =>
          l10n.backendErrorInsufficientCommissionBalance,
      'transfer failed': (l10n) => l10n.backendErrorTransferFailed,
      'the transfer amount cannot be empty': (l10n) =>
          l10n.backendErrorTransferAmountEmpty,
      'the transfer amount parameter is wrong': (l10n) =>
          l10n.backendErrorTransferAmountInvalid,
      'coupon cannot be empty': (l10n) => l10n.backendErrorCouponEmpty,
      'coupon is invalid': (l10n) => l10n.backendErrorCouponInvalid,
      'coupon does not exist': (l10n) => l10n.backendErrorCouponNotFound,
      'coupon has expired': (l10n) => l10n.backendErrorCouponExpired,
      'coupon limit exceeded': (l10n) => l10n.backendErrorCouponLimitExceeded,
      'order does not exist': (l10n) => l10n.backendErrorOrderNotFound,
      'order is not found': (l10n) => l10n.backendErrorOrderNotFound,
      'plan does not exist': (l10n) => l10n.backendErrorPlanNotFound,
      'ticket does not exist': (l10n) => l10n.backendErrorTicketNotFound,
      'ticket is closed': (l10n) => l10n.backendErrorTicketClosed,
      'old password is wrong': (l10n) => l10n.backendErrorOldPasswordWrong,
      'new password can not be empty': (l10n) =>
          l10n.backendErrorNewPasswordEmpty,
      'reset failed': (l10n) => l10n.backendErrorResetFailed,
    };

    return exact[normalized]?.call(l10n);
  }

  static String? _mapPattern(String raw, BackendMessageContext context) {
    final l10n = AppLocalizations.current;
    final lower = raw.toLowerCase();

    if (lower.contains('too many password errors')) {
      final minuteMatch = RegExp(r'after\s+(\d+)\s+minutes?').firstMatch(lower);
      final minute = minuteMatch?.group(1);
      return minute == null
          ? l10n.backendErrorTooManyPasswordErrorsGeneric
          : l10n.backendErrorTooManyPasswordErrors(minute);
    }

    if (lower.contains('mail has been sent') ||
        lower.contains('please wait') && lower.contains('try again')) {
      return l10n.backendErrorTooManyRequests;
    }

    if (context == BackendMessageContext.register ||
        context == BackendMessageContext.emailVerify) {
      if (lower.contains('email') &&
          lower.contains('already') &&
          (lower.contains('exist') || lower.contains('used'))) {
        return l10n.backendErrorEmailExists;
      }
      if (lower.contains('invite') &&
          lower.contains('code') &&
          (lower.contains('invalid') || lower.contains('incorrect'))) {
        return l10n.backendErrorInviteCodeInvalid;
      }
    }

    if (context == BackendMessageContext.giftCard ||
        lower.contains('gift card') ||
        lower.contains('giftcard')) {
      if (matchesGiftCardAlreadyUsed(raw)) {
        return l10n.backendErrorGiftCardAlreadyUsedByUser;
      }
      if (matchesGiftCardNotFound(raw)) {
        return l10n.backendErrorGiftCardNotFound;
      }
      if (lower.contains('expired')) {
        return l10n.backendErrorGiftCardExpired;
      }
      if (lower.contains('not yet valid')) {
        return l10n.backendErrorGiftCardNotYetValid;
      }
    }

    if (context == BackendMessageContext.withdraw ||
        lower.contains('withdraw')) {
      if (lower.contains('minimum withdrawal commission')) {
        final limit = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(raw)?.group(1);
        return limit == null
            ? l10n.backendErrorMinimumWithdrawalCommissionGeneric
            : l10n.backendErrorMinimumWithdrawalCommission(limit);
      }
      if (lower.contains('not_support_withdraw') ||
          lower.contains('not support withdraw')) {
        return l10n.backendErrorWithdrawNotSupported;
      }
    }

    if (context == BackendMessageContext.login) {
      if (_containsAny(lower, const [
        'incorrect email or password',
        'email or password',
        'invalid credentials',
        'unauthorized',
      ])) {
        return l10n.backendErrorIncorrectEmailOrPassword;
      }
      if (_containsAny(lower, const [
        'disabled',
        'banned',
        'suspended',
        'frozen',
      ])) {
        return l10n.backendErrorAccountSuspended;
      }
    }

    if (lower.contains('does not exist') || lower.contains('not found')) {
      switch (context) {
        case BackendMessageContext.coupon:
          return l10n.backendErrorCouponNotFound;
        case BackendMessageContext.order:
          return l10n.backendErrorOrderNotFound;
        case BackendMessageContext.ticket:
          return l10n.backendErrorTicketNotFound;
        case BackendMessageContext.giftCard:
          return l10n.backendErrorGiftCardNotFound;
        case BackendMessageContext.register:
        case BackendMessageContext.emailVerify:
        case BackendMessageContext.login:
        case BackendMessageContext.withdraw:
        case BackendMessageContext.transfer:
        case BackendMessageContext.password:
        case BackendMessageContext.generic:
          break;
      }
    }

    return null;
  }

  static String? _mapChinesePattern(
    String raw,
    BackendMessageContext context,
  ) {
    final l10n = AppLocalizations.current;
    if (context == BackendMessageContext.giftCard) {
      if (raw.contains('已使用') || raw.contains('已被')) {
        return l10n.backendErrorGiftCardAlreadyUsedByUser;
      }
      if (raw.contains('不存在') || raw.contains('无效')) {
        return l10n.backendErrorGiftCardNotFound;
      }
    }
    if (context == BackendMessageContext.withdraw) {
      if (raw.contains('可提现金额不足') || raw.contains('佣金余额不足')) {
        return l10n.backendErrorInsufficientCommissionBalance;
      }
      if (raw.contains('不支持提现')) {
        return l10n.backendErrorWithdrawNotSupported;
      }
    }
    if (context == BackendMessageContext.register) {
      if (raw.contains('邮箱已存在') || raw.contains('邮箱已注册')) {
        return l10n.backendErrorEmailExists;
      }
      if (raw.contains('邀请码') && raw.contains('无效')) {
        return l10n.backendErrorInviteCodeInvalid;
      }
    }
    return null;
  }

  static bool _containsAny(String haystack, List<String> needles) {
    return needles.any(haystack.contains);
  }

  static String _defaultFallback(BackendMessageContext context) {
    final l10n = AppLocalizations.current;
    switch (context) {
      case BackendMessageContext.login:
        return l10n.backendFallbackLoginFailed;
      case BackendMessageContext.register:
        return l10n.backendFallbackRegisterFailed;
      case BackendMessageContext.emailVerify:
        return l10n.backendFallbackEmailVerifyFailed;
      case BackendMessageContext.giftCard:
        return l10n.xboardRedeemFailed;
      case BackendMessageContext.withdraw:
        return l10n.withdrawSubmissionFailed;
      case BackendMessageContext.transfer:
        return l10n.backendFallbackTransferFailed;
      case BackendMessageContext.password:
        return l10n.backendFallbackPasswordFailed;
      case BackendMessageContext.coupon:
        return l10n.backendFallbackCouponFailed;
      case BackendMessageContext.order:
        return l10n.backendFallbackOrderFailed;
      case BackendMessageContext.ticket:
        return l10n.backendFallbackTicketFailed;
      case BackendMessageContext.generic:
        return l10n.backendFallbackOperationFailed;
    }
  }
}
