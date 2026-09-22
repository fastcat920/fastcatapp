int _intValue(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _boolValue(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    if (value == '1' || value.toLowerCase() == 'true') return true;
    if (value == '0' || value.toLowerCase() == 'false') return false;
  }
  return fallback;
}

DateTime? parseCatboardDate(dynamic value) {
  if (value == null || value == '') return null;
  if (value is num || RegExp(r'^\d+$').hasMatch(value.toString())) {
    final raw = _intValue(value);
    if (raw <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      raw > 100000000000 ? raw : raw * 1000,
    );
  }
  return DateTime.tryParse(value.toString())?.toLocal();
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : <String, dynamic>{};

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value.map(_map).where((item) => item.isNotEmpty).toList()
    : const [];

class CatboardFeatures {
  final bool couponWallet;
  final bool orderPreview;
  final bool flashSale;
  final bool referralProgram;
  final bool balanceLedger;
  final bool commissionLedger;

  const CatboardFeatures({
    this.couponWallet = false,
    this.orderPreview = false,
    this.flashSale = false,
    this.referralProgram = false,
    this.balanceLedger = false,
    this.commissionLedger = false,
  });

  factory CatboardFeatures.fromJson(Map<String, dynamic> json) =>
      CatboardFeatures(
        couponWallet: _boolValue(json['coupon_wallet']),
        orderPreview: _boolValue(json['order_preview']),
        flashSale: _boolValue(json['flash_sale']),
        referralProgram: _boolValue(json['referral_program']),
        balanceLedger: _boolValue(json['balance_ledger']),
        commissionLedger: _boolValue(json['commission_ledger']),
      );
}

class CatboardCouponTemplate {
  final int id;
  final String name;
  final String? nameEn;
  final String? description;
  final String? descriptionEn;
  final String discountType;
  final int discountValue;
  final List<int> planIds;
  final List<String> periods;
  final bool firstOrderOnly;
  final bool stackable;

  const CatboardCouponTemplate({
    required this.id,
    required this.name,
    this.nameEn,
    this.description,
    this.descriptionEn,
    required this.discountType,
    required this.discountValue,
    this.planIds = const [],
    this.periods = const [],
    this.firstOrderOnly = false,
    this.stackable = false,
  });

  factory CatboardCouponTemplate.fromJson(Map<String, dynamic> json) =>
      CatboardCouponTemplate(
        id: _intValue(json['id']),
        name: json['name']?.toString() ?? '',
        nameEn: json['name_en']?.toString(),
        description: json['description']?.toString(),
        descriptionEn: json['description_en']?.toString(),
        discountType: json['discount_type']?.toString() ?? 'fixed',
        discountValue: _intValue(json['discount_value']),
        planIds: (json['plan_ids'] as List? ?? const [])
            .map(_intValue)
            .where((id) => id > 0)
            .toList(),
        periods: (json['periods'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(),
        firstOrderOnly: _boolValue(json['first_order_only']),
        stackable: _boolValue(json['stackable']),
      );
}

class CatboardCoupon {
  final int id;
  final int templateId;
  final String source;
  final String status;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final int? orderId;
  final String? lockedTradeNo;
  final int calculatedDiscount;
  final String? unavailableReason;
  final CatboardCouponTemplate template;

  const CatboardCoupon({
    required this.id,
    required this.templateId,
    required this.source,
    required this.status,
    this.startsAt,
    this.expiresAt,
    this.orderId,
    this.lockedTradeNo,
    this.calculatedDiscount = 0,
    this.unavailableReason,
    required this.template,
  });

  factory CatboardCoupon.fromJson(Map<String, dynamic> json) => CatboardCoupon(
        id: _intValue(json['id']),
        templateId: _intValue(json['template_id']),
        source: json['source']?.toString() ?? 'manual',
        status: json['status']?.toString() ?? 'available',
        startsAt: parseCatboardDate(json['starts_at']),
        expiresAt: parseCatboardDate(json['expires_at']),
        orderId: json['order_id'] == null ? null : _intValue(json['order_id']),
        lockedTradeNo: json['locked_trade_no']?.toString(),
        calculatedDiscount: _intValue(json['calculated_discount']),
        unavailableReason: json['unavailable_reason']?.toString(),
        template: CatboardCouponTemplate.fromJson(_map(json['template'])),
      );
}

class CatboardFlashSale {
  final int id;
  final String name;
  final String? description;
  final DateTime? endsAt;
  final int originalAmount;
  final int finalAmount;
  final int discountAmount;
  final bool allowCoupon;
  final bool allowMemberDiscount;

  const CatboardFlashSale({
    required this.id,
    required this.name,
    this.description,
    this.endsAt,
    this.originalAmount = 0,
    this.finalAmount = 0,
    this.discountAmount = 0,
    this.allowCoupon = true,
    this.allowMemberDiscount = true,
  });

  factory CatboardFlashSale.fromJson(Map<String, dynamic> json) =>
      CatboardFlashSale(
        id: _intValue(json['id']),
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        endsAt: parseCatboardDate(json['ends_at']),
        originalAmount: _intValue(json['original_amount']),
        finalAmount: _intValue(json['final_amount']),
        discountAmount: _intValue(json['discount_amount']),
        allowCoupon: _boolValue(json['allow_coupon'], true),
        allowMemberDiscount: _boolValue(json['allow_member_discount'], true),
      );
}

class CatboardPromotionOption {
  final String key;
  final String type;
  final int? couponId;
  final String? name;
  final String? nameEn;
  final String? description;
  final String? descriptionEn;
  final int activityDiscount;
  final int couponDiscount;
  final int memberDiscount;
  final int discountAmount;
  final int finalAmount;
  final bool recommended;

  const CatboardPromotionOption({
    required this.key,
    required this.type,
    this.couponId,
    this.name,
    this.nameEn,
    this.description,
    this.descriptionEn,
    this.activityDiscount = 0,
    this.couponDiscount = 0,
    this.memberDiscount = 0,
    this.discountAmount = 0,
    this.finalAmount = 0,
    this.recommended = false,
  });

  factory CatboardPromotionOption.fromJson(Map<String, dynamic> json) =>
      CatboardPromotionOption(
        key: json['key']?.toString() ?? '',
        type: json['type']?.toString() ?? 'standard',
        couponId:
            json['coupon_id'] == null ? null : _intValue(json['coupon_id']),
        name: json['name']?.toString(),
        nameEn: json['name_en']?.toString(),
        description: json['description']?.toString(),
        descriptionEn: json['description_en']?.toString(),
        activityDiscount: _intValue(json['activity_discount']),
        couponDiscount: _intValue(json['coupon_discount']),
        memberDiscount: _intValue(json['member_discount']),
        discountAmount: _intValue(json['discount_amount']),
        finalAmount: _intValue(json['final_amount']),
        recommended: _boolValue(json['recommended']),
      );
}

class CatboardOrderPreview {
  final int originalAmount;
  final int activityDiscount;
  final int surplusAmount;
  final int refundAmount;
  final int couponDiscount;
  final int memberDiscountRate;
  final int memberDiscount;
  final int vipDiscount;
  final int finalAmount;
  final int balanceAmount;
  final int payableAmount;
  final bool allowCoupon;
  final bool allowMemberDiscount;
  final bool promotionExclusive;
  final CatboardFlashSale? flashSale;
  final CatboardPromotionOption? selectedPromotion;
  final List<CatboardPromotionOption> promotionOptions;
  final CatboardCoupon? selectedCoupon;
  final List<CatboardCoupon> availableCoupons;
  final List<CatboardCoupon> unavailableCoupons;

  const CatboardOrderPreview({
    required this.originalAmount,
    this.activityDiscount = 0,
    this.surplusAmount = 0,
    this.refundAmount = 0,
    this.couponDiscount = 0,
    this.memberDiscountRate = 0,
    this.memberDiscount = 0,
    this.vipDiscount = 0,
    required this.finalAmount,
    this.balanceAmount = 0,
    required this.payableAmount,
    this.allowCoupon = true,
    this.allowMemberDiscount = true,
    this.promotionExclusive = false,
    this.flashSale,
    this.selectedPromotion,
    this.promotionOptions = const [],
    this.selectedCoupon,
    this.availableCoupons = const [],
    this.unavailableCoupons = const [],
  });

  factory CatboardOrderPreview.fromJson(Map<String, dynamic> json) {
    final flash = _map(json['flash_sale']);
    final selected = _map(json['selected_coupon']);
    final selectedPromotion = _map(json['selected_promotion']);
    final finalAmount = _intValue(json['final_amount']);
    final balanceAmount = _intValue(json['balance_amount']);
    final memberDiscount =
        _intValue(json['member_discount'] ?? json['vip_discount']);
    return CatboardOrderPreview(
      originalAmount: _intValue(json['original_amount']),
      activityDiscount: _intValue(json['activity_discount']),
      surplusAmount: _intValue(json['surplus_amount']),
      refundAmount: _intValue(json['refund_amount']),
      couponDiscount: _intValue(json['coupon_discount']),
      memberDiscountRate: _intValue(json['member_discount_rate']),
      memberDiscount: memberDiscount,
      vipDiscount: memberDiscount,
      finalAmount: finalAmount,
      balanceAmount: balanceAmount,
      payableAmount: _intValue(json['payable_amount']),
      allowCoupon: _boolValue(json['allow_coupon'], true),
      allowMemberDiscount: _boolValue(json['allow_member_discount'], true),
      promotionExclusive: _boolValue(json['promotion_exclusive']),
      flashSale: flash.isEmpty ? null : CatboardFlashSale.fromJson(flash),
      selectedPromotion: selectedPromotion.isEmpty
          ? null
          : CatboardPromotionOption.fromJson(selectedPromotion),
      promotionOptions: _mapList(json['promotion_options'])
          .map(CatboardPromotionOption.fromJson)
          .toList(),
      selectedCoupon:
          selected.isEmpty ? null : CatboardCoupon.fromJson(selected),
      availableCoupons: _mapList(json['available_coupons'])
          .map(CatboardCoupon.fromJson)
          .toList(),
      unavailableCoupons: _mapList(json['unavailable_coupons'])
          .map(CatboardCoupon.fromJson)
          .toList(),
    );
  }
}

class CatboardLedgerEntry {
  final int id;
  final String type;
  final int amount;
  final int? balanceBefore;
  final int? balanceAfter;
  final String status;
  final String? tradeNo;
  final String? description;
  final Map<String, dynamic> meta;
  final DateTime? createdAt;

  const CatboardLedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    this.balanceBefore,
    this.balanceAfter,
    required this.status,
    this.tradeNo,
    this.description,
    this.meta = const {},
    this.createdAt,
  });

  factory CatboardLedgerEntry.fromJson(Map<String, dynamic> json) =>
      CatboardLedgerEntry(
        id: _intValue(json['id']),
        type: json['type']?.toString() ?? 'unknown',
        amount: _intValue(json['amount'] ?? json['get_amount']),
        balanceBefore: json['balance_before'] == null
            ? null
            : _intValue(json['balance_before']),
        balanceAfter: json['balance_after'] == null
            ? null
            : _intValue(json['balance_after']),
        status: json['status']?.toString() ?? 'completed',
        tradeNo: json['trade_no']?.toString(),
        description: json['description']?.toString(),
        meta: _map(json['meta']),
        createdAt: parseCatboardDate(json['created_at']),
      );
}

class CatboardPagedResult<T> {
  final List<T> items;
  final int total;
  final int current;
  final int pageSize;

  const CatboardPagedResult({
    required this.items,
    required this.total,
    required this.current,
    required this.pageSize,
  });
}

class CatboardInviteUser {
  final int id;
  final String email;
  final String status;
  final DateTime? createdAt;

  const CatboardInviteUser({
    required this.id,
    required this.email,
    required this.status,
    this.createdAt,
  });

  factory CatboardInviteUser.fromJson(Map<String, dynamic> json) =>
      CatboardInviteUser(
        id: _intValue(json['id']),
        email: json['email']?.toString() ?? '-',
        status: json['status']?.toString() ?? 'pending',
        createdAt: parseCatboardDate(json['created_at']),
      );

  String get maskedEmail => maskCatboardInviteEmail(email);
}

String maskCatboardInviteEmail(String email) {
  final separator = email.lastIndexOf('@');
  if (separator <= 0 || separator == email.length - 1) return email;
  final local = email.substring(0, separator);
  final domain = email.substring(separator + 1);
  if (local.contains('*')) return '$local@$domain';
  final headLength = local.length < 2 ? local.length : 2;
  final tailLength = (local.length - headLength).clamp(0, 2).toInt();
  final head = local.substring(0, headLength);
  final tail =
      tailLength == 0 ? '' : local.substring(local.length - tailLength);
  return '$head***$tail@$domain';
}

class CatboardReferralProgram {
  final int effectiveInvites;
  final int referralRevenue;
  final int commissionRate;
  final Map<String, dynamic>? level;
  final DateTime? levelExpiresAt;
  final Map<String, dynamic>? nextLevel;
  final List<Map<String, dynamic>> recentRewards;
  final Map<String, dynamic>? newcomerReward;
  final String? rewardRestrictionPolicy;

  const CatboardReferralProgram({
    this.effectiveInvites = 0,
    this.referralRevenue = 0,
    this.commissionRate = 0,
    this.level,
    this.levelExpiresAt,
    this.nextLevel,
    this.recentRewards = const [],
    this.newcomerReward,
    this.rewardRestrictionPolicy,
  });

  factory CatboardReferralProgram.fromJson(Map<String, dynamic> json) =>
      CatboardReferralProgram(
        effectiveInvites: _intValue(json['effective_invites']),
        referralRevenue: _intValue(json['referral_revenue']),
        commissionRate: _intValue(json['commission_rate']),
        level: _map(json['level']).isEmpty ? null : _map(json['level']),
        levelExpiresAt: parseCatboardDate(json['level_expires_at']),
        nextLevel:
            _map(json['next_level']).isEmpty ? null : _map(json['next_level']),
        recentRewards: _mapList(json['recent_rewards']),
        newcomerReward: _map(json['newcomer_reward']).isEmpty
            ? null
            : _map(json['newcomer_reward']),
        rewardRestrictionPolicy:
            _map(json['reward_restriction'])['policy']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'effective_invites': effectiveInvites,
        'referral_revenue': referralRevenue,
        'commission_rate': commissionRate,
        'level': level,
        'level_expires_at': levelExpiresAt?.toIso8601String(),
        'next_level': nextLevel,
        'recent_rewards': recentRewards,
        'newcomer_reward': newcomerReward,
        'reward_restriction': rewardRestrictionPolicy == null
            ? null
            : {'policy': rewardRestrictionPolicy},
      };

  Map<String, dynamic>? get nextLevelReward {
    final reward = _map(nextLevel?['reward']);
    return reward.isEmpty ? null : reward;
  }
}
