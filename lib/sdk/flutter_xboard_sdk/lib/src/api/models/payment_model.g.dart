// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PaymentMethodModelImpl _$$PaymentMethodModelImplFromJson(
        Map<String, dynamic> json) =>
    _$PaymentMethodModelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      paymentMethod: json['payment'] as String?,
      handlingFeeFixed: (json['handling_fee_fixed'] as num?)?.toDouble(),
      handlingFeePercent: (json['handling_fee_percent'] as num?)?.toDouble(),
      icon: json['icon'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      config: json['config'] as Map<String, dynamic>?,
      description: json['description'] as String?,
      minAmount: (json['min_amount'] as num?)?.toDouble(),
      maxAmount: (json['max_amount'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$PaymentMethodModelImplToJson(
        _$PaymentMethodModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'payment': instance.paymentMethod,
      'handling_fee_fixed': instance.handlingFeeFixed,
      'handling_fee_percent': instance.handlingFeePercent,
      'icon': instance.icon,
      'is_available': instance.isAvailable,
      'config': instance.config,
      'description': instance.description,
      'min_amount': instance.minAmount,
      'max_amount': instance.maxAmount,
    };

_$PaymentResultSuccessImpl _$$PaymentResultSuccessImplFromJson(
        Map<String, dynamic> json) =>
    _$PaymentResultSuccessImpl(
      transactionId: json['transactionId'] as String?,
      message: json['message'] as String?,
      extra: json['extra'] as Map<String, dynamic>?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$PaymentResultSuccessImplToJson(
        _$PaymentResultSuccessImpl instance) =>
    <String, dynamic>{
      'transactionId': instance.transactionId,
      'message': instance.message,
      'extra': instance.extra,
      'runtimeType': instance.$type,
    };

_$PaymentResultRedirectImpl _$$PaymentResultRedirectImplFromJson(
        Map<String, dynamic> json) =>
    _$PaymentResultRedirectImpl(
      url: json['url'] as String,
      method: json['method'] as String?,
      headers: (json['headers'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$PaymentResultRedirectImplToJson(
        _$PaymentResultRedirectImpl instance) =>
    <String, dynamic>{
      'url': instance.url,
      'method': instance.method,
      'headers': instance.headers,
      'runtimeType': instance.$type,
    };

_$PaymentResultFailedImpl _$$PaymentResultFailedImplFromJson(
        Map<String, dynamic> json) =>
    _$PaymentResultFailedImpl(
      message: json['message'] as String,
      errorCode: json['errorCode'] as String?,
      extra: json['extra'] as Map<String, dynamic>?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$PaymentResultFailedImplToJson(
        _$PaymentResultFailedImpl instance) =>
    <String, dynamic>{
      'message': instance.message,
      'errorCode': instance.errorCode,
      'extra': instance.extra,
      'runtimeType': instance.$type,
    };

_$PaymentResultCanceledImpl _$$PaymentResultCanceledImplFromJson(
        Map<String, dynamic> json) =>
    _$PaymentResultCanceledImpl(
      message: json['message'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$PaymentResultCanceledImplToJson(
        _$PaymentResultCanceledImpl instance) =>
    <String, dynamic>{
      'message': instance.message,
      'runtimeType': instance.$type,
    };
