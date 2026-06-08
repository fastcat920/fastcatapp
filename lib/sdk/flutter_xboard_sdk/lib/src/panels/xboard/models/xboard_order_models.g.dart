// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'xboard_order_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrderImpl _$$OrderImplFromJson(Map<String, dynamic> json) => _$OrderImpl(
      planId: (json['plan_id'] as num?)?.toInt(),
      tradeNo: json['trade_no'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      balanceAmount: (json['balance_amount'] as num?)?.toDouble(),
      period: json['period'] as String?,
      status: (json['status'] as num?)?.toInt(),
      createdAt: _fromUnixTimestamp((json['created_at'] as num?)?.toInt()),
      orderPlan: json['plan'] == null
          ? null
          : OrderPlan.fromJson(json['plan'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$OrderImplToJson(_$OrderImpl instance) =>
    <String, dynamic>{
      'plan_id': instance.planId,
      'trade_no': instance.tradeNo,
      'total_amount': instance.totalAmount,
      'balance_amount': instance.balanceAmount,
      'period': instance.period,
      'status': instance.status,
      'created_at': _toUnixTimestamp(instance.createdAt),
      'plan': instance.orderPlan,
    };

_$OrderPlanImpl _$$OrderPlanImplFromJson(Map<String, dynamic> json) =>
    _$OrderPlanImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      onetimePrice: (json['onetime_price'] as num?)?.toDouble(),
      content: json['content'] as String?,
    );

Map<String, dynamic> _$$OrderPlanImplToJson(_$OrderPlanImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'onetime_price': instance.onetimePrice,
      'content': instance.content,
    };

_$CreateOrderRequestImpl _$$CreateOrderRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$CreateOrderRequestImpl(
      planId: (json['plan_id'] as num).toInt(),
      period: json['period'] as String,
      couponCode: json['coupon_code'] as String?,
    );

Map<String, dynamic> _$$CreateOrderRequestImplToJson(
        _$CreateOrderRequestImpl instance) =>
    <String, dynamic>{
      'plan_id': instance.planId,
      'period': instance.period,
      'coupon_code': instance.couponCode,
    };

_$SubmitOrderRequestImpl _$$SubmitOrderRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$SubmitOrderRequestImpl(
      tradeNo: json['trade_no'] as String,
      method: json['method'] as String,
    );

Map<String, dynamic> _$$SubmitOrderRequestImplToJson(
        _$SubmitOrderRequestImpl instance) =>
    <String, dynamic>{
      'trade_no': instance.tradeNo,
      'method': instance.method,
    };

_$PaymentMethodImpl _$$PaymentMethodImplFromJson(Map<String, dynamic> json) =>
    _$PaymentMethodImpl(
      id: _idFromJson(json['id']),
      name: json['name'] as String,
      icon: json['icon'] as String?,
      isAvailable: json['is_available'] as bool? ?? false,
      config: json['config'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$PaymentMethodImplToJson(_$PaymentMethodImpl instance) =>
    <String, dynamic>{
      'id': _idToJson(instance.id),
      'name': instance.name,
      'icon': instance.icon,
      'is_available': instance.isAvailable,
      'config': instance.config,
    };

_$OrderPaymentInfoResponseImpl _$$OrderPaymentInfoResponseImplFromJson(
        Map<String, dynamic> json) =>
    _$OrderPaymentInfoResponseImpl(
      paymentMethods: (json['payment_methods'] as List<dynamic>)
          .map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>))
          .toList(),
      tradeNo: json['trade_no'] as String,
    );

Map<String, dynamic> _$$OrderPaymentInfoResponseImplToJson(
        _$OrderPaymentInfoResponseImpl instance) =>
    <String, dynamic>{
      'payment_methods': instance.paymentMethods,
      'trade_no': instance.tradeNo,
    };

_$OrderResponseImpl _$$OrderResponseImplFromJson(Map<String, dynamic> json) =>
    _$OrderResponseImpl(
      data: (json['data'] as List<dynamic>)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$OrderResponseImplToJson(_$OrderResponseImpl instance) =>
    <String, dynamic>{
      'data': instance.data,
      'total': instance.total,
    };
