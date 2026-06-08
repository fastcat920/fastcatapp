// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'xboard_subscription_models.freezed.dart';
part 'xboard_subscription_models.g.dart';

// Helper functions for DateTime conversion
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

/// 计划详情模型
@freezed
class PlanDetails with _$PlanDetails {
  const factory PlanDetails({
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
  }) = _PlanDetails;

  factory PlanDetails.fromJson(Map<String, dynamic> json) =>
      _$PlanDetailsFromJson(json);
}

/// 订阅信息模型
@freezed
class SubscriptionInfo with _$SubscriptionInfo {
  const factory SubscriptionInfo({
    @JsonKey(name: 'subscribe_url') String? subscribeUrl,
    PlanDetails? plan,
    String? token,
    @JsonKey(
        name: 'expired_at',
        fromJson: _fromUnixTimestamp,
        toJson: _toUnixTimestamp)
    DateTime? expiredAt,
    @JsonKey(fromJson: _intFromJson, toJson: _intToJson) int? u, // 上传流量
    @JsonKey(fromJson: _intFromJson, toJson: _intToJson) int? d, // 下载流量
    @JsonKey(
        name: 'transfer_enable', fromJson: _intFromJson, toJson: _intToJson)
    int? transferEnable, // 总流量限制
    @JsonKey(name: 'plan_id', fromJson: _intFromJson, toJson: _intToJson)
    int? planId, // 套餐ID
    String? email, // 邮箱
    String? uuid, // 用户UUID
    @JsonKey(name: 'device_limit', fromJson: _intFromJson, toJson: _intToJson)
    int? deviceLimit, // 设备限制
    @JsonKey(name: 'speed_limit', fromJson: _intFromJson, toJson: _intToJson)
    int? speedLimit, // 速度限制
    @JsonKey(
        name: 'next_reset_at',
        fromJson: _fromUnixTimestamp,
        toJson: _toUnixTimestamp)
    DateTime? nextResetAt, // 下次重置时间
    @JsonKey(name: 'reset_day', fromJson: _parseResetDay)
    int? resetDay, // 距下次重置天数
  }) = _SubscriptionInfo;

  const SubscriptionInfo._(); // Add this line

  String? get planName => plan?.name; // Derived property

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionInfoFromJson(json);
}

/// 订阅统计信息模型
class SubscriptionStats {
  final int? todayUsed;
  final int? monthUsed;
  final int? totalUsed;
  final int? totalRemaining;
  final DateTime? expiredAt;

  SubscriptionStats({
    this.todayUsed,
    this.monthUsed,
    this.totalUsed,
    this.totalRemaining,
    this.expiredAt,
  });

  factory SubscriptionStats.fromJson(dynamic json) {
    if (json is List) {
      // 如果API返回的是List，我们假设它是一个无效或默认的响应，返回一个默认实例
      return SubscriptionStats(
        todayUsed: 0,
        monthUsed: 0,
        totalUsed: 0,
        totalRemaining: 0,
        expiredAt: null,
      );
    } else if (json is Map<String, dynamic>) {
      // 否则，按正常方式解析Map
      return SubscriptionStats(
        todayUsed: json['today_used'] as int?,
        monthUsed: json['month_used'] as int?,
        totalUsed: json['total_used'] as int?,
        totalRemaining: json['total_remaining'] as int?,
        expiredAt: _fromUnixTimestamp(json['expired_at'] as int?),
      );
    }
    throw FormatException('Invalid JSON format for SubscriptionStats');
  }

  Map<String, dynamic> toJson() {
    return {
      'today_used': todayUsed,
      'month_used': monthUsed,
      'total_used': totalUsed,
      'total_remaining': totalRemaining,
      'expired_at': _toUnixTimestamp(expiredAt),
    };
  }
}

/// 订阅响应模型
@freezed
class SubscriptionResponse with _$SubscriptionResponse {
  const factory SubscriptionResponse({
    required bool success,
    String? message,
    SubscriptionInfo? data,
  }) = _SubscriptionResponse;

  factory SubscriptionResponse.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionResponseFromJson(json);
}
