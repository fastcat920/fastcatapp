// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'xboard_coupon_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CouponDataImpl _$$CouponDataImplFromJson(Map<String, dynamic> json) =>
    _$CouponDataImpl(
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

Map<String, dynamic> _$$CouponDataImplToJson(_$CouponDataImpl instance) =>
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

_$CouponResponseImpl _$$CouponResponseImplFromJson(Map<String, dynamic> json) =>
    _$CouponResponseImpl(
      success: json['success'] as bool,
      message: json['message'] as String?,
      data: json['data'] == null
          ? null
          : CouponData.fromJson(json['data'] as Map<String, dynamic>),
      errors: json['errors'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$CouponResponseImplToJson(
        _$CouponResponseImpl instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'data': instance.data,
      'errors': instance.errors,
    };
