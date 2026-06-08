// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SubscriptionModelImpl _$$SubscriptionModelImplFromJson(
        Map<String, dynamic> json) =>
    _$SubscriptionModelImpl(
      subscribeUrl: json['subscribe_url'] as String?,
      plan: json['plan'] == null
          ? null
          : SubscriptionPlanModel.fromJson(
              json['plan'] as Map<String, dynamic>),
      token: json['token'] as String?,
      expiredAt: _fromUnixTimestamp(json['expired_at']),
      u: _intFromJson(json['u']),
      d: _intFromJson(json['d']),
      transferEnable: _intFromJson(json['transfer_enable']),
      planId: _intFromJson(json['plan_id']),
      email: json['email'] as String?,
      uuid: json['uuid'] as String?,
      deviceLimit: _intFromJson(json['device_limit']),
      speedLimit: _intFromJson(json['speed_limit']),
      nextResetAt: _fromUnixTimestamp(json['next_reset_at']),
      resetDay: _parseResetDay(json['reset_day']),
    );

Map<String, dynamic> _$$SubscriptionModelImplToJson(
        _$SubscriptionModelImpl instance) =>
    <String, dynamic>{
      'subscribe_url': instance.subscribeUrl,
      'plan': instance.plan,
      'token': instance.token,
      'expired_at': _toUnixTimestamp(instance.expiredAt),
      'u': _intToJson(instance.u),
      'd': _intToJson(instance.d),
      'transfer_enable': _intToJson(instance.transferEnable),
      'plan_id': _intToJson(instance.planId),
      'email': instance.email,
      'uuid': instance.uuid,
      'device_limit': _intToJson(instance.deviceLimit),
      'speed_limit': _intToJson(instance.speedLimit),
      'next_reset_at': _toUnixTimestamp(instance.nextResetAt),
      'reset_day': instance.resetDay,
    };

_$SubscriptionPlanModelImpl _$$SubscriptionPlanModelImplFromJson(
        Map<String, dynamic> json) =>
    _$SubscriptionPlanModelImpl(
      name: json['name'] as String?,
      id: _intFromJson(json['id']),
      groupId: _intFromJson(json['group_id']),
      price: _priceFromJson(json['price']),
      description: json['description'] as String?,
      content: json['content'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      transferEnable: _intFromJson(json['transfer_enable']),
      speedLimit: _intFromJson(json['speed_limit']),
      deviceLimit: _intFromJson(json['device_limit']),
      show: _intToBool(json['show']),
      sell: _intToBool(json['sell']),
      renew: _intToBool(json['renew']),
      sort: _intFromJson(json['sort']),
      onetimePrice: _priceFromJson(json['onetime_price']),
      monthPrice: _priceFromJson(json['month_price']),
      quarterPrice: _priceFromJson(json['quarter_price']),
      halfYearPrice: _priceFromJson(json['half_year_price']),
      yearPrice: _priceFromJson(json['year_price']),
      twoYearPrice: _priceFromJson(json['two_year_price']),
      threeYearPrice: _priceFromJson(json['three_year_price']),
      resetPrice: _priceFromJson(json['reset_price']),
      resetTrafficMethod: _intFromJson(json['reset_traffic_method']),
    );

Map<String, dynamic> _$$SubscriptionPlanModelImplToJson(
        _$SubscriptionPlanModelImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'id': _intToJson(instance.id),
      'group_id': _intToJson(instance.groupId),
      'price': _priceToJson(instance.price),
      'description': instance.description,
      'content': instance.content,
      'tags': instance.tags,
      'transfer_enable': _intToJson(instance.transferEnable),
      'speed_limit': _intToJson(instance.speedLimit),
      'device_limit': _intToJson(instance.deviceLimit),
      'show': _boolToInt(instance.show),
      'sell': _boolToInt(instance.sell),
      'renew': _boolToInt(instance.renew),
      'sort': _intToJson(instance.sort),
      'onetime_price': _priceToJson(instance.onetimePrice),
      'month_price': _priceToJson(instance.monthPrice),
      'quarter_price': _priceToJson(instance.quarterPrice),
      'half_year_price': _priceToJson(instance.halfYearPrice),
      'year_price': _priceToJson(instance.yearPrice),
      'two_year_price': _priceToJson(instance.twoYearPrice),
      'three_year_price': _priceToJson(instance.threeYearPrice),
      'reset_price': _priceToJson(instance.resetPrice),
      'reset_traffic_method': _intToJson(instance.resetTrafficMethod),
    };
