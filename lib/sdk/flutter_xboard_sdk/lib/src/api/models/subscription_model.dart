// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'subscription_model.freezed.dart';
part 'subscription_model.g.dart';

DateTime? _fromUnixTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    final timestamp = value.toInt();
    return DateTime.fromMillisecondsSinceEpoch(
      timestamp > 9999999999 ? timestamp : timestamp * 1000,
    );
  }
  final text = value.toString();
  final timestamp = int.tryParse(text);
  if (timestamp != null) {
    return DateTime.fromMillisecondsSinceEpoch(
      timestamp > 9999999999 ? timestamp : timestamp * 1000,
    );
  }
  return DateTime.tryParse(text);
}

int? _toUnixTimestamp(DateTime? dateTime) =>
    dateTime != null ? dateTime.millisecondsSinceEpoch ~/ 1000 : null;

int? _parseResetDay(dynamic value) {
  if (value == null) return null;
  final days = value is num ? value.toInt() : int.tryParse(value.toString());
  return days != null && days >= 0 ? days : null;
}

int? _intFromJson(dynamic value) => value == null
    ? null
    : value is num
        ? value.toInt()
        : int.tryParse(value.toString());

int? _intToJson(int? value) => value;

double? _priceFromJson(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble() / 100;
  if (value is String) {
    final parsed = double.tryParse(value);
    return parsed != null ? parsed / 100 : null;
  }
  return null;
}

int? _priceToJson(double? value) =>
    value == null ? null : (value * 100).round();

bool? _intToBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value.toInt() == 1;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
    final parsed = int.tryParse(normalized);
    if (parsed != null) return parsed == 1;
  }
  return null;
}

int? _boolToInt(bool? value) => value == null ? null : (value ? 1 : 0);

@freezed
class SubscriptionModel with _$SubscriptionModel {
  const factory SubscriptionModel({
    @JsonKey(name: 'subscribe_url') String? subscribeUrl,
    SubscriptionPlanModel? plan,
    String? token,
    @JsonKey(
        name: 'expired_at',
        fromJson: _fromUnixTimestamp,
        toJson: _toUnixTimestamp)
    DateTime? expiredAt,
    @JsonKey(fromJson: _intFromJson, toJson: _intToJson) int? u,
    @JsonKey(fromJson: _intFromJson, toJson: _intToJson) int? d,
    @JsonKey(
        name: 'transfer_enable', fromJson: _intFromJson, toJson: _intToJson)
    int? transferEnable,
    @JsonKey(name: 'plan_id', fromJson: _intFromJson, toJson: _intToJson)
    int? planId,
    String? email,
    String? uuid,
    @JsonKey(name: 'device_limit', fromJson: _intFromJson, toJson: _intToJson)
    int? deviceLimit,
    @JsonKey(name: 'speed_limit', fromJson: _intFromJson, toJson: _intToJson)
    int? speedLimit,
    @JsonKey(
        name: 'next_reset_at',
        fromJson: _fromUnixTimestamp,
        toJson: _toUnixTimestamp)
    DateTime? nextResetAt,
    @JsonKey(name: 'reset_day', fromJson: _parseResetDay) int? resetDay,
  }) = _SubscriptionModel;

  const SubscriptionModel._();

  String? get planName => plan?.name;

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionModelFromJson(json);
}

@freezed
class SubscriptionPlanModel with _$SubscriptionPlanModel {
  const factory SubscriptionPlanModel({
    String? name,
    @JsonKey(fromJson: _intFromJson, toJson: _intToJson) int? id,
    @JsonKey(name: 'group_id', fromJson: _intFromJson, toJson: _intToJson)
    int? groupId,
    @JsonKey(fromJson: _priceFromJson, toJson: _priceToJson) double? price,
    String? description,
    String? content,
    List<String>? tags,
    @JsonKey(
        name: 'transfer_enable', fromJson: _intFromJson, toJson: _intToJson)
    int? transferEnable,
    @JsonKey(name: 'speed_limit', fromJson: _intFromJson, toJson: _intToJson)
    int? speedLimit,
    @JsonKey(name: 'device_limit', fromJson: _intFromJson, toJson: _intToJson)
    int? deviceLimit,
    @JsonKey(fromJson: _intToBool, toJson: _boolToInt) bool? show,
    @JsonKey(fromJson: _intToBool, toJson: _boolToInt) bool? sell,
    @JsonKey(fromJson: _intToBool, toJson: _boolToInt) bool? renew,
    @JsonKey(fromJson: _intFromJson, toJson: _intToJson) int? sort,
    @JsonKey(
        name: 'onetime_price', fromJson: _priceFromJson, toJson: _priceToJson)
    double? onetimePrice,
    @JsonKey(
        name: 'month_price', fromJson: _priceFromJson, toJson: _priceToJson)
    double? monthPrice,
    @JsonKey(
        name: 'quarter_price', fromJson: _priceFromJson, toJson: _priceToJson)
    double? quarterPrice,
    @JsonKey(
        name: 'half_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
    double? halfYearPrice,
    @JsonKey(name: 'year_price', fromJson: _priceFromJson, toJson: _priceToJson)
    double? yearPrice,
    @JsonKey(
        name: 'two_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
    double? twoYearPrice,
    @JsonKey(
        name: 'three_year_price',
        fromJson: _priceFromJson,
        toJson: _priceToJson)
    double? threeYearPrice,
    @JsonKey(
        name: 'reset_price', fromJson: _priceFromJson, toJson: _priceToJson)
    double? resetPrice,
    @JsonKey(
        name: 'reset_traffic_method',
        fromJson: _intFromJson,
        toJson: _intToJson)
    int? resetTrafficMethod,
  }) = _SubscriptionPlanModel;

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionPlanModelFromJson(json);
}
