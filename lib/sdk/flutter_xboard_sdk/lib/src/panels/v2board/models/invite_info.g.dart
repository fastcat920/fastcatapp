// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$InviteInfoImpl _$$InviteInfoImplFromJson(Map<String, dynamic> json) =>
    _$InviteInfoImpl(
      codes: (json['codes'] as List<dynamic>?)
          ?.map((e) => InviteCode.fromJson(e as Map<String, dynamic>))
          .toList(),
      stat: json['stat'] == null
          ? null
          : InviteStat.fromJson(json['stat'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$InviteInfoImplToJson(_$InviteInfoImpl instance) =>
    <String, dynamic>{
      'codes': instance.codes,
      'stat': instance.stat,
    };

_$InviteCodeImpl _$$InviteCodeImplFromJson(Map<String, dynamic> json) =>
    _$InviteCodeImpl(
      id: (json['id'] as num?)?.toInt(),
      userId: (json['user_id'] as num?)?.toInt(),
      code: json['code'] as String?,
      status: (json['status'] as num?)?.toInt(),
      createdAt: (json['created_at'] as num?)?.toInt(),
      updatedAt: (json['updated_at'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$InviteCodeImplToJson(_$InviteCodeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'code': instance.code,
      'status': instance.status,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };

_$InviteStatImpl _$$InviteStatImplFromJson(Map<String, dynamic> json) =>
    _$InviteStatImpl(
      registerCount: (json['register_count'] as num?)?.toInt(),
      commissionRate: (json['commission_rate'] as num?)?.toInt(),
      commissionBalance: (json['commission_balance'] as num?)?.toInt(),
      commissionPendingBalance:
          (json['commission_pending_balance'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$InviteStatImplToJson(_$InviteStatImpl instance) =>
    <String, dynamic>{
      'register_count': instance.registerCount,
      'commission_rate': instance.commissionRate,
      'commission_balance': instance.commissionBalance,
      'commission_pending_balance': instance.commissionPendingBalance,
    };
