// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PlanModelImpl _$$PlanModelImplFromJson(Map<String, dynamic> json) =>
    _$PlanModelImpl(
      id: (json['id'] as num).toInt(),
      groupId: (json['group_id'] as num).toInt(),
      transferEnable: (json['transfer_enable'] as num).toDouble(),
      name: json['name'] as String,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      speedLimit: (json['speed_limit'] as num?)?.toInt(),
      show: _intToBool(json['show']),
      content: json['content'] as String?,
      onetimePrice: _priceFromJson(json['onetime_price']),
      monthPrice: _priceFromJson(json['month_price']),
      quarterPrice: _priceFromJson(json['quarter_price']),
      halfYearPrice: _priceFromJson(json['half_year_price']),
      yearPrice: _priceFromJson(json['year_price']),
      twoYearPrice: _priceFromJson(json['two_year_price']),
      threeYearPrice: _priceFromJson(json['three_year_price']),
      resetPrice: _priceFromJson(json['reset_price']),
      capacityLimit: json['capacity_limit'],
      deviceLimit: (json['device_limit'] as num?)?.toInt(),
      sell: json['sell'] == null ? true : _intToBool(json['sell']),
      renew: _intToBool(json['renew']),
      resetTrafficMethod: (json['reset_traffic_method'] as num?)?.toInt(),
      sort: (json['sort'] as num?)?.toInt(),
      createdAt: (json['created_at'] as num?)?.toInt(),
      updatedAt: (json['updated_at'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$PlanModelImplToJson(_$PlanModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'group_id': instance.groupId,
      'transfer_enable': instance.transferEnable,
      'name': instance.name,
      'tags': instance.tags,
      'speed_limit': instance.speedLimit,
      'show': _boolToInt(instance.show),
      'content': instance.content,
      'onetime_price': _priceToJson(instance.onetimePrice),
      'month_price': _priceToJson(instance.monthPrice),
      'quarter_price': _priceToJson(instance.quarterPrice),
      'half_year_price': _priceToJson(instance.halfYearPrice),
      'year_price': _priceToJson(instance.yearPrice),
      'two_year_price': _priceToJson(instance.twoYearPrice),
      'three_year_price': _priceToJson(instance.threeYearPrice),
      'reset_price': _priceToJson(instance.resetPrice),
      'capacity_limit': instance.capacityLimit,
      'device_limit': instance.deviceLimit,
      'sell': _boolToInt(instance.sell),
      'renew': _boolToInt(instance.renew),
      'reset_traffic_method': instance.resetTrafficMethod,
      'sort': instance.sort,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
