// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'xboard_order_models.dart';

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
  @JsonKey(name: 'plan_id')
  int? get planId => throw _privateConstructorUsedError;
  @JsonKey(name: 'trade_no')
  String? get tradeNo => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_amount')
  double? get totalAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'balance_amount')
  double? get balanceAmount => throw _privateConstructorUsedError;
  String? get period => throw _privateConstructorUsedError;
  int? get status => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'plan')
  OrderPlan? get orderPlan => throw _privateConstructorUsedError;

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
      {@JsonKey(name: 'plan_id') int? planId,
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
      @JsonKey(name: 'plan') OrderPlan? orderPlan});

  $OrderPlanCopyWith<$Res>? get orderPlan;
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
    Object? planId = freezed,
    Object? tradeNo = freezed,
    Object? totalAmount = freezed,
    Object? balanceAmount = freezed,
    Object? period = freezed,
    Object? status = freezed,
    Object? createdAt = freezed,
    Object? orderPlan = freezed,
  }) {
    return _then(_value.copyWith(
      planId: freezed == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as int?,
      tradeNo: freezed == tradeNo
          ? _value.tradeNo
          : tradeNo // ignore: cast_nullable_to_non_nullable
              as String?,
      totalAmount: freezed == totalAmount
          ? _value.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      balanceAmount: freezed == balanceAmount
          ? _value.balanceAmount
          : balanceAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      period: freezed == period
          ? _value.period
          : period // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      orderPlan: freezed == orderPlan
          ? _value.orderPlan
          : orderPlan // ignore: cast_nullable_to_non_nullable
              as OrderPlan?,
    ) as $Val);
  }

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $OrderPlanCopyWith<$Res>? get orderPlan {
    if (_value.orderPlan == null) {
      return null;
    }

    return $OrderPlanCopyWith<$Res>(_value.orderPlan!, (value) {
      return _then(_value.copyWith(orderPlan: value) as $Val);
    });
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
      {@JsonKey(name: 'plan_id') int? planId,
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
      @JsonKey(name: 'plan') OrderPlan? orderPlan});

  @override
  $OrderPlanCopyWith<$Res>? get orderPlan;
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
    Object? planId = freezed,
    Object? tradeNo = freezed,
    Object? totalAmount = freezed,
    Object? balanceAmount = freezed,
    Object? period = freezed,
    Object? status = freezed,
    Object? createdAt = freezed,
    Object? orderPlan = freezed,
  }) {
    return _then(_$OrderImpl(
      planId: freezed == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as int?,
      tradeNo: freezed == tradeNo
          ? _value.tradeNo
          : tradeNo // ignore: cast_nullable_to_non_nullable
              as String?,
      totalAmount: freezed == totalAmount
          ? _value.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      balanceAmount: freezed == balanceAmount
          ? _value.balanceAmount
          : balanceAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      period: freezed == period
          ? _value.period
          : period // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      orderPlan: freezed == orderPlan
          ? _value.orderPlan
          : orderPlan // ignore: cast_nullable_to_non_nullable
              as OrderPlan?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderImpl implements _Order {
  const _$OrderImpl(
      {@JsonKey(name: 'plan_id') this.planId,
      @JsonKey(name: 'trade_no') this.tradeNo,
      @JsonKey(name: 'total_amount') this.totalAmount,
      @JsonKey(name: 'balance_amount') this.balanceAmount,
      this.period,
      this.status,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      this.createdAt,
      @JsonKey(name: 'plan') this.orderPlan});

  factory _$OrderImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderImplFromJson(json);

  @override
  @JsonKey(name: 'plan_id')
  final int? planId;
  @override
  @JsonKey(name: 'trade_no')
  final String? tradeNo;
  @override
  @JsonKey(name: 'total_amount')
  final double? totalAmount;
  @override
  @JsonKey(name: 'balance_amount')
  final double? balanceAmount;
  @override
  final String? period;
  @override
  final int? status;
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'plan')
  final OrderPlan? orderPlan;

  @override
  String toString() {
    return 'Order(planId: $planId, tradeNo: $tradeNo, totalAmount: $totalAmount, balanceAmount: $balanceAmount, period: $period, status: $status, createdAt: $createdAt, orderPlan: $orderPlan)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderImpl &&
            (identical(other.planId, planId) || other.planId == planId) &&
            (identical(other.tradeNo, tradeNo) || other.tradeNo == tradeNo) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.balanceAmount, balanceAmount) ||
                other.balanceAmount == balanceAmount) &&
            (identical(other.period, period) || other.period == period) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.orderPlan, orderPlan) ||
                other.orderPlan == orderPlan));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, planId, tradeNo, totalAmount,
      balanceAmount, period, status, createdAt, orderPlan);

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

abstract class _Order implements Order {
  const factory _Order(
      {@JsonKey(name: 'plan_id') final int? planId,
      @JsonKey(name: 'trade_no') final String? tradeNo,
      @JsonKey(name: 'total_amount') final double? totalAmount,
      @JsonKey(name: 'balance_amount') final double? balanceAmount,
      final String? period,
      final int? status,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      final DateTime? createdAt,
      @JsonKey(name: 'plan') final OrderPlan? orderPlan}) = _$OrderImpl;

  factory _Order.fromJson(Map<String, dynamic> json) = _$OrderImpl.fromJson;

  @override
  @JsonKey(name: 'plan_id')
  int? get planId;
  @override
  @JsonKey(name: 'trade_no')
  String? get tradeNo;
  @override
  @JsonKey(name: 'total_amount')
  double? get totalAmount;
  @override
  @JsonKey(name: 'balance_amount')
  double? get balanceAmount;
  @override
  String? get period;
  @override
  int? get status;
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'plan')
  OrderPlan? get orderPlan;

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderImplCopyWith<_$OrderImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OrderPlan _$OrderPlanFromJson(Map<String, dynamic> json) {
  return _OrderPlan.fromJson(json);
}

/// @nodoc
mixin _$OrderPlan {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'onetime_price')
  double? get onetimePrice => throw _privateConstructorUsedError;
  String? get content => throw _privateConstructorUsedError;

  /// Serializes this OrderPlan to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderPlan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderPlanCopyWith<OrderPlan> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderPlanCopyWith<$Res> {
  factory $OrderPlanCopyWith(OrderPlan value, $Res Function(OrderPlan) then) =
      _$OrderPlanCopyWithImpl<$Res, OrderPlan>;
  @useResult
  $Res call(
      {int id,
      String name,
      @JsonKey(name: 'onetime_price') double? onetimePrice,
      String? content});
}

/// @nodoc
class _$OrderPlanCopyWithImpl<$Res, $Val extends OrderPlan>
    implements $OrderPlanCopyWith<$Res> {
  _$OrderPlanCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderPlan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? onetimePrice = freezed,
    Object? content = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      onetimePrice: freezed == onetimePrice
          ? _value.onetimePrice
          : onetimePrice // ignore: cast_nullable_to_non_nullable
              as double?,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OrderPlanImplCopyWith<$Res>
    implements $OrderPlanCopyWith<$Res> {
  factory _$$OrderPlanImplCopyWith(
          _$OrderPlanImpl value, $Res Function(_$OrderPlanImpl) then) =
      __$$OrderPlanImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      String name,
      @JsonKey(name: 'onetime_price') double? onetimePrice,
      String? content});
}

/// @nodoc
class __$$OrderPlanImplCopyWithImpl<$Res>
    extends _$OrderPlanCopyWithImpl<$Res, _$OrderPlanImpl>
    implements _$$OrderPlanImplCopyWith<$Res> {
  __$$OrderPlanImplCopyWithImpl(
      _$OrderPlanImpl _value, $Res Function(_$OrderPlanImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrderPlan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? onetimePrice = freezed,
    Object? content = freezed,
  }) {
    return _then(_$OrderPlanImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      onetimePrice: freezed == onetimePrice
          ? _value.onetimePrice
          : onetimePrice // ignore: cast_nullable_to_non_nullable
              as double?,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderPlanImpl implements _OrderPlan {
  const _$OrderPlanImpl(
      {required this.id,
      required this.name,
      @JsonKey(name: 'onetime_price') this.onetimePrice,
      this.content});

  factory _$OrderPlanImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderPlanImplFromJson(json);

  @override
  final int id;
  @override
  final String name;
  @override
  @JsonKey(name: 'onetime_price')
  final double? onetimePrice;
  @override
  final String? content;

  @override
  String toString() {
    return 'OrderPlan(id: $id, name: $name, onetimePrice: $onetimePrice, content: $content)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderPlanImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.onetimePrice, onetimePrice) ||
                other.onetimePrice == onetimePrice) &&
            (identical(other.content, content) || other.content == content));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, onetimePrice, content);

  /// Create a copy of OrderPlan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderPlanImplCopyWith<_$OrderPlanImpl> get copyWith =>
      __$$OrderPlanImplCopyWithImpl<_$OrderPlanImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderPlanImplToJson(
      this,
    );
  }
}

abstract class _OrderPlan implements OrderPlan {
  const factory _OrderPlan(
      {required final int id,
      required final String name,
      @JsonKey(name: 'onetime_price') final double? onetimePrice,
      final String? content}) = _$OrderPlanImpl;

  factory _OrderPlan.fromJson(Map<String, dynamic> json) =
      _$OrderPlanImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'onetime_price')
  double? get onetimePrice;
  @override
  String? get content;

  /// Create a copy of OrderPlan
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderPlanImplCopyWith<_$OrderPlanImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CreateOrderRequest _$CreateOrderRequestFromJson(Map<String, dynamic> json) {
  return _CreateOrderRequest.fromJson(json);
}

/// @nodoc
mixin _$CreateOrderRequest {
  @JsonKey(name: 'plan_id')
  int get planId => throw _privateConstructorUsedError;
  String get period => throw _privateConstructorUsedError;
  @JsonKey(name: 'coupon_code')
  String? get couponCode => throw _privateConstructorUsedError;

  /// Serializes this CreateOrderRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CreateOrderRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CreateOrderRequestCopyWith<CreateOrderRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CreateOrderRequestCopyWith<$Res> {
  factory $CreateOrderRequestCopyWith(
          CreateOrderRequest value, $Res Function(CreateOrderRequest) then) =
      _$CreateOrderRequestCopyWithImpl<$Res, CreateOrderRequest>;
  @useResult
  $Res call(
      {@JsonKey(name: 'plan_id') int planId,
      String period,
      @JsonKey(name: 'coupon_code') String? couponCode});
}

/// @nodoc
class _$CreateOrderRequestCopyWithImpl<$Res, $Val extends CreateOrderRequest>
    implements $CreateOrderRequestCopyWith<$Res> {
  _$CreateOrderRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CreateOrderRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? planId = null,
    Object? period = null,
    Object? couponCode = freezed,
  }) {
    return _then(_value.copyWith(
      planId: null == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as int,
      period: null == period
          ? _value.period
          : period // ignore: cast_nullable_to_non_nullable
              as String,
      couponCode: freezed == couponCode
          ? _value.couponCode
          : couponCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CreateOrderRequestImplCopyWith<$Res>
    implements $CreateOrderRequestCopyWith<$Res> {
  factory _$$CreateOrderRequestImplCopyWith(_$CreateOrderRequestImpl value,
          $Res Function(_$CreateOrderRequestImpl) then) =
      __$$CreateOrderRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'plan_id') int planId,
      String period,
      @JsonKey(name: 'coupon_code') String? couponCode});
}

/// @nodoc
class __$$CreateOrderRequestImplCopyWithImpl<$Res>
    extends _$CreateOrderRequestCopyWithImpl<$Res, _$CreateOrderRequestImpl>
    implements _$$CreateOrderRequestImplCopyWith<$Res> {
  __$$CreateOrderRequestImplCopyWithImpl(_$CreateOrderRequestImpl _value,
      $Res Function(_$CreateOrderRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of CreateOrderRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? planId = null,
    Object? period = null,
    Object? couponCode = freezed,
  }) {
    return _then(_$CreateOrderRequestImpl(
      planId: null == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as int,
      period: null == period
          ? _value.period
          : period // ignore: cast_nullable_to_non_nullable
              as String,
      couponCode: freezed == couponCode
          ? _value.couponCode
          : couponCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CreateOrderRequestImpl implements _CreateOrderRequest {
  const _$CreateOrderRequestImpl(
      {@JsonKey(name: 'plan_id') required this.planId,
      required this.period,
      @JsonKey(name: 'coupon_code') this.couponCode});

  factory _$CreateOrderRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$CreateOrderRequestImplFromJson(json);

  @override
  @JsonKey(name: 'plan_id')
  final int planId;
  @override
  final String period;
  @override
  @JsonKey(name: 'coupon_code')
  final String? couponCode;

  @override
  String toString() {
    return 'CreateOrderRequest(planId: $planId, period: $period, couponCode: $couponCode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CreateOrderRequestImpl &&
            (identical(other.planId, planId) || other.planId == planId) &&
            (identical(other.period, period) || other.period == period) &&
            (identical(other.couponCode, couponCode) ||
                other.couponCode == couponCode));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, planId, period, couponCode);

  /// Create a copy of CreateOrderRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CreateOrderRequestImplCopyWith<_$CreateOrderRequestImpl> get copyWith =>
      __$$CreateOrderRequestImplCopyWithImpl<_$CreateOrderRequestImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CreateOrderRequestImplToJson(
      this,
    );
  }
}

abstract class _CreateOrderRequest implements CreateOrderRequest {
  const factory _CreateOrderRequest(
          {@JsonKey(name: 'plan_id') required final int planId,
          required final String period,
          @JsonKey(name: 'coupon_code') final String? couponCode}) =
      _$CreateOrderRequestImpl;

  factory _CreateOrderRequest.fromJson(Map<String, dynamic> json) =
      _$CreateOrderRequestImpl.fromJson;

  @override
  @JsonKey(name: 'plan_id')
  int get planId;
  @override
  String get period;
  @override
  @JsonKey(name: 'coupon_code')
  String? get couponCode;

  /// Create a copy of CreateOrderRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CreateOrderRequestImplCopyWith<_$CreateOrderRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SubmitOrderRequest _$SubmitOrderRequestFromJson(Map<String, dynamic> json) {
  return _SubmitOrderRequest.fromJson(json);
}

/// @nodoc
mixin _$SubmitOrderRequest {
  @JsonKey(name: 'trade_no')
  String get tradeNo => throw _privateConstructorUsedError;
  String get method => throw _privateConstructorUsedError;

  /// Serializes this SubmitOrderRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SubmitOrderRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SubmitOrderRequestCopyWith<SubmitOrderRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SubmitOrderRequestCopyWith<$Res> {
  factory $SubmitOrderRequestCopyWith(
          SubmitOrderRequest value, $Res Function(SubmitOrderRequest) then) =
      _$SubmitOrderRequestCopyWithImpl<$Res, SubmitOrderRequest>;
  @useResult
  $Res call({@JsonKey(name: 'trade_no') String tradeNo, String method});
}

/// @nodoc
class _$SubmitOrderRequestCopyWithImpl<$Res, $Val extends SubmitOrderRequest>
    implements $SubmitOrderRequestCopyWith<$Res> {
  _$SubmitOrderRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SubmitOrderRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tradeNo = null,
    Object? method = null,
  }) {
    return _then(_value.copyWith(
      tradeNo: null == tradeNo
          ? _value.tradeNo
          : tradeNo // ignore: cast_nullable_to_non_nullable
              as String,
      method: null == method
          ? _value.method
          : method // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SubmitOrderRequestImplCopyWith<$Res>
    implements $SubmitOrderRequestCopyWith<$Res> {
  factory _$$SubmitOrderRequestImplCopyWith(_$SubmitOrderRequestImpl value,
          $Res Function(_$SubmitOrderRequestImpl) then) =
      __$$SubmitOrderRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({@JsonKey(name: 'trade_no') String tradeNo, String method});
}

/// @nodoc
class __$$SubmitOrderRequestImplCopyWithImpl<$Res>
    extends _$SubmitOrderRequestCopyWithImpl<$Res, _$SubmitOrderRequestImpl>
    implements _$$SubmitOrderRequestImplCopyWith<$Res> {
  __$$SubmitOrderRequestImplCopyWithImpl(_$SubmitOrderRequestImpl _value,
      $Res Function(_$SubmitOrderRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of SubmitOrderRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tradeNo = null,
    Object? method = null,
  }) {
    return _then(_$SubmitOrderRequestImpl(
      tradeNo: null == tradeNo
          ? _value.tradeNo
          : tradeNo // ignore: cast_nullable_to_non_nullable
              as String,
      method: null == method
          ? _value.method
          : method // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SubmitOrderRequestImpl implements _SubmitOrderRequest {
  const _$SubmitOrderRequestImpl(
      {@JsonKey(name: 'trade_no') required this.tradeNo, required this.method});

  factory _$SubmitOrderRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$SubmitOrderRequestImplFromJson(json);

  @override
  @JsonKey(name: 'trade_no')
  final String tradeNo;
  @override
  final String method;

  @override
  String toString() {
    return 'SubmitOrderRequest(tradeNo: $tradeNo, method: $method)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SubmitOrderRequestImpl &&
            (identical(other.tradeNo, tradeNo) || other.tradeNo == tradeNo) &&
            (identical(other.method, method) || other.method == method));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, tradeNo, method);

  /// Create a copy of SubmitOrderRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SubmitOrderRequestImplCopyWith<_$SubmitOrderRequestImpl> get copyWith =>
      __$$SubmitOrderRequestImplCopyWithImpl<_$SubmitOrderRequestImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SubmitOrderRequestImplToJson(
      this,
    );
  }
}

abstract class _SubmitOrderRequest implements SubmitOrderRequest {
  const factory _SubmitOrderRequest(
      {@JsonKey(name: 'trade_no') required final String tradeNo,
      required final String method}) = _$SubmitOrderRequestImpl;

  factory _SubmitOrderRequest.fromJson(Map<String, dynamic> json) =
      _$SubmitOrderRequestImpl.fromJson;

  @override
  @JsonKey(name: 'trade_no')
  String get tradeNo;
  @override
  String get method;

  /// Create a copy of SubmitOrderRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SubmitOrderRequestImplCopyWith<_$SubmitOrderRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PaymentMethod _$PaymentMethodFromJson(Map<String, dynamic> json) {
  return _PaymentMethod.fromJson(json);
}

/// @nodoc
mixin _$PaymentMethod {
  @JsonKey(fromJson: _idFromJson, toJson: _idToJson)
  String get id =>
      throw _privateConstructorUsedError; // Custom fromJson/toJson for id
  String get name => throw _privateConstructorUsedError;
  String? get icon => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_available', defaultValue: false)
  bool get isAvailable => throw _privateConstructorUsedError;
  Map<String, dynamic>? get config => throw _privateConstructorUsedError;

  /// Serializes this PaymentMethod to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PaymentMethod
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PaymentMethodCopyWith<PaymentMethod> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentMethodCopyWith<$Res> {
  factory $PaymentMethodCopyWith(
          PaymentMethod value, $Res Function(PaymentMethod) then) =
      _$PaymentMethodCopyWithImpl<$Res, PaymentMethod>;
  @useResult
  $Res call(
      {@JsonKey(fromJson: _idFromJson, toJson: _idToJson) String id,
      String name,
      String? icon,
      @JsonKey(name: 'is_available', defaultValue: false) bool isAvailable,
      Map<String, dynamic>? config});
}

/// @nodoc
class _$PaymentMethodCopyWithImpl<$Res, $Val extends PaymentMethod>
    implements $PaymentMethodCopyWith<$Res> {
  _$PaymentMethodCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaymentMethod
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? icon = freezed,
    Object? isAvailable = null,
    Object? config = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      icon: freezed == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String?,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      config: freezed == config
          ? _value.config
          : config // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PaymentMethodImplCopyWith<$Res>
    implements $PaymentMethodCopyWith<$Res> {
  factory _$$PaymentMethodImplCopyWith(
          _$PaymentMethodImpl value, $Res Function(_$PaymentMethodImpl) then) =
      __$$PaymentMethodImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(fromJson: _idFromJson, toJson: _idToJson) String id,
      String name,
      String? icon,
      @JsonKey(name: 'is_available', defaultValue: false) bool isAvailable,
      Map<String, dynamic>? config});
}

/// @nodoc
class __$$PaymentMethodImplCopyWithImpl<$Res>
    extends _$PaymentMethodCopyWithImpl<$Res, _$PaymentMethodImpl>
    implements _$$PaymentMethodImplCopyWith<$Res> {
  __$$PaymentMethodImplCopyWithImpl(
      _$PaymentMethodImpl _value, $Res Function(_$PaymentMethodImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentMethod
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? icon = freezed,
    Object? isAvailable = null,
    Object? config = freezed,
  }) {
    return _then(_$PaymentMethodImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      icon: freezed == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String?,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      config: freezed == config
          ? _value._config
          : config // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaymentMethodImpl implements _PaymentMethod {
  const _$PaymentMethodImpl(
      {@JsonKey(fromJson: _idFromJson, toJson: _idToJson) required this.id,
      required this.name,
      this.icon,
      @JsonKey(name: 'is_available', defaultValue: false)
      required this.isAvailable,
      final Map<String, dynamic>? config})
      : _config = config;

  factory _$PaymentMethodImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaymentMethodImplFromJson(json);

  @override
  @JsonKey(fromJson: _idFromJson, toJson: _idToJson)
  final String id;
// Custom fromJson/toJson for id
  @override
  final String name;
  @override
  final String? icon;
  @override
  @JsonKey(name: 'is_available', defaultValue: false)
  final bool isAvailable;
  final Map<String, dynamic>? _config;
  @override
  Map<String, dynamic>? get config {
    final value = _config;
    if (value == null) return null;
    if (_config is EqualUnmodifiableMapView) return _config;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'PaymentMethod(id: $id, name: $name, icon: $icon, isAvailable: $isAvailable, config: $config)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentMethodImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.isAvailable, isAvailable) ||
                other.isAvailable == isAvailable) &&
            const DeepCollectionEquality().equals(other._config, _config));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, icon, isAvailable,
      const DeepCollectionEquality().hash(_config));

  /// Create a copy of PaymentMethod
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentMethodImplCopyWith<_$PaymentMethodImpl> get copyWith =>
      __$$PaymentMethodImplCopyWithImpl<_$PaymentMethodImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PaymentMethodImplToJson(
      this,
    );
  }
}

abstract class _PaymentMethod implements PaymentMethod {
  const factory _PaymentMethod(
      {@JsonKey(fromJson: _idFromJson, toJson: _idToJson)
      required final String id,
      required final String name,
      final String? icon,
      @JsonKey(name: 'is_available', defaultValue: false)
      required final bool isAvailable,
      final Map<String, dynamic>? config}) = _$PaymentMethodImpl;

  factory _PaymentMethod.fromJson(Map<String, dynamic> json) =
      _$PaymentMethodImpl.fromJson;

  @override
  @JsonKey(fromJson: _idFromJson, toJson: _idToJson)
  String get id; // Custom fromJson/toJson for id
  @override
  String get name;
  @override
  String? get icon;
  @override
  @JsonKey(name: 'is_available', defaultValue: false)
  bool get isAvailable;
  @override
  Map<String, dynamic>? get config;

  /// Create a copy of PaymentMethod
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentMethodImplCopyWith<_$PaymentMethodImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OrderPaymentInfoResponse _$OrderPaymentInfoResponseFromJson(
    Map<String, dynamic> json) {
  return _OrderPaymentInfoResponse.fromJson(json);
}

/// @nodoc
mixin _$OrderPaymentInfoResponse {
  @JsonKey(name: 'payment_methods')
  List<PaymentMethod> get paymentMethods => throw _privateConstructorUsedError;
  @JsonKey(name: 'trade_no')
  String get tradeNo => throw _privateConstructorUsedError;

  /// Serializes this OrderPaymentInfoResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderPaymentInfoResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderPaymentInfoResponseCopyWith<OrderPaymentInfoResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderPaymentInfoResponseCopyWith<$Res> {
  factory $OrderPaymentInfoResponseCopyWith(OrderPaymentInfoResponse value,
          $Res Function(OrderPaymentInfoResponse) then) =
      _$OrderPaymentInfoResponseCopyWithImpl<$Res, OrderPaymentInfoResponse>;
  @useResult
  $Res call(
      {@JsonKey(name: 'payment_methods') List<PaymentMethod> paymentMethods,
      @JsonKey(name: 'trade_no') String tradeNo});
}

/// @nodoc
class _$OrderPaymentInfoResponseCopyWithImpl<$Res,
        $Val extends OrderPaymentInfoResponse>
    implements $OrderPaymentInfoResponseCopyWith<$Res> {
  _$OrderPaymentInfoResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderPaymentInfoResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? paymentMethods = null,
    Object? tradeNo = null,
  }) {
    return _then(_value.copyWith(
      paymentMethods: null == paymentMethods
          ? _value.paymentMethods
          : paymentMethods // ignore: cast_nullable_to_non_nullable
              as List<PaymentMethod>,
      tradeNo: null == tradeNo
          ? _value.tradeNo
          : tradeNo // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OrderPaymentInfoResponseImplCopyWith<$Res>
    implements $OrderPaymentInfoResponseCopyWith<$Res> {
  factory _$$OrderPaymentInfoResponseImplCopyWith(
          _$OrderPaymentInfoResponseImpl value,
          $Res Function(_$OrderPaymentInfoResponseImpl) then) =
      __$$OrderPaymentInfoResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'payment_methods') List<PaymentMethod> paymentMethods,
      @JsonKey(name: 'trade_no') String tradeNo});
}

/// @nodoc
class __$$OrderPaymentInfoResponseImplCopyWithImpl<$Res>
    extends _$OrderPaymentInfoResponseCopyWithImpl<$Res,
        _$OrderPaymentInfoResponseImpl>
    implements _$$OrderPaymentInfoResponseImplCopyWith<$Res> {
  __$$OrderPaymentInfoResponseImplCopyWithImpl(
      _$OrderPaymentInfoResponseImpl _value,
      $Res Function(_$OrderPaymentInfoResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrderPaymentInfoResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? paymentMethods = null,
    Object? tradeNo = null,
  }) {
    return _then(_$OrderPaymentInfoResponseImpl(
      paymentMethods: null == paymentMethods
          ? _value._paymentMethods
          : paymentMethods // ignore: cast_nullable_to_non_nullable
              as List<PaymentMethod>,
      tradeNo: null == tradeNo
          ? _value.tradeNo
          : tradeNo // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderPaymentInfoResponseImpl implements _OrderPaymentInfoResponse {
  const _$OrderPaymentInfoResponseImpl(
      {@JsonKey(name: 'payment_methods')
      required final List<PaymentMethod> paymentMethods,
      @JsonKey(name: 'trade_no') required this.tradeNo})
      : _paymentMethods = paymentMethods;

  factory _$OrderPaymentInfoResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderPaymentInfoResponseImplFromJson(json);

  final List<PaymentMethod> _paymentMethods;
  @override
  @JsonKey(name: 'payment_methods')
  List<PaymentMethod> get paymentMethods {
    if (_paymentMethods is EqualUnmodifiableListView) return _paymentMethods;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_paymentMethods);
  }

  @override
  @JsonKey(name: 'trade_no')
  final String tradeNo;

  @override
  String toString() {
    return 'OrderPaymentInfoResponse(paymentMethods: $paymentMethods, tradeNo: $tradeNo)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderPaymentInfoResponseImpl &&
            const DeepCollectionEquality()
                .equals(other._paymentMethods, _paymentMethods) &&
            (identical(other.tradeNo, tradeNo) || other.tradeNo == tradeNo));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_paymentMethods), tradeNo);

  /// Create a copy of OrderPaymentInfoResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderPaymentInfoResponseImplCopyWith<_$OrderPaymentInfoResponseImpl>
      get copyWith => __$$OrderPaymentInfoResponseImplCopyWithImpl<
          _$OrderPaymentInfoResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderPaymentInfoResponseImplToJson(
      this,
    );
  }
}

abstract class _OrderPaymentInfoResponse implements OrderPaymentInfoResponse {
  const factory _OrderPaymentInfoResponse(
          {@JsonKey(name: 'payment_methods')
          required final List<PaymentMethod> paymentMethods,
          @JsonKey(name: 'trade_no') required final String tradeNo}) =
      _$OrderPaymentInfoResponseImpl;

  factory _OrderPaymentInfoResponse.fromJson(Map<String, dynamic> json) =
      _$OrderPaymentInfoResponseImpl.fromJson;

  @override
  @JsonKey(name: 'payment_methods')
  List<PaymentMethod> get paymentMethods;
  @override
  @JsonKey(name: 'trade_no')
  String get tradeNo;

  /// Create a copy of OrderPaymentInfoResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderPaymentInfoResponseImplCopyWith<_$OrderPaymentInfoResponseImpl>
      get copyWith => throw _privateConstructorUsedError;
}

OrderResponse _$OrderResponseFromJson(Map<String, dynamic> json) {
  return _OrderResponse.fromJson(json);
}

/// @nodoc
mixin _$OrderResponse {
  List<Order> get data =>
      throw _privateConstructorUsedError; // Renamed from orders to data to match ApiResponse
  int? get total => throw _privateConstructorUsedError;

  /// Serializes this OrderResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderResponseCopyWith<OrderResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderResponseCopyWith<$Res> {
  factory $OrderResponseCopyWith(
          OrderResponse value, $Res Function(OrderResponse) then) =
      _$OrderResponseCopyWithImpl<$Res, OrderResponse>;
  @useResult
  $Res call({List<Order> data, int? total});
}

/// @nodoc
class _$OrderResponseCopyWithImpl<$Res, $Val extends OrderResponse>
    implements $OrderResponseCopyWith<$Res> {
  _$OrderResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? data = null,
    Object? total = freezed,
  }) {
    return _then(_value.copyWith(
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as List<Order>,
      total: freezed == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OrderResponseImplCopyWith<$Res>
    implements $OrderResponseCopyWith<$Res> {
  factory _$$OrderResponseImplCopyWith(
          _$OrderResponseImpl value, $Res Function(_$OrderResponseImpl) then) =
      __$$OrderResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<Order> data, int? total});
}

/// @nodoc
class __$$OrderResponseImplCopyWithImpl<$Res>
    extends _$OrderResponseCopyWithImpl<$Res, _$OrderResponseImpl>
    implements _$$OrderResponseImplCopyWith<$Res> {
  __$$OrderResponseImplCopyWithImpl(
      _$OrderResponseImpl _value, $Res Function(_$OrderResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrderResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? data = null,
    Object? total = freezed,
  }) {
    return _then(_$OrderResponseImpl(
      data: null == data
          ? _value._data
          : data // ignore: cast_nullable_to_non_nullable
              as List<Order>,
      total: freezed == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderResponseImpl implements _OrderResponse {
  const _$OrderResponseImpl({required final List<Order> data, this.total})
      : _data = data;

  factory _$OrderResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderResponseImplFromJson(json);

  final List<Order> _data;
  @override
  List<Order> get data {
    if (_data is EqualUnmodifiableListView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_data);
  }

// Renamed from orders to data to match ApiResponse
  @override
  final int? total;

  @override
  String toString() {
    return 'OrderResponse(data: $data, total: $total)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderResponseImpl &&
            const DeepCollectionEquality().equals(other._data, _data) &&
            (identical(other.total, total) || other.total == total));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_data), total);

  /// Create a copy of OrderResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderResponseImplCopyWith<_$OrderResponseImpl> get copyWith =>
      __$$OrderResponseImplCopyWithImpl<_$OrderResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderResponseImplToJson(
      this,
    );
  }
}

abstract class _OrderResponse implements OrderResponse {
  const factory _OrderResponse(
      {required final List<Order> data,
      final int? total}) = _$OrderResponseImpl;

  factory _OrderResponse.fromJson(Map<String, dynamic> json) =
      _$OrderResponseImpl.fromJson;

  @override
  List<Order> get data; // Renamed from orders to data to match ApiResponse
  @override
  int? get total;

  /// Create a copy of OrderResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderResponseImplCopyWith<_$OrderResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
