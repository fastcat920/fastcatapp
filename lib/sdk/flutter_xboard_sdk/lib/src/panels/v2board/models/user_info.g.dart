// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserInfoImpl _$$UserInfoImplFromJson(Map<String, dynamic> json) =>
    _$UserInfoImpl(
      email: json['email'] as String,
      transferEnable: (json['transfer_enable'] as num?)?.toInt(),
      deviceLimit: (json['device_limit'] as num?)?.toInt(),
      lastLoginAt: (json['last_login_at'] as num?)?.toInt(),
      createdAt: (json['created_at'] as num?)?.toInt(),
      banned: (json['banned'] as num?)?.toInt(),
      autoRenewal: (json['auto_renewal'] as num?)?.toInt(),
      remindExpire: (json['remind_expire'] as num?)?.toInt(),
      remindTraffic: (json['remind_traffic'] as num?)?.toInt(),
      expiredAt: (json['expired_at'] as num?)?.toInt(),
      balance: (json['balance'] as num?)?.toInt(),
      commissionBalance: (json['commission_balance'] as num?)?.toInt(),
      planId: (json['plan_id'] as num?)?.toInt(),
      discount: (json['discount'] as num?)?.toInt(),
      commissionRate: (json['commission_rate'] as num?)?.toInt(),
      telegramId: (json['telegram_id'] as num?)?.toInt(),
      uuid: json['uuid'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      u: (json['u'] as num?)?.toInt(),
      d: (json['d'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$UserInfoImplToJson(_$UserInfoImpl instance) =>
    <String, dynamic>{
      'email': instance.email,
      'transfer_enable': instance.transferEnable,
      'device_limit': instance.deviceLimit,
      'last_login_at': instance.lastLoginAt,
      'created_at': instance.createdAt,
      'banned': instance.banned,
      'auto_renewal': instance.autoRenewal,
      'remind_expire': instance.remindExpire,
      'remind_traffic': instance.remindTraffic,
      'expired_at': instance.expiredAt,
      'balance': instance.balance,
      'commission_balance': instance.commissionBalance,
      'plan_id': instance.planId,
      'discount': instance.discount,
      'commission_rate': instance.commissionRate,
      'telegram_id': instance.telegramId,
      'uuid': instance.uuid,
      'avatar_url': instance.avatarUrl,
      'u': instance.u,
      'd': instance.d,
    };
