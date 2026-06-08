// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

OrderModel _$OrderModelFromJson(Map<String, dynamic> json) {
  return _OrderModel.fromJson(json);
}

/// @nodoc
mixin _$OrderModel {
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
  OrderPlanModel? get orderPlan => throw _privateConstructorUsedError;

  /// Serializes this OrderModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderModelCopyWith<OrderModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderModelCopyWith<$Res> {
  factory $OrderModelCopyWith(
          OrderModel value, $Res Function(OrderModel) then) =
      _$OrderModelCopyWithImpl<$Res, OrderModel>;
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
      @JsonKey(name: 'plan') OrderPlanModel? orderPlan});

  $OrderPlanModelCopyWith<$Res>? get orderPlan;
}

/// @nodoc
class _$OrderModelCopyWithImpl<$Res, $Val extends OrderModel>
    implements $OrderModelCopyWith<$Res> {
  _$OrderModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderModel
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
              as OrderPlanModel?,
    ) as $Val);
  }

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $OrderPlanModelCopyWith<$Res>? get orderPlan {
    if (_value.orderPlan == null) {
      return null;
    }

    return $OrderPlanModelCopyWith<$Res>(_value.orderPlan!, (value) {
      return _then(_value.copyWith(orderPlan: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$OrderModelImplCopyWith<$Res>
    implements $OrderModelCopyWith<$Res> {
  factory _$$OrderModelImplCopyWith(
          _$OrderModelImpl value, $Res Function(_$OrderModelImpl) then) =
      __$$OrderModelImplCopyWithImpl<$Res>;
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
      @JsonKey(name: 'plan') OrderPlanModel? orderPlan});

  @override
  $OrderPlanModelCopyWith<$Res>? get orderPlan;
}

/// @nodoc
class __$$OrderModelImplCopyWithImpl<$Res>
    extends _$OrderModelCopyWithImpl<$Res, _$OrderModelImpl>
    implements _$$OrderModelImplCopyWith<$Res> {
  __$$OrderModelImplCopyWithImpl(
      _$OrderModelImpl _value, $Res Function(_$OrderModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrderModel
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
    return _then(_$OrderModelImpl(
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
              as OrderPlanModel?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderModelImpl implements _OrderModel {
  const _$OrderModelImpl(
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

  factory _$OrderModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderModelImplFromJson(json);

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
  final OrderPlanModel? orderPlan;

  @override
  String toString() {
    return 'OrderModel(planId: $planId, tradeNo: $tradeNo, totalAmount: $totalAmount, balanceAmount: $balanceAmount, period: $period, status: $status, createdAt: $createdAt, orderPlan: $orderPlan)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderModelImpl &&
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

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderModelImplCopyWith<_$OrderModelImpl> get copyWith =>
      __$$OrderModelImplCopyWithImpl<_$OrderModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderModelImplToJson(
      this,
    );
  }
}

abstract class _OrderModel implements OrderModel {
  const factory _OrderModel(
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
          @JsonKey(name: 'plan') final OrderPlanModel? orderPlan}) =
      _$OrderModelImpl;

  factory _OrderModel.fromJson(Map<String, dynamic> json) =
      _$OrderModelImpl.fromJson;

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
  OrderPlanModel? get orderPlan;

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderModelImplCopyWith<_$OrderModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OrderPlanModel _$OrderPlanModelFromJson(Map<String, dynamic> json) {
  return _OrderPlanModel.fromJson(json);
}

/// @nodoc
mixin _$OrderPlanModel {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'onetime_price')
  double? get onetimePrice => throw _privateConstructorUsedError;
  String? get content => throw _privateConstructorUsedError;

  /// Serializes this OrderPlanModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderPlanModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderPlanModelCopyWith<OrderPlanModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderPlanModelCopyWith<$Res> {
  factory $OrderPlanModelCopyWith(
          OrderPlanModel value, $Res Function(OrderPlanModel) then) =
      _$OrderPlanModelCopyWithImpl<$Res, OrderPlanModel>;
  @useResult
  $Res call(
      {int id,
      String name,
      @JsonKey(name: 'onetime_price') double? onetimePrice,
      String? content});
}

/// @nodoc
class _$OrderPlanModelCopyWithImpl<$Res, $Val extends OrderPlanModel>
    implements $OrderPlanModelCopyWith<$Res> {
  _$OrderPlanModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderPlanModel
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
abstract class _$$OrderPlanModelImplCopyWith<$Res>
    implements $OrderPlanModelCopyWith<$Res> {
  factory _$$OrderPlanModelImplCopyWith(_$OrderPlanModelImpl value,
          $Res Function(_$OrderPlanModelImpl) then) =
      __$$OrderPlanModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      String name,
      @JsonKey(name: 'onetime_price') double? onetimePrice,
      String? content});
}

/// @nodoc
class __$$OrderPlanModelImplCopyWithImpl<$Res>
    extends _$OrderPlanModelCopyWithImpl<$Res, _$OrderPlanModelImpl>
    implements _$$OrderPlanModelImplCopyWith<$Res> {
  __$$OrderPlanModelImplCopyWithImpl(
      _$OrderPlanModelImpl _value, $Res Function(_$OrderPlanModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrderPlanModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? onetimePrice = freezed,
    Object? content = freezed,
  }) {
    return _then(_$OrderPlanModelImpl(
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
class _$OrderPlanModelImpl implements _OrderPlanModel {
  const _$OrderPlanModelImpl(
      {required this.id,
      required this.name,
      @JsonKey(name: 'onetime_price') this.onetimePrice,
      this.content});

  factory _$OrderPlanModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderPlanModelImplFromJson(json);

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
    return 'OrderPlanModel(id: $id, name: $name, onetimePrice: $onetimePrice, content: $content)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderPlanModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.onetimePrice, onetimePrice) ||
                other.onetimePrice == onetimePrice) &&
            (identical(other.content, content) || other.content == content));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, onetimePrice, content);

  /// Create a copy of OrderPlanModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderPlanModelImplCopyWith<_$OrderPlanModelImpl> get copyWith =>
      __$$OrderPlanModelImplCopyWithImpl<_$OrderPlanModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderPlanModelImplToJson(
      this,
    );
  }
}

abstract class _OrderPlanModel implements OrderPlanModel {
  const factory _OrderPlanModel(
      {required final int id,
      required final String name,
      @JsonKey(name: 'onetime_price') final double? onetimePrice,
      final String? content}) = _$OrderPlanModelImpl;

  factory _OrderPlanModel.fromJson(Map<String, dynamic> json) =
      _$OrderPlanModelImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'onetime_price')
  double? get onetimePrice;
  @override
  String? get content;

  /// Create a copy of OrderPlanModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderPlanModelImplCopyWith<_$OrderPlanModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
