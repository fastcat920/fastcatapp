// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'order_model.freezed.dart';
part 'order_model.g.dart';

int? _toUnixTimestamp(DateTime? date) => date?.millisecondsSinceEpoch == null
    ? null
    : date!.millisecondsSinceEpoch ~/ 1000;
DateTime? _fromUnixTimestamp(int? timestamp) => timestamp != null
    ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
    : null;

@freezed
class OrderModel with _$OrderModel {
  const factory OrderModel({
    @JsonKey(name: 'plan_id') int? planId,
    @JsonKey(name: 'trade_no') String? tradeNo,
    @JsonKey(name: 'total_amount') double? totalAmount,
    @JsonKey(name: 'balance_amount') double? balanceAmount,
    String? period,
    int? status,
    @JsonKey(
        name: 'created_at',
        fromJson: _fromUnixTimestamp,
        toJson: _toUnixTimestamp)
    DateTime? createdAt,
    @JsonKey(name: 'plan') OrderPlanModel? orderPlan,
    @JsonKey(name: 'coupon_price') double? couponPrice,
    @JsonKey(name: 'coupon_code') String? couponCode,
    @JsonKey(name: 'discount_amount') double? discountAmount,
  }) = _OrderModel;

  factory OrderModel.fromJson(Map<String, dynamic> json) =>
      _$OrderModelFromJson(json);
}

@freezed
class OrderPlanModel with _$OrderPlanModel {
  const factory OrderPlanModel({
    required int id,
    required String name,
    @JsonKey(name: 'onetime_price') double? onetimePrice,
    String? content,
  }) = _OrderPlanModel;

  factory OrderPlanModel.fromJson(Map<String, dynamic> json) =>
      _$OrderPlanModelFromJson(json);
}
