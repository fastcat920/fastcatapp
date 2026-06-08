// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'xboard_invite_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$InviteCodeImpl _$$InviteCodeImplFromJson(Map<String, dynamic> json) =>
    _$InviteCodeImpl(
      userId: (json['user_id'] as num).toInt(),
      code: json['code'] as String,
      pv: (json['pv'] as num?)?.toInt() ?? 0,
      status: json['status'] as bool,
      createdAt: _fromUnixTimestamp((json['created_at'] as num).toInt()),
      updatedAt: _fromUnixTimestamp((json['updated_at'] as num).toInt()),
    );

Map<String, dynamic> _$$InviteCodeImplToJson(_$InviteCodeImpl instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'code': instance.code,
      'pv': instance.pv,
      'status': instance.status,
      'created_at': _toUnixTimestamp(instance.createdAt),
      'updated_at': _toUnixTimestamp(instance.updatedAt),
    };

_$InviteInfoImpl _$$InviteInfoImplFromJson(Map<String, dynamic> json) =>
    _$InviteInfoImpl(
      codes: (json['codes'] as List<dynamic>)
          .map((e) => InviteCode.fromJson(e as Map<String, dynamic>))
          .toList(),
      stat: (json['stat'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$$InviteInfoImplToJson(_$InviteInfoImpl instance) =>
    <String, dynamic>{
      'codes': instance.codes.map((e) => e.toJson()).toList(),
      'stat': instance.stat,
    };

_$CommissionDetailImpl _$$CommissionDetailImplFromJson(
        Map<String, dynamic> json) =>
    _$CommissionDetailImpl(
      id: (json['id'] as num).toInt(),
      orderAmount: (json['order_amount'] as num).toInt(),
      tradeNo: json['trade_no'] as String,
      getAmount: (json['get_amount'] as num).toInt(),
      commissionStatus: (json['commission_status'] as num?)?.toInt() ?? 2,
      createdAt: _fromUnixTimestamp((json['created_at'] as num).toInt()),
    );

Map<String, dynamic> _$$CommissionDetailImplToJson(
        _$CommissionDetailImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_amount': instance.orderAmount,
      'trade_no': instance.tradeNo,
      'get_amount': instance.getAmount,
      'commission_status': instance.commissionStatus,
      'created_at': _toUnixTimestamp(instance.createdAt),
    };
