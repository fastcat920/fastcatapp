// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coupon.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CouponImpl _$$CouponImplFromJson(Map<String, dynamic> json) => _$CouponImpl(
      id: (json['id'] as num?)?.toInt(),
      code: json['code'] as String?,
      name: json['name'] as String?,
      type: (json['type'] as num?)?.toInt(),
      value: (json['value'] as num?)?.toInt(),
      limitUse: (json['limit_use'] as num?)?.toInt(),
      limitUseWithUser: (json['limit_use_with_user'] as num?)?.toInt(),
      limitPlanIds: (json['limit_plan_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      startedAt: (json['started_at'] as num?)?.toInt(),
      endedAt: (json['ended_at'] as num?)?.toInt(),
      createdAt: (json['created_at'] as num?)?.toInt(),
      updatedAt: (json['updated_at'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$CouponImplToJson(_$CouponImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'name': instance.name,
      'type': instance.type,
      'value': instance.value,
      'limit_use': instance.limitUse,
      'limit_use_with_user': instance.limitUseWithUser,
      'limit_plan_ids': instance.limitPlanIds,
      'started_at': instance.startedAt,
      'ended_at': instance.endedAt,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
