// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PlanImpl _$$PlanImplFromJson(Map<String, dynamic> json) => _$PlanImpl(
      id: (json['id'] as num).toInt(),
      groupId: (json['group_id'] as num?)?.toInt(),
      transferEnable: (json['transfer_enable'] as num?)?.toInt(),
      name: json['name'] as String?,
      show: (json['show'] as num?)?.toInt(),
      sort: (json['sort'] as num?)?.toInt(),
      renew: (json['renew'] as num?)?.toInt(),
      content: json['content'] as String?,
      monthPrice: (json['month_price'] as num?)?.toInt(),
      quarterPrice: (json['quarter_price'] as num?)?.toInt(),
      halfYearPrice: (json['half_year_price'] as num?)?.toInt(),
      yearPrice: (json['year_price'] as num?)?.toInt(),
      twoYearPrice: (json['two_year_price'] as num?)?.toInt(),
      threeYearPrice: (json['three_year_price'] as num?)?.toInt(),
      onetimePrice: (json['onetime_price'] as num?)?.toInt(),
      resetPrice: (json['reset_price'] as num?)?.toInt(),
      resetTrafficMethod: (json['reset_traffic_method'] as num?)?.toInt(),
      capacityLimit: (json['capacity_limit'] as num?)?.toInt(),
      speedLimit: (json['speed_limit'] as num?)?.toInt(),
      deviceLimit: (json['device_limit'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$PlanImplToJson(_$PlanImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'group_id': instance.groupId,
      'transfer_enable': instance.transferEnable,
      'name': instance.name,
      'show': instance.show,
      'sort': instance.sort,
      'renew': instance.renew,
      'content': instance.content,
      'month_price': instance.monthPrice,
      'quarter_price': instance.quarterPrice,
      'half_year_price': instance.halfYearPrice,
      'year_price': instance.yearPrice,
      'two_year_price': instance.twoYearPrice,
      'three_year_price': instance.threeYearPrice,
      'onetime_price': instance.onetimePrice,
      'reset_price': instance.resetPrice,
      'reset_traffic_method': instance.resetTrafficMethod,
      'capacity_limit': instance.capacityLimit,
      'speed_limit': instance.speedLimit,
      'device_limit': instance.deviceLimit,
    };
