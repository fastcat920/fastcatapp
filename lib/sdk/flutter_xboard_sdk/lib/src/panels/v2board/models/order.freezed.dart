// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Order _$OrderFromJson(Map<String, dynamic> json) {
  return _Order.fromJson(json);
}

/// @nodoc
mixin _$Order {
  int? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'trade_no')
  String? get tradeNo => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  int? get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'plan_id')
  int? get planId => throw _privateConstructorUsedError;
  @JsonKey(name: 'coupon_id')
  int? get couponId => throw _privateConstructorUsedError;
  @JsonKey(name: 'payment_id')
  int? get paymentId => throw _privateConstructorUsedError;
  int? get type => throw _privateConstructorUsedError;
  String? get period => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_amount')
  int? get totalAmount => throw _privateConstructorUsedError;
  int? get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'commission_status')
  int? get commissionStatus => throw _privateConstructorUsedError;
  @JsonKey(name: 'commission_balance')
  int? get commissionBalance => throw _privateConstructorUsedError;
  @JsonKey(name: 'actual_commission_balance')
  int? get actualCommissionBalance => throw _privateConstructorUsedError;
  @JsonKey(name: 'surplus_amount')
  int? get surplusAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'refund_amount')
  int? get refundAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'balance_amount')
  int? get balanceAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'surplus_order_ids')
  List<dynamic>? get surplusOrderIds => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  int? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  int? get updatedAt => throw _privateConstructorUsedError;

  /// 套餐信息（关联）
  Map<String, dynamic>? get plan => throw _privateConstructorUsedError;

  /// Serializes this Order to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderCopyWith<Order> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderCopyWith<$Res> {
  factory $OrderCopyWith(Order value, $Res Function(Order) then) =
      _$OrderCopyWithImpl<$Res, Order>;
  @useResult
  $Res call(
      {int? id,
      @JsonKey(name: 'trade_no') String? tradeNo,
      @JsonKey(name: 'user_id') int? userId,
      @JsonKey(name: 'plan_id') int? planId,
      @JsonKey(name: 'coupon_id') int? couponId,
      @JsonKey(name: 'payment_id') int? paymentId,
      int? type,
      String? period,
      @JsonKey(name: 'total_amount') int? totalAmount,
      int? status,
      @JsonKey(name: 'commission_status') int? commissionStatus,
      @JsonKey(name: 'commission_balance') int? commissionBalance,
      @JsonKey(name: 'actual_commission_balance') int? actualCommissionBalance,
      @JsonKey(name: 'surplus_amount') int? surplusAmount,
      @JsonKey(name: 'refund_amount') int? refundAmount,
      @JsonKey(name: 'balance_amount') int? balanceAmount,
      @JsonKey(name: 'surplus_order_ids') List<dynamic>? surplusOrderIds,
      @JsonKey(name: 'created_at') int? createdAt,
      @JsonKey(name: 'updated_at') int? updatedAt,
      Map<String, dynamic>? plan});
}

/// @nodoc
class _$OrderCopyWithImpl<$Res, $Val extends Order>
    implements $OrderCopyWith<$Res> {
  _$OrderCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tradeNo = freezed,
    Object? userId = freezed,
    Object? planId = freezed,
    Object? couponId = freezed,
    Object? paymentId = freezed,
    Object? type = freezed,
    Object? period = freezed,
    Object? totalAmount = freezed,
    Object? status = freezed,
    Object? commissionStatus = freezed,
    Object? commissionBalance = freezed,
    Object? actualCommissionBalance = freezed,
    Object? surplusAmount = freezed,
    Object? refundAmount = freezed,
    Object? balanceAmount = freezed,
    Object? surplusOrderIds = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? plan = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      tradeNo: freezed == tradeNo
          ? _value.tradeNo
          : tradeNo // ignore: cast_nullable_to_non_nullable
              as String?,
      userId: freezed == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as int?,
      planId: freezed == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as int?,
      couponId: freezed == couponId
          ? _value.couponId
          : couponId // ignore: cast_nullable_to_non_nullable
              as int?,
      paymentId: freezed == paymentId
          ? _value.paymentId
          : paymentId // ignore: cast_nullable_to_non_nullable
              as int?,
      type: freezed == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as int?,
      period: freezed == period
          ? _value.period
          : period // ignore: cast_nullable_to_non_nullable
              as String?,
      totalAmount: freezed == totalAmount
          ? _value.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as int?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as int?,
      commissionStatus: freezed == commissionStatus
          ? _value.commissionStatus
          : commissionStatus // ignore: cast_nullable_to_non_nullable
              as int?,
      commissionBalance: freezed == commissionBalance
          ? _value.commissionBalance
          : commissionBalance // ignore: cast_nullable_to_non_nullable
              as int?,
      actualCommissionBalance: freezed == actualCommissionBalance
          ? _value.actualCommissionBalance
          : actualCommissionBalance // ignore: cast_nullable_to_non_nullable
              as int?,
      surplusAmount: freezed == surplusAmount
          ? _value.surplusAmount
          : surplusAmount // ignore: cast_nullable_to_non_nullable
              as int?,
      refundAmount: freezed == refundAmount
          ? _value.refundAmount
          : refundAmount // ignore: cast_nullable_to_non_nullable
              as int?,
      balanceAmount: freezed == balanceAmount
          ? _value.balanceAmount
          : balanceAmount // ignore: cast_nullable_to_non_nullable
              as int?,
      surplusOrderIds: freezed == surplusOrderIds
          ? _value.surplusOrderIds
          : surplusOrderIds // ignore: cast_nullable_to_non_nullable
              as List<dynamic>?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as int?,
      plan: freezed == plan
          ? _value.plan
          : plan // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OrderImplCopyWith<$Res> implements $OrderCopyWith<$Res> {
  factory _$$OrderImplCopyWith(
          _$OrderImpl value, $Res Function(_$OrderImpl) then) =
      __$$OrderImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int? id,
      @JsonKey(name: 'trade_no') String? tradeNo,
      @JsonKey(name: 'user_id') int? userId,
      @JsonKey(name: 'plan_id') int? planId,
      @JsonKey(name: 'coupon_id') int? couponId,
      @JsonKey(name: 'payment_id') int? paymentId,
      int? type,
      String? period,
      @JsonKey(name: 'total_amount') int? totalAmount,
      int? status,
      @JsonKey(name: 'commission_status') int? commissionStatus,
      @JsonKey(name: 'commission_balance') int? commissionBalance,
      @JsonKey(name: 'actual_commission_balance') int? actualCommissionBalance,
      @JsonKey(name: 'surplus_amount') int? surplusAmount,
      @JsonKey(name: 'refund_amount') int? refundAmount,
      @JsonKey(name: 'balance_amount') int? balanceAmount,
      @JsonKey(name: 'surplus_order_ids') List<dynamic>? surplusOrderIds,
      @JsonKey(name: 'created_at') int? createdAt,
      @JsonKey(name: 'updated_at') int? updatedAt,
      Map<String, dynamic>? plan});
}

/// @nodoc
class __$$OrderImplCopyWithImpl<$Res>
    extends _$OrderCopyWithImpl<$Res, _$OrderImpl>
    implements _$$OrderImplCopyWith<$Res> {
  __$$OrderImplCopyWithImpl(
      _$OrderImpl _value, $Res Function(_$OrderImpl) _then)
      : super(_value, _then);

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tradeNo = freezed,
    Object? userId = freezed,
    Object? planId = freezed,
    Object? couponId = freezed,
    Object? paymentId = freezed,
    Object? type = freezed,
    Object? period = freezed,
    Object? totalAmount = freezed,
    Object? status = freezed,
    Object? commissionStatus = freezed,
    Object? commissionBalance = freezed,
    Object? actualCommissionBalance = freezed,
    Object? surplusAmount = freezed,
    Object? refundAmount = freezed,
    Object? balanceAmount = freezed,
    Object? surplusOrderIds = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? plan = freezed,
  }) {
    return _then(_$OrderImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      tradeNo: freezed == tradeNo
          ? _value.tradeNo
          : tradeNo // ignore: cast_nullable_to_non_nullable
              as String?,
      userId: freezed == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as int?,
      planId: freezed == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as int?,
      couponId: freezed == couponId
          ? _value.couponId
          : couponId // ignore: cast_nullable_to_non_nullable
              as int?,
      paymentId: freezed == paymentId
          ? _value.paymentId
          : paymentId // ignore: cast_nullable_to_non_nullable
              as int?,
      type: freezed == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as int?,
      period: freezed == period
          ? _value.period
          : period // ignore: cast_nullable_to_non_nullable
              as String?,
      totalAmount: freezed == totalAmount
          ? _value.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as int?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as int?,
      commissionStatus: freezed == commissionStatus
          ? _value.commissionStatus
          : commissionStatus // ignore: cast_nullable_to_non_nullable
              as int?,
      commissionBalance: freezed == commissionBalance
          ? _value.commissionBalance
          : commissionBalance // ignore: cast_nullable_to_non_nullable
              as int?,
      actualCommissionBalance: freezed == actualCommissionBalance
          ? _value.actualCommissionBalance
          : actualCommissionBalance // ignore: cast_nullable_to_non_nullable
              as int?,
      surplusAmount: freezed == surplusAmount
          ? _value.surplusAmount
          : surplusAmount // ignore: cast_nullable_to_non_nullable
              as int?,
      refundAmount: freezed == refundAmount
          ? _value.refundAmount
          : refundAmount // ignore: cast_nullable_to_non_nullable
              as int?,
      balanceAmount: freezed == balanceAmount
          ? _value.balanceAmount
          : balanceAmount // ignore: cast_nullable_to_non_nullable
              as int?,
      surplusOrderIds: freezed == surplusOrderIds
          ? _value._surplusOrderIds
          : surplusOrderIds // ignore: cast_nullable_to_non_nullable
              as List<dynamic>?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as int?,
      plan: freezed == plan
          ? _value._plan
          : plan // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderImpl extends _Order {
  const _$OrderImpl(
      {this.id,
      @JsonKey(name: 'trade_no') this.tradeNo,
      @JsonKey(name: 'user_id') this.userId,
      @JsonKey(name: 'plan_id') this.planId,
      @JsonKey(name: 'coupon_id') this.couponId,
      @JsonKey(name: 'payment_id') this.paymentId,
      this.type,
      this.period,
      @JsonKey(name: 'total_amount') this.totalAmount,
      this.status,
      @JsonKey(name: 'commission_status') this.commissionStatus,
      @JsonKey(name: 'commission_balance') this.commissionBalance,
      @JsonKey(name: 'actual_commission_balance') this.actualCommissionBalance,
      @JsonKey(name: 'surplus_amount') this.surplusAmount,
      @JsonKey(name: 'refund_amount') this.refundAmount,
      @JsonKey(name: 'balance_amount') this.balanceAmount,
      @JsonKey(name: 'surplus_order_ids') final List<dynamic>? surplusOrderIds,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt,
      final Map<String, dynamic>? plan})
      : _surplusOrderIds = surplusOrderIds,
        _plan = plan,
        super._();

  factory _$OrderImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderImplFromJson(json);

  @override
  final int? id;
  @override
  @JsonKey(name: 'trade_no')
  final String? tradeNo;
  @override
  @JsonKey(name: 'user_id')
  final int? userId;
  @override
  @JsonKey(name: 'plan_id')
  final int? planId;
  @override
  @JsonKey(name: 'coupon_id')
  final int? couponId;
  @override
  @JsonKey(name: 'payment_id')
  final int? paymentId;
  @override
  final int? type;
  @override
  final String? period;
  @override
  @JsonKey(name: 'total_amount')
  final int? totalAmount;
  @override
  final int? status;
  @override
  @JsonKey(name: 'commission_status')
  final int? commissionStatus;
  @override
  @JsonKey(name: 'commission_balance')
  final int? commissionBalance;
  @override
  @JsonKey(name: 'actual_commission_balance')
  final int? actualCommissionBalance;
  @override
  @JsonKey(name: 'surplus_amount')
  final int? surplusAmount;
  @override
  @JsonKey(name: 'refund_amount')
  final int? refundAmount;
  @override
  @JsonKey(name: 'balance_amount')
  final int? balanceAmount;
  final List<dynamic>? _surplusOrderIds;
  @override
  @JsonKey(name: 'surplus_order_ids')
  List<dynamic>? get surplusOrderIds {
    final value = _surplusOrderIds;
    if (value == null) return null;
    if (_surplusOrderIds is EqualUnmodifiableListView) return _surplusOrderIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'created_at')
  final int? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final int? updatedAt;

  /// 套餐信息（关联）
  final Map<String, dynamic>? _plan;

  /// 套餐信息（关联）
  @override
  Map<String, dynamic>? get plan {
    final value = _plan;
    if (value == null) return null;
    if (_plan is EqualUnmodifiableMapView) return _plan;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'Order(id: $id, tradeNo: $tradeNo, userId: $userId, planId: $planId, couponId: $couponId, paymentId: $paymentId, type: $type, period: $period, totalAmount: $totalAmount, status: $status, commissionStatus: $commissionStatus, commissionBalance: $commissionBalance, actualCommissionBalance: $actualCommissionBalance, surplusAmount: $surplusAmount, refundAmount: $refundAmount, balanceAmount: $balanceAmount, surplusOrderIds: $surplusOrderIds, createdAt: $createdAt, updatedAt: $updatedAt, plan: $plan)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tradeNo, tradeNo) || other.tradeNo == tradeNo) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.planId, planId) || other.planId == planId) &&
            (identical(other.couponId, couponId) ||
                other.couponId == couponId) &&
            (identical(other.paymentId, paymentId) ||
                other.paymentId == paymentId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.period, period) || other.period == period) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.commissionStatus, commissionStatus) ||
                other.commissionStatus == commissionStatus) &&
            (identical(other.commissionBalance, commissionBalance) ||
                other.commissionBalance == commissionBalance) &&
            (identical(
                    other.actualCommissionBalance, actualCommissionBalance) ||
                other.actualCommissionBalance == actualCommissionBalance) &&
            (identical(other.surplusAmount, surplusAmount) ||
                other.surplusAmount == surplusAmount) &&
            (identical(other.refundAmount, refundAmount) ||
                other.refundAmount == refundAmount) &&
            (identical(other.balanceAmount, balanceAmount) ||
                other.balanceAmount == balanceAmount) &&
            const DeepCollectionEquality()
                .equals(other._surplusOrderIds, _surplusOrderIds) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            const DeepCollectionEquality().equals(other._plan, _plan));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        tradeNo,
        userId,
        planId,
        couponId,
        paymentId,
        type,
        period,
        totalAmount,
        status,
        commissionStatus,
        commissionBalance,
        actualCommissionBalance,
        surplusAmount,
        refundAmount,
        balanceAmount,
        const DeepCollectionEquality().hash(_surplusOrderIds),
        createdAt,
        updatedAt,
        const DeepCollectionEquality().hash(_plan)
      ]);

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderImplCopyWith<_$OrderImpl> get copyWith =>
      __$$OrderImplCopyWithImpl<_$OrderImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderImplToJson(
      this,
    );
  }
}

abstract class _Order extends Order {
  const factory _Order(
      {final int? id,
      @JsonKey(name: 'trade_no') final String? tradeNo,
      @JsonKey(name: 'user_id') final int? userId,
      @JsonKey(name: 'plan_id') final int? planId,
      @JsonKey(name: 'coupon_id') final int? couponId,
      @JsonKey(name: 'payment_id') final int? paymentId,
      final int? type,
      final String? period,
      @JsonKey(name: 'total_amount') final int? totalAmount,
      final int? status,
      @JsonKey(name: 'commission_status') final int? commissionStatus,
      @JsonKey(name: 'commission_balance') final int? commissionBalance,
      @JsonKey(name: 'actual_commission_balance')
      final int? actualCommissionBalance,
      @JsonKey(name: 'surplus_amount') final int? surplusAmount,
      @JsonKey(name: 'refund_amount') final int? refundAmount,
      @JsonKey(name: 'balance_amount') final int? balanceAmount,
      @JsonKey(name: 'surplus_order_ids') final List<dynamic>? surplusOrderIds,
      @JsonKey(name: 'created_at') final int? createdAt,
      @JsonKey(name: 'updated_at') final int? updatedAt,
      final Map<String, dynamic>? plan}) = _$OrderImpl;
  const _Order._() : super._();

  factory _Order.fromJson(Map<String, dynamic> json) = _$OrderImpl.fromJson;

  @override
  int? get id;
  @override
  @JsonKey(name: 'trade_no')
  String? get tradeNo;
  @override
  @JsonKey(name: 'user_id')
  int? get userId;
  @override
  @JsonKey(name: 'plan_id')
  int? get planId;
  @override
  @JsonKey(name: 'coupon_id')
  int? get couponId;
  @override
  @JsonKey(name: 'payment_id')
  int? get paymentId;
  @override
  int? get type;
  @override
  String? get period;
  @override
  @JsonKey(name: 'total_amount')
  int? get totalAmount;
  @override
  int? get status;
  @override
  @JsonKey(name: 'commission_status')
  int? get commissionStatus;
  @override
  @JsonKey(name: 'commission_balance')
  int? get commissionBalance;
  @override
  @JsonKey(name: 'actual_commission_balance')
  int? get actualCommissionBalance;
  @override
  @JsonKey(name: 'surplus_amount')
  int? get surplusAmount;
  @override
  @JsonKey(name: 'refund_amount')
  int? get refundAmount;
  @override
  @JsonKey(name: 'balance_amount')
  int? get balanceAmount;
  @override
  @JsonKey(name: 'surplus_order_ids')
  List<dynamic>? get surplusOrderIds;
  @override
  @JsonKey(name: 'created_at')
  int? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  int? get updatedAt;

  /// 套餐信息（关联）
  @override
  Map<String, dynamic>? get plan;

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderImplCopyWith<_$OrderImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
