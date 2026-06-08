// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrderImpl _$$OrderImplFromJson(Map<String, dynamic> json) => _$OrderImpl(
      id: (json['id'] as num?)?.toInt(),
      tradeNo: json['trade_no'] as String?,
      userId: (json['user_id'] as num?)?.toInt(),
      planId: (json['plan_id'] as num?)?.toInt(),
      couponId: (json['coupon_id'] as num?)?.toInt(),
      paymentId: (json['payment_id'] as num?)?.toInt(),
      type: (json['type'] as num?)?.toInt(),
      period: json['period'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toInt(),
      status: (json['status'] as num?)?.toInt(),
      commissionStatus: (json['commission_status'] as num?)?.toInt(),
      commissionBalance: (json['commission_balance'] as num?)?.toInt(),
      actualCommissionBalance:
          (json['actual_commission_balance'] as num?)?.toInt(),
      surplusAmount: (json['surplus_amount'] as num?)?.toInt(),
      refundAmount: (json['refund_amount'] as num?)?.toInt(),
      balanceAmount: (json['balance_amount'] as num?)?.toInt(),
      surplusOrderIds: json['surplus_order_ids'] as List<dynamic>?,
      createdAt: (json['created_at'] as num?)?.toInt(),
      updatedAt: (json['updated_at'] as num?)?.toInt(),
      plan: json['plan'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$OrderImplToJson(_$OrderImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'trade_no': instance.tradeNo,
      'user_id': instance.userId,
      'plan_id': instance.planId,
      'coupon_id': instance.couponId,
      'payment_id': instance.paymentId,
      'type': instance.type,
      'period': instance.period,
      'total_amount': instance.totalAmount,
      'status': instance.status,
      'commission_status': instance.commissionStatus,
      'commission_balance': instance.commissionBalance,
      'actual_commission_balance': instance.actualCommissionBalance,
      'surplus_amount': instance.surplusAmount,
      'refund_amount': instance.refundAmount,
      'balance_amount': instance.balanceAmount,
      'surplus_order_ids': instance.surplusOrderIds,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'plan': instance.plan,
    };
