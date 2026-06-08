// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coupon_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CouponModelImpl _$$CouponModelImplFromJson(Map<String, dynamic> json) =>
    _$CouponModelImpl(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      code: json['code'] as String?,
      type: (json['type'] as num?)?.toInt(),
      value: (json['value'] as num?)?.toInt(),
      limitUse: (json['limit_use'] as num?)?.toInt(),
      limitUseWithUser: (json['limit_use_with_user'] as num?)?.toInt(),
      limitPlanIds: (json['limit_plan_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      limitPeriod: json['limitPeriod'],
      startedAt: _fromUnixTimestamp((json['started_at'] as num?)?.toInt()),
      endedAt: _fromUnixTimestamp((json['ended_at'] as num?)?.toInt()),
      show: _intToBool(json['show']),
      createdAt: _fromUnixTimestamp((json['created_at'] as num?)?.toInt()),
      updatedAt: _fromUnixTimestamp((json['updated_at'] as num?)?.toInt()),
    );

Map<String, dynamic> _$$CouponModelImplToJson(_$CouponModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'code': instance.code,
      'type': instance.type,
      'value': instance.value,
      'limit_use': instance.limitUse,
      'limit_use_with_user': instance.limitUseWithUser,
      'limit_plan_ids': instance.limitPlanIds,
      'limitPeriod': instance.limitPeriod,
      'started_at': _toUnixTimestamp(instance.startedAt),
      'ended_at': _toUnixTimestamp(instance.endedAt),
      'show': _boolToInt(instance.show),
      'created_at': _toUnixTimestamp(instance.createdAt),
      'updated_at': _toUnixTimestamp(instance.updatedAt),
    };
