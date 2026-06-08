// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SubscriptionInfoImpl _$$SubscriptionInfoImplFromJson(
        Map<String, dynamic> json) =>
    _$SubscriptionInfoImpl(
      subscribeUrl: json['subscribe_url'] as String?,
      token: json['token'] as String?,
    );

Map<String, dynamic> _$$SubscriptionInfoImplToJson(
        _$SubscriptionInfoImpl instance) =>
    <String, dynamic>{
      'subscribe_url': instance.subscribeUrl,
      'token': instance.token,
    };
