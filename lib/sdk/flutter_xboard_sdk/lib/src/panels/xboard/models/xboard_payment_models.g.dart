// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'xboard_payment_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PaymentStatusResultImpl _$$PaymentStatusResultImplFromJson(
        Map<String, dynamic> json) =>
    _$PaymentStatusResultImpl(
      isSuccess: json['isSuccess'] as bool,
      isCanceled: json['isCanceled'] as bool,
      isPending: json['isPending'] as bool,
      message: json['message'] as String?,
    );

Map<String, dynamic> _$$PaymentStatusResultImplToJson(
        _$PaymentStatusResultImpl instance) =>
    <String, dynamic>{
      'isSuccess': instance.isSuccess,
      'isCanceled': instance.isCanceled,
      'isPending': instance.isPending,
      'message': instance.message,
    };

_$PaymentOrderInfoImpl _$$PaymentOrderInfoImplFromJson(
        Map<String, dynamic> json) =>
    _$PaymentOrderInfoImpl(
      tradeNo: json['tradeNo'] as String,
      originalAmount: (json['originalAmount'] as num).toDouble(),
      finalAmount: (json['finalAmount'] as num?)?.toDouble() ?? 0.0,
      couponCode: json['couponCode'] as String?,
      discountAmount: (json['discountAmount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'CNY',
      expireTime: json['expireTime'] == null
          ? null
          : DateTime.parse(json['expireTime'] as String),
    );

Map<String, dynamic> _$$PaymentOrderInfoImplToJson(
        _$PaymentOrderInfoImpl instance) =>
    <String, dynamic>{
      'tradeNo': instance.tradeNo,
      'originalAmount': instance.originalAmount,
      'finalAmount': instance.finalAmount,
      'couponCode': instance.couponCode,
      'discountAmount': instance.discountAmount,
      'currency': instance.currency,
      'expireTime': instance.expireTime?.toIso8601String(),
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

_$PaymentRequestImpl _$$PaymentRequestImplFromJson(Map<String, dynamic> json) =>
    _$PaymentRequestImpl(
      tradeNo: json['trade_no'] as String,
      method: json['method'] as String,
    );

Map<String, dynamic> _$$PaymentRequestImplToJson(
        _$PaymentRequestImpl instance) =>
    <String, dynamic>{
      'trade_no': instance.tradeNo,
      'method': instance.method,
    };

_$PaymentResponseImpl _$$PaymentResponseImplFromJson(
        Map<String, dynamic> json) =>
    _$PaymentResponseImpl(
      success: json['success'] as bool,
      message: json['message'] as String?,
      result: json['result'] == null
          ? null
          : PaymentResult.fromJson(json['result'] as Map<String, dynamic>),
      data: json['data'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$PaymentResponseImplToJson(
        _$PaymentResponseImpl instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'result': instance.result,
      'data': instance.data,
    };
