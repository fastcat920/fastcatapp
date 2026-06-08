// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'xboard_balance_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SystemConfigImpl _$$SystemConfigImplFromJson(Map<String, dynamic> json) =>
    _$SystemConfigImpl(
      withdrawMethods: (json['withdraw_methods'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      withdrawEnabled: _intToBool((json['withdraw_close'] as num).toInt()),
      currency: json['currency'] as String,
      currencySymbol: json['currency_symbol'] as String,
    );

Map<String, dynamic> _$$SystemConfigImplToJson(_$SystemConfigImpl instance) =>
    <String, dynamic>{
      'withdraw_methods': instance.withdrawMethods,
      'withdraw_close': _boolToInt(instance.withdrawEnabled),
      'currency': instance.currency,
      'currency_symbol': instance.currencySymbol,
    };

_$TransferResultImpl _$$TransferResultImplFromJson(Map<String, dynamic> json) =>
    _$TransferResultImpl(
      success: json['success'] as bool,
      message: json['message'] as String?,
      updatedUserInfo: json['updatedUserInfo'] == null
          ? null
          : UserInfo.fromJson(json['updatedUserInfo'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$TransferResultImplToJson(
        _$TransferResultImpl instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'updatedUserInfo': instance.updatedUserInfo,
    };

_$WithdrawResultImpl _$$WithdrawResultImplFromJson(Map<String, dynamic> json) =>
    _$WithdrawResultImpl(
      success: json['success'] as bool,
      message: json['message'] as String?,
      withdrawId: json['withdrawId'] as String?,
    );

Map<String, dynamic> _$$WithdrawResultImplToJson(
        _$WithdrawResultImpl instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'withdrawId': instance.withdrawId,
    };

_$CommissionHistoryItemImpl _$$CommissionHistoryItemImplFromJson(
        Map<String, dynamic> json) =>
    _$CommissionHistoryItemImpl(
      id: (json['id'] as num).toInt(),
      orderAmount: (json['order_amount'] as num).toInt(),
      tradeNo: json['trade_no'] as String,
      getAmount: (json['get_amount'] as num).toInt(),
      createdAt: (json['created_at'] as num).toInt(),
    );

Map<String, dynamic> _$$CommissionHistoryItemImplToJson(
        _$CommissionHistoryItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_amount': instance.orderAmount,
      'trade_no': instance.tradeNo,
      'get_amount': instance.getAmount,
      'created_at': instance.createdAt,
    };
