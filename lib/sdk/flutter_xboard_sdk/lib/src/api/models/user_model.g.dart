// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      email: json['email'] as String,
      transferEnable: (json['transfer_enable'] as num?)?.toDouble() ?? 0,
      lastLoginAt: _fromUnixTimestamp((json['last_login_at'] as num?)?.toInt()),
      createdAt: _fromUnixTimestamp((json['created_at'] as num?)?.toInt()),
      banned: json['banned'] == null ? false : _intToBool(json['banned']),
      remindExpire: json['remind_expire'] == null
          ? true
          : _intToBool(json['remind_expire']),
      remindTraffic: json['remind_traffic'] == null
          ? true
          : _intToBool(json['remind_traffic']),
      expiredAt: _fromUnixTimestamp((json['expired_at'] as num?)?.toInt()),
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      commissionBalance: (json['commission_balance'] as num?)?.toDouble() ?? 0,
      planId: (json['plan_id'] as num?)?.toInt(),
      discount: (json['discount'] as num?)?.toDouble(),
      commissionRate: (json['commission_rate'] as num?)?.toDouble(),
      telegramId: _telegramIdFromJson(json['telegram_id']),
      uuid: json['uuid'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'email': instance.email,
      'transfer_enable': instance.transferEnable,
      'last_login_at': _toUnixTimestamp(instance.lastLoginAt),
      'created_at': _toUnixTimestamp(instance.createdAt),
      'banned': _boolToInt(instance.banned),
      'remind_expire': _boolToInt(instance.remindExpire),
      'remind_traffic': _boolToInt(instance.remindTraffic),
      'expired_at': _toUnixTimestamp(instance.expiredAt),
      'balance': instance.balance,
      'commission_balance': instance.commissionBalance,
      'plan_id': instance.planId,
      'discount': instance.discount,
      'commission_rate': instance.commissionRate,
      'telegram_id': _telegramIdToJson(instance.telegramId),
      'uuid': instance.uuid,
      'avatar_url': instance.avatarUrl,
    };
