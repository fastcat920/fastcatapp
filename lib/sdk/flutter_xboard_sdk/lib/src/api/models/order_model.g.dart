// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrderModelImpl _$$OrderModelImplFromJson(Map<String, dynamic> json) =>
    _$OrderModelImpl(
      planId: (json['plan_id'] as num?)?.toInt(),
      tradeNo: json['trade_no'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      balanceAmount: (json['balance_amount'] as num?)?.toDouble(),
      surplusAmount: (json['surplus_amount'] as num?)?.toDouble(),
      refundAmount: (json['refund_amount'] as num?)?.toDouble(),
      depositAmount: (json['deposit_amount'] as num?)?.toDouble(),
      depositBonusAmount: (json['bounus'] as num?)?.toDouble(),
      depositCreditedAmount: (json['get_amount'] as num?)?.toDouble(),
      depositSource: json['deposit_source'] as String?,
      commissionBalance: (json['commission_balance'] as num?)?.toDouble(),
      actualCommissionBalance:
          (json['actual_commission_balance'] as num?)?.toDouble(),
      period: json['period'] as String?,
      status: (json['status'] as num?)?.toInt(),
      createdAt: _fromUnixTimestamp((json['created_at'] as num?)?.toInt()),
      orderPlan: json['plan'] == null
          ? null
          : OrderPlanModel.fromJson(json['plan'] as Map<String, dynamic>),
      couponPrice: (json['coupon_price'] as num?)?.toDouble(),
      couponCode: json['coupon_code'] as String?,
      discountAmount: (json['discount_amount'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$OrderModelImplToJson(_$OrderModelImpl instance) =>
    <String, dynamic>{
      'plan_id': instance.planId,
      'trade_no': instance.tradeNo,
      'total_amount': instance.totalAmount,
      'balance_amount': instance.balanceAmount,
      'surplus_amount': instance.surplusAmount,
      'refund_amount': instance.refundAmount,
      'deposit_amount': instance.depositAmount,
      'bounus': instance.depositBonusAmount,
      'get_amount': instance.depositCreditedAmount,
      'deposit_source': instance.depositSource,
      'commission_balance': instance.commissionBalance,
      'actual_commission_balance': instance.actualCommissionBalance,
      'period': instance.period,
      'status': instance.status,
      'created_at': _toUnixTimestamp(instance.createdAt),
      'plan': instance.orderPlan,
      'coupon_price': instance.couponPrice,
      'coupon_code': instance.couponCode,
      'discount_amount': instance.discountAmount,
    };

_$OrderPlanModelImpl _$$OrderPlanModelImplFromJson(Map<String, dynamic> json) =>
    _$OrderPlanModelImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      onetimePrice: (json['onetime_price'] as num?)?.toDouble(),
      content: json['content'] as String?,
    );

Map<String, dynamic> _$$OrderPlanModelImplToJson(
        _$OrderPlanModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'onetime_price': instance.onetimePrice,
      'content': instance.content,
    };
