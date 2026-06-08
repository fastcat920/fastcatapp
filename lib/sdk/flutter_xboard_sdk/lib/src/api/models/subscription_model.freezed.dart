// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subscription_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SubscriptionModel _$SubscriptionModelFromJson(Map<String, dynamic> json) {
  return _SubscriptionModel.fromJson(json);
}

/// @nodoc
mixin _$SubscriptionModel {
  @JsonKey(name: 'subscribe_url')
  String? get subscribeUrl => throw _privateConstructorUsedError;
  SubscriptionPlanModel? get plan => throw _privateConstructorUsedError;
  String? get token => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'expired_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get expiredAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _intFromJson, toJson: _intToJson)
  int? get u => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _intFromJson, toJson: _intToJson)
  int? get d => throw _privateConstructorUsedError;
  @JsonKey(name: 'transfer_enable', fromJson: _intFromJson, toJson: _intToJson)
  int? get transferEnable => throw _privateConstructorUsedError;
  @JsonKey(name: 'plan_id', fromJson: _intFromJson, toJson: _intToJson)
  int? get planId => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String? get uuid => throw _privateConstructorUsedError;
  @JsonKey(name: 'device_limit', fromJson: _intFromJson, toJson: _intToJson)
  int? get deviceLimit => throw _privateConstructorUsedError;
  @JsonKey(name: 'speed_limit', fromJson: _intFromJson, toJson: _intToJson)
  int? get speedLimit => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'next_reset_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get nextResetAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'reset_day', fromJson: _parseResetDay)
  int? get resetDay => throw _privateConstructorUsedError;

  /// Serializes this SubscriptionModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SubscriptionModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SubscriptionModelCopyWith<SubscriptionModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SubscriptionModelCopyWith<$Res> {
  factory $SubscriptionModelCopyWith(
          SubscriptionModel value, $Res Function(SubscriptionModel) then) =
      _$SubscriptionModelCopyWithImpl<$Res, SubscriptionModel>;
  @useResult
  $Res call(
      {@JsonKey(name: 'subscribe_url') String? subscribeUrl,
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
      @JsonKey(name: 'reset_day', fromJson: _parseResetDay) int? resetDay});

  $SubscriptionPlanModelCopyWith<$Res>? get plan;
}

/// @nodoc
class _$SubscriptionModelCopyWithImpl<$Res, $Val extends SubscriptionModel>
    implements $SubscriptionModelCopyWith<$Res> {
  _$SubscriptionModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SubscriptionModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? subscribeUrl = freezed,
    Object? plan = freezed,
    Object? token = freezed,
    Object? expiredAt = freezed,
    Object? u = freezed,
    Object? d = freezed,
    Object? transferEnable = freezed,
    Object? planId = freezed,
    Object? email = freezed,
    Object? uuid = freezed,
    Object? deviceLimit = freezed,
    Object? speedLimit = freezed,
    Object? nextResetAt = freezed,
    Object? resetDay = freezed,
  }) {
    return _then(_value.copyWith(
      subscribeUrl: freezed == subscribeUrl
          ? _value.subscribeUrl
          : subscribeUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      plan: freezed == plan
          ? _value.plan
          : plan // ignore: cast_nullable_to_non_nullable
              as SubscriptionPlanModel?,
      token: freezed == token
          ? _value.token
          : token // ignore: cast_nullable_to_non_nullable
              as String?,
      expiredAt: freezed == expiredAt
          ? _value.expiredAt
          : expiredAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      u: freezed == u
          ? _value.u
          : u // ignore: cast_nullable_to_non_nullable
              as int?,
      d: freezed == d
          ? _value.d
          : d // ignore: cast_nullable_to_non_nullable
              as int?,
      transferEnable: freezed == transferEnable
          ? _value.transferEnable
          : transferEnable // ignore: cast_nullable_to_non_nullable
              as int?,
      planId: freezed == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as int?,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      uuid: freezed == uuid
          ? _value.uuid
          : uuid // ignore: cast_nullable_to_non_nullable
              as String?,
      deviceLimit: freezed == deviceLimit
          ? _value.deviceLimit
          : deviceLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      speedLimit: freezed == speedLimit
          ? _value.speedLimit
          : speedLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      nextResetAt: freezed == nextResetAt
          ? _value.nextResetAt
          : nextResetAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      resetDay: freezed == resetDay
          ? _value.resetDay
          : resetDay // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }

  /// Create a copy of SubscriptionModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SubscriptionPlanModelCopyWith<$Res>? get plan {
    if (_value.plan == null) {
      return null;
    }

    return $SubscriptionPlanModelCopyWith<$Res>(_value.plan!, (value) {
      return _then(_value.copyWith(plan: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SubscriptionModelImplCopyWith<$Res>
    implements $SubscriptionModelCopyWith<$Res> {
  factory _$$SubscriptionModelImplCopyWith(_$SubscriptionModelImpl value,
          $Res Function(_$SubscriptionModelImpl) then) =
      __$$SubscriptionModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'subscribe_url') String? subscribeUrl,
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
      @JsonKey(name: 'reset_day', fromJson: _parseResetDay) int? resetDay});

  @override
  $SubscriptionPlanModelCopyWith<$Res>? get plan;
}

/// @nodoc
class __$$SubscriptionModelImplCopyWithImpl<$Res>
    extends _$SubscriptionModelCopyWithImpl<$Res, _$SubscriptionModelImpl>
    implements _$$SubscriptionModelImplCopyWith<$Res> {
  __$$SubscriptionModelImplCopyWithImpl(_$SubscriptionModelImpl _value,
      $Res Function(_$SubscriptionModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of SubscriptionModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? subscribeUrl = freezed,
    Object? plan = freezed,
    Object? token = freezed,
    Object? expiredAt = freezed,
    Object? u = freezed,
    Object? d = freezed,
    Object? transferEnable = freezed,
    Object? planId = freezed,
    Object? email = freezed,
    Object? uuid = freezed,
    Object? deviceLimit = freezed,
    Object? speedLimit = freezed,
    Object? nextResetAt = freezed,
    Object? resetDay = freezed,
  }) {
    return _then(_$SubscriptionModelImpl(
      subscribeUrl: freezed == subscribeUrl
          ? _value.subscribeUrl
          : subscribeUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      plan: freezed == plan
          ? _value.plan
          : plan // ignore: cast_nullable_to_non_nullable
              as SubscriptionPlanModel?,
      token: freezed == token
          ? _value.token
          : token // ignore: cast_nullable_to_non_nullable
              as String?,
      expiredAt: freezed == expiredAt
          ? _value.expiredAt
          : expiredAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      u: freezed == u
          ? _value.u
          : u // ignore: cast_nullable_to_non_nullable
              as int?,
      d: freezed == d
          ? _value.d
          : d // ignore: cast_nullable_to_non_nullable
              as int?,
      transferEnable: freezed == transferEnable
          ? _value.transferEnable
          : transferEnable // ignore: cast_nullable_to_non_nullable
              as int?,
      planId: freezed == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as int?,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      uuid: freezed == uuid
          ? _value.uuid
          : uuid // ignore: cast_nullable_to_non_nullable
              as String?,
      deviceLimit: freezed == deviceLimit
          ? _value.deviceLimit
          : deviceLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      speedLimit: freezed == speedLimit
          ? _value.speedLimit
          : speedLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      nextResetAt: freezed == nextResetAt
          ? _value.nextResetAt
          : nextResetAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      resetDay: freezed == resetDay
          ? _value.resetDay
          : resetDay // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SubscriptionModelImpl extends _SubscriptionModel {
  const _$SubscriptionModelImpl(
      {@JsonKey(name: 'subscribe_url') this.subscribeUrl,
      this.plan,
      this.token,
      @JsonKey(
          name: 'expired_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      this.expiredAt,
      @JsonKey(fromJson: _intFromJson, toJson: _intToJson) this.u,
      @JsonKey(fromJson: _intFromJson, toJson: _intToJson) this.d,
      @JsonKey(
          name: 'transfer_enable', fromJson: _intFromJson, toJson: _intToJson)
      this.transferEnable,
      @JsonKey(name: 'plan_id', fromJson: _intFromJson, toJson: _intToJson)
      this.planId,
      this.email,
      this.uuid,
      @JsonKey(name: 'device_limit', fromJson: _intFromJson, toJson: _intToJson)
      this.deviceLimit,
      @JsonKey(name: 'speed_limit', fromJson: _intFromJson, toJson: _intToJson)
      this.speedLimit,
      @JsonKey(
          name: 'next_reset_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      this.nextResetAt,
      @JsonKey(name: 'reset_day', fromJson: _parseResetDay) this.resetDay})
      : super._();

  factory _$SubscriptionModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$SubscriptionModelImplFromJson(json);

  @override
  @JsonKey(name: 'subscribe_url')
  final String? subscribeUrl;
  @override
  final SubscriptionPlanModel? plan;
  @override
  final String? token;
  @override
  @JsonKey(
      name: 'expired_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime? expiredAt;
  @override
  @JsonKey(fromJson: _intFromJson, toJson: _intToJson)
  final int? u;
  @override
  @JsonKey(fromJson: _intFromJson, toJson: _intToJson)
  final int? d;
  @override
  @JsonKey(name: 'transfer_enable', fromJson: _intFromJson, toJson: _intToJson)
  final int? transferEnable;
  @override
  @JsonKey(name: 'plan_id', fromJson: _intFromJson, toJson: _intToJson)
  final int? planId;
  @override
  final String? email;
  @override
  final String? uuid;
  @override
  @JsonKey(name: 'device_limit', fromJson: _intFromJson, toJson: _intToJson)
  final int? deviceLimit;
  @override
  @JsonKey(name: 'speed_limit', fromJson: _intFromJson, toJson: _intToJson)
  final int? speedLimit;
  @override
  @JsonKey(
      name: 'next_reset_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime? nextResetAt;
  @override
  @JsonKey(name: 'reset_day', fromJson: _parseResetDay)
  final int? resetDay;

  @override
  String toString() {
    return 'SubscriptionModel(subscribeUrl: $subscribeUrl, plan: $plan, token: $token, expiredAt: $expiredAt, u: $u, d: $d, transferEnable: $transferEnable, planId: $planId, email: $email, uuid: $uuid, deviceLimit: $deviceLimit, speedLimit: $speedLimit, nextResetAt: $nextResetAt, resetDay: $resetDay)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SubscriptionModelImpl &&
            (identical(other.subscribeUrl, subscribeUrl) ||
                other.subscribeUrl == subscribeUrl) &&
            (identical(other.plan, plan) || other.plan == plan) &&
            (identical(other.token, token) || other.token == token) &&
            (identical(other.expiredAt, expiredAt) ||
                other.expiredAt == expiredAt) &&
            (identical(other.u, u) || other.u == u) &&
            (identical(other.d, d) || other.d == d) &&
            (identical(other.transferEnable, transferEnable) ||
                other.transferEnable == transferEnable) &&
            (identical(other.planId, planId) || other.planId == planId) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.uuid, uuid) || other.uuid == uuid) &&
            (identical(other.deviceLimit, deviceLimit) ||
                other.deviceLimit == deviceLimit) &&
            (identical(other.speedLimit, speedLimit) ||
                other.speedLimit == speedLimit) &&
            (identical(other.nextResetAt, nextResetAt) ||
                other.nextResetAt == nextResetAt) &&
            (identical(other.resetDay, resetDay) ||
                other.resetDay == resetDay));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      subscribeUrl,
      plan,
      token,
      expiredAt,
      u,
      d,
      transferEnable,
      planId,
      email,
      uuid,
      deviceLimit,
      speedLimit,
      nextResetAt,
      resetDay);

  /// Create a copy of SubscriptionModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SubscriptionModelImplCopyWith<_$SubscriptionModelImpl> get copyWith =>
      __$$SubscriptionModelImplCopyWithImpl<_$SubscriptionModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SubscriptionModelImplToJson(
      this,
    );
  }
}

abstract class _SubscriptionModel extends SubscriptionModel {
  const factory _SubscriptionModel(
      {@JsonKey(name: 'subscribe_url') final String? subscribeUrl,
      final SubscriptionPlanModel? plan,
      final String? token,
      @JsonKey(
          name: 'expired_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      final DateTime? expiredAt,
      @JsonKey(fromJson: _intFromJson, toJson: _intToJson) final int? u,
      @JsonKey(fromJson: _intFromJson, toJson: _intToJson) final int? d,
      @JsonKey(
          name: 'transfer_enable', fromJson: _intFromJson, toJson: _intToJson)
      final int? transferEnable,
      @JsonKey(name: 'plan_id', fromJson: _intFromJson, toJson: _intToJson)
      final int? planId,
      final String? email,
      final String? uuid,
      @JsonKey(name: 'device_limit', fromJson: _intFromJson, toJson: _intToJson)
      final int? deviceLimit,
      @JsonKey(name: 'speed_limit', fromJson: _intFromJson, toJson: _intToJson)
      final int? speedLimit,
      @JsonKey(
          name: 'next_reset_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      final DateTime? nextResetAt,
      @JsonKey(name: 'reset_day', fromJson: _parseResetDay)
      final int? resetDay}) = _$SubscriptionModelImpl;
  const _SubscriptionModel._() : super._();

  factory _SubscriptionModel.fromJson(Map<String, dynamic> json) =
      _$SubscriptionModelImpl.fromJson;

  @override
  @JsonKey(name: 'subscribe_url')
  String? get subscribeUrl;
  @override
  SubscriptionPlanModel? get plan;
  @override
  String? get token;
  @override
  @JsonKey(
      name: 'expired_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get expiredAt;
  @override
  @JsonKey(fromJson: _intFromJson, toJson: _intToJson)
  int? get u;
  @override
  @JsonKey(fromJson: _intFromJson, toJson: _intToJson)
  int? get d;
  @override
  @JsonKey(name: 'transfer_enable', fromJson: _intFromJson, toJson: _intToJson)
  int? get transferEnable;
  @override
  @JsonKey(name: 'plan_id', fromJson: _intFromJson, toJson: _intToJson)
  int? get planId;
  @override
  String? get email;
  @override
  String? get uuid;
  @override
  @JsonKey(name: 'device_limit', fromJson: _intFromJson, toJson: _intToJson)
  int? get deviceLimit;
  @override
  @JsonKey(name: 'speed_limit', fromJson: _intFromJson, toJson: _intToJson)
  int? get speedLimit;
  @override
  @JsonKey(
      name: 'next_reset_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get nextResetAt;
  @override
  @JsonKey(name: 'reset_day', fromJson: _parseResetDay)
  int? get resetDay;

  /// Create a copy of SubscriptionModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SubscriptionModelImplCopyWith<_$SubscriptionModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SubscriptionPlanModel _$SubscriptionPlanModelFromJson(
    Map<String, dynamic> json) {
  return _SubscriptionPlanModel.fromJson(json);
}

/// @nodoc
mixin _$SubscriptionPlanModel {
  String? get name => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _intFromJson, toJson: _intToJson)
  int? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'group_id', fromJson: _intFromJson, toJson: _intToJson)
  int? get groupId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _priceFromJson, toJson: _priceToJson)
  double? get price => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get content => throw _privateConstructorUsedError;
  List<String>? get tags => throw _privateConstructorUsedError;
  @JsonKey(name: 'transfer_enable', fromJson: _intFromJson, toJson: _intToJson)
  int? get transferEnable => throw _privateConstructorUsedError;
  @JsonKey(name: 'speed_limit', fromJson: _intFromJson, toJson: _intToJson)
  int? get speedLimit => throw _privateConstructorUsedError;
  @JsonKey(name: 'device_limit', fromJson: _intFromJson, toJson: _intToJson)
  int? get deviceLimit => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool? get show => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool? get sell => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool? get renew => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _intFromJson, toJson: _intToJson)
  int? get sort => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'onetime_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get onetimePrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'month_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get monthPrice => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'quarter_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get quarterPrice => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'half_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get halfYearPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get yearPrice => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'two_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get twoYearPrice => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'three_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get threeYearPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'reset_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get resetPrice => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'reset_traffic_method', fromJson: _intFromJson, toJson: _intToJson)
  int? get resetTrafficMethod => throw _privateConstructorUsedError;

  /// Serializes this SubscriptionPlanModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SubscriptionPlanModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SubscriptionPlanModelCopyWith<SubscriptionPlanModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SubscriptionPlanModelCopyWith<$Res> {
  factory $SubscriptionPlanModelCopyWith(SubscriptionPlanModel value,
          $Res Function(SubscriptionPlanModel) then) =
      _$SubscriptionPlanModelCopyWithImpl<$Res, SubscriptionPlanModel>;
  @useResult
  $Res call(
      {String? name,
      @JsonKey(fromJson: _intFromJson, toJson: _intToJson) int? id,
      @JsonKey(name: 'group_id', fromJson: _intFromJson, toJson: _intToJson)
      int? groupId,
      @JsonKey(fromJson: _priceFromJson, toJson: _priceToJson) double? price,
      String? description,
      String? content,
      List<String>? tags,
      @JsonKey(name: 'transfer_enable', fromJson: _intFromJson, toJson: _intToJson)
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
          name: 'half_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      double? halfYearPrice,
      @JsonKey(name: 'year_price', fromJson: _priceFromJson, toJson: _priceToJson)
      double? yearPrice,
      @JsonKey(
          name: 'two_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
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
      int? resetTrafficMethod});
}

/// @nodoc
class _$SubscriptionPlanModelCopyWithImpl<$Res,
        $Val extends SubscriptionPlanModel>
    implements $SubscriptionPlanModelCopyWith<$Res> {
  _$SubscriptionPlanModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SubscriptionPlanModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = freezed,
    Object? id = freezed,
    Object? groupId = freezed,
    Object? price = freezed,
    Object? description = freezed,
    Object? content = freezed,
    Object? tags = freezed,
    Object? transferEnable = freezed,
    Object? speedLimit = freezed,
    Object? deviceLimit = freezed,
    Object? show = freezed,
    Object? sell = freezed,
    Object? renew = freezed,
    Object? sort = freezed,
    Object? onetimePrice = freezed,
    Object? monthPrice = freezed,
    Object? quarterPrice = freezed,
    Object? halfYearPrice = freezed,
    Object? yearPrice = freezed,
    Object? twoYearPrice = freezed,
    Object? threeYearPrice = freezed,
    Object? resetPrice = freezed,
    Object? resetTrafficMethod = freezed,
  }) {
    return _then(_value.copyWith(
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      groupId: freezed == groupId
          ? _value.groupId
          : groupId // ignore: cast_nullable_to_non_nullable
              as int?,
      price: freezed == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: freezed == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      transferEnable: freezed == transferEnable
          ? _value.transferEnable
          : transferEnable // ignore: cast_nullable_to_non_nullable
              as int?,
      speedLimit: freezed == speedLimit
          ? _value.speedLimit
          : speedLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      deviceLimit: freezed == deviceLimit
          ? _value.deviceLimit
          : deviceLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      show: freezed == show
          ? _value.show
          : show // ignore: cast_nullable_to_non_nullable
              as bool?,
      sell: freezed == sell
          ? _value.sell
          : sell // ignore: cast_nullable_to_non_nullable
              as bool?,
      renew: freezed == renew
          ? _value.renew
          : renew // ignore: cast_nullable_to_non_nullable
              as bool?,
      sort: freezed == sort
          ? _value.sort
          : sort // ignore: cast_nullable_to_non_nullable
              as int?,
      onetimePrice: freezed == onetimePrice
          ? _value.onetimePrice
          : onetimePrice // ignore: cast_nullable_to_non_nullable
              as double?,
      monthPrice: freezed == monthPrice
          ? _value.monthPrice
          : monthPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      quarterPrice: freezed == quarterPrice
          ? _value.quarterPrice
          : quarterPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      halfYearPrice: freezed == halfYearPrice
          ? _value.halfYearPrice
          : halfYearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      yearPrice: freezed == yearPrice
          ? _value.yearPrice
          : yearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      twoYearPrice: freezed == twoYearPrice
          ? _value.twoYearPrice
          : twoYearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      threeYearPrice: freezed == threeYearPrice
          ? _value.threeYearPrice
          : threeYearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      resetPrice: freezed == resetPrice
          ? _value.resetPrice
          : resetPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      resetTrafficMethod: freezed == resetTrafficMethod
          ? _value.resetTrafficMethod
          : resetTrafficMethod // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SubscriptionPlanModelImplCopyWith<$Res>
    implements $SubscriptionPlanModelCopyWith<$Res> {
  factory _$$SubscriptionPlanModelImplCopyWith(
          _$SubscriptionPlanModelImpl value,
          $Res Function(_$SubscriptionPlanModelImpl) then) =
      __$$SubscriptionPlanModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? name,
      @JsonKey(fromJson: _intFromJson, toJson: _intToJson) int? id,
      @JsonKey(name: 'group_id', fromJson: _intFromJson, toJson: _intToJson)
      int? groupId,
      @JsonKey(fromJson: _priceFromJson, toJson: _priceToJson) double? price,
      String? description,
      String? content,
      List<String>? tags,
      @JsonKey(name: 'transfer_enable', fromJson: _intFromJson, toJson: _intToJson)
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
          name: 'half_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      double? halfYearPrice,
      @JsonKey(name: 'year_price', fromJson: _priceFromJson, toJson: _priceToJson)
      double? yearPrice,
      @JsonKey(
          name: 'two_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
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
      int? resetTrafficMethod});
}

/// @nodoc
class __$$SubscriptionPlanModelImplCopyWithImpl<$Res>
    extends _$SubscriptionPlanModelCopyWithImpl<$Res,
        _$SubscriptionPlanModelImpl>
    implements _$$SubscriptionPlanModelImplCopyWith<$Res> {
  __$$SubscriptionPlanModelImplCopyWithImpl(_$SubscriptionPlanModelImpl _value,
      $Res Function(_$SubscriptionPlanModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of SubscriptionPlanModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = freezed,
    Object? id = freezed,
    Object? groupId = freezed,
    Object? price = freezed,
    Object? description = freezed,
    Object? content = freezed,
    Object? tags = freezed,
    Object? transferEnable = freezed,
    Object? speedLimit = freezed,
    Object? deviceLimit = freezed,
    Object? show = freezed,
    Object? sell = freezed,
    Object? renew = freezed,
    Object? sort = freezed,
    Object? onetimePrice = freezed,
    Object? monthPrice = freezed,
    Object? quarterPrice = freezed,
    Object? halfYearPrice = freezed,
    Object? yearPrice = freezed,
    Object? twoYearPrice = freezed,
    Object? threeYearPrice = freezed,
    Object? resetPrice = freezed,
    Object? resetTrafficMethod = freezed,
  }) {
    return _then(_$SubscriptionPlanModelImpl(
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      groupId: freezed == groupId
          ? _value.groupId
          : groupId // ignore: cast_nullable_to_non_nullable
              as int?,
      price: freezed == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: freezed == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      transferEnable: freezed == transferEnable
          ? _value.transferEnable
          : transferEnable // ignore: cast_nullable_to_non_nullable
              as int?,
      speedLimit: freezed == speedLimit
          ? _value.speedLimit
          : speedLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      deviceLimit: freezed == deviceLimit
          ? _value.deviceLimit
          : deviceLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      show: freezed == show
          ? _value.show
          : show // ignore: cast_nullable_to_non_nullable
              as bool?,
      sell: freezed == sell
          ? _value.sell
          : sell // ignore: cast_nullable_to_non_nullable
              as bool?,
      renew: freezed == renew
          ? _value.renew
          : renew // ignore: cast_nullable_to_non_nullable
              as bool?,
      sort: freezed == sort
          ? _value.sort
          : sort // ignore: cast_nullable_to_non_nullable
              as int?,
      onetimePrice: freezed == onetimePrice
          ? _value.onetimePrice
          : onetimePrice // ignore: cast_nullable_to_non_nullable
              as double?,
      monthPrice: freezed == monthPrice
          ? _value.monthPrice
          : monthPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      quarterPrice: freezed == quarterPrice
          ? _value.quarterPrice
          : quarterPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      halfYearPrice: freezed == halfYearPrice
          ? _value.halfYearPrice
          : halfYearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      yearPrice: freezed == yearPrice
          ? _value.yearPrice
          : yearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      twoYearPrice: freezed == twoYearPrice
          ? _value.twoYearPrice
          : twoYearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      threeYearPrice: freezed == threeYearPrice
          ? _value.threeYearPrice
          : threeYearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      resetPrice: freezed == resetPrice
          ? _value.resetPrice
          : resetPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      resetTrafficMethod: freezed == resetTrafficMethod
          ? _value.resetTrafficMethod
          : resetTrafficMethod // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SubscriptionPlanModelImpl implements _SubscriptionPlanModel {
  const _$SubscriptionPlanModelImpl(
      {this.name,
      @JsonKey(fromJson: _intFromJson, toJson: _intToJson) this.id,
      @JsonKey(name: 'group_id', fromJson: _intFromJson, toJson: _intToJson)
      this.groupId,
      @JsonKey(fromJson: _priceFromJson, toJson: _priceToJson) this.price,
      this.description,
      this.content,
      final List<String>? tags,
      @JsonKey(
          name: 'transfer_enable', fromJson: _intFromJson, toJson: _intToJson)
      this.transferEnable,
      @JsonKey(name: 'speed_limit', fromJson: _intFromJson, toJson: _intToJson)
      this.speedLimit,
      @JsonKey(name: 'device_limit', fromJson: _intFromJson, toJson: _intToJson)
      this.deviceLimit,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) this.show,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) this.sell,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) this.renew,
      @JsonKey(fromJson: _intFromJson, toJson: _intToJson) this.sort,
      @JsonKey(
          name: 'onetime_price', fromJson: _priceFromJson, toJson: _priceToJson)
      this.onetimePrice,
      @JsonKey(
          name: 'month_price', fromJson: _priceFromJson, toJson: _priceToJson)
      this.monthPrice,
      @JsonKey(
          name: 'quarter_price', fromJson: _priceFromJson, toJson: _priceToJson)
      this.quarterPrice,
      @JsonKey(
          name: 'half_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      this.halfYearPrice,
      @JsonKey(
          name: 'year_price', fromJson: _priceFromJson, toJson: _priceToJson)
      this.yearPrice,
      @JsonKey(
          name: 'two_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      this.twoYearPrice,
      @JsonKey(
          name: 'three_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      this.threeYearPrice,
      @JsonKey(
          name: 'reset_price', fromJson: _priceFromJson, toJson: _priceToJson)
      this.resetPrice,
      @JsonKey(
          name: 'reset_traffic_method',
          fromJson: _intFromJson,
          toJson: _intToJson)
      this.resetTrafficMethod})
      : _tags = tags;

  factory _$SubscriptionPlanModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$SubscriptionPlanModelImplFromJson(json);

  @override
  final String? name;
  @override
  @JsonKey(fromJson: _intFromJson, toJson: _intToJson)
  final int? id;
  @override
  @JsonKey(name: 'group_id', fromJson: _intFromJson, toJson: _intToJson)
  final int? groupId;
  @override
  @JsonKey(fromJson: _priceFromJson, toJson: _priceToJson)
  final double? price;
  @override
  final String? description;
  @override
  final String? content;
  final List<String>? _tags;
  @override
  List<String>? get tags {
    final value = _tags;
    if (value == null) return null;
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'transfer_enable', fromJson: _intFromJson, toJson: _intToJson)
  final int? transferEnable;
  @override
  @JsonKey(name: 'speed_limit', fromJson: _intFromJson, toJson: _intToJson)
  final int? speedLimit;
  @override
  @JsonKey(name: 'device_limit', fromJson: _intFromJson, toJson: _intToJson)
  final int? deviceLimit;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  final bool? show;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  final bool? sell;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  final bool? renew;
  @override
  @JsonKey(fromJson: _intFromJson, toJson: _intToJson)
  final int? sort;
  @override
  @JsonKey(
      name: 'onetime_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? onetimePrice;
  @override
  @JsonKey(name: 'month_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? monthPrice;
  @override
  @JsonKey(
      name: 'quarter_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? quarterPrice;
  @override
  @JsonKey(
      name: 'half_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? halfYearPrice;
  @override
  @JsonKey(name: 'year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? yearPrice;
  @override
  @JsonKey(
      name: 'two_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? twoYearPrice;
  @override
  @JsonKey(
      name: 'three_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? threeYearPrice;
  @override
  @JsonKey(name: 'reset_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? resetPrice;
  @override
  @JsonKey(
      name: 'reset_traffic_method', fromJson: _intFromJson, toJson: _intToJson)
  final int? resetTrafficMethod;

  @override
  String toString() {
    return 'SubscriptionPlanModel(name: $name, id: $id, groupId: $groupId, price: $price, description: $description, content: $content, tags: $tags, transferEnable: $transferEnable, speedLimit: $speedLimit, deviceLimit: $deviceLimit, show: $show, sell: $sell, renew: $renew, sort: $sort, onetimePrice: $onetimePrice, monthPrice: $monthPrice, quarterPrice: $quarterPrice, halfYearPrice: $halfYearPrice, yearPrice: $yearPrice, twoYearPrice: $twoYearPrice, threeYearPrice: $threeYearPrice, resetPrice: $resetPrice, resetTrafficMethod: $resetTrafficMethod)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SubscriptionPlanModelImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.content, content) || other.content == content) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.transferEnable, transferEnable) ||
                other.transferEnable == transferEnable) &&
            (identical(other.speedLimit, speedLimit) ||
                other.speedLimit == speedLimit) &&
            (identical(other.deviceLimit, deviceLimit) ||
                other.deviceLimit == deviceLimit) &&
            (identical(other.show, show) || other.show == show) &&
            (identical(other.sell, sell) || other.sell == sell) &&
            (identical(other.renew, renew) || other.renew == renew) &&
            (identical(other.sort, sort) || other.sort == sort) &&
            (identical(other.onetimePrice, onetimePrice) ||
                other.onetimePrice == onetimePrice) &&
            (identical(other.monthPrice, monthPrice) ||
                other.monthPrice == monthPrice) &&
            (identical(other.quarterPrice, quarterPrice) ||
                other.quarterPrice == quarterPrice) &&
            (identical(other.halfYearPrice, halfYearPrice) ||
                other.halfYearPrice == halfYearPrice) &&
            (identical(other.yearPrice, yearPrice) ||
                other.yearPrice == yearPrice) &&
            (identical(other.twoYearPrice, twoYearPrice) ||
                other.twoYearPrice == twoYearPrice) &&
            (identical(other.threeYearPrice, threeYearPrice) ||
                other.threeYearPrice == threeYearPrice) &&
            (identical(other.resetPrice, resetPrice) ||
                other.resetPrice == resetPrice) &&
            (identical(other.resetTrafficMethod, resetTrafficMethod) ||
                other.resetTrafficMethod == resetTrafficMethod));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        name,
        id,
        groupId,
        price,
        description,
        content,
        const DeepCollectionEquality().hash(_tags),
        transferEnable,
        speedLimit,
        deviceLimit,
        show,
        sell,
        renew,
        sort,
        onetimePrice,
        monthPrice,
        quarterPrice,
        halfYearPrice,
        yearPrice,
        twoYearPrice,
        threeYearPrice,
        resetPrice,
        resetTrafficMethod
      ]);

  /// Create a copy of SubscriptionPlanModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SubscriptionPlanModelImplCopyWith<_$SubscriptionPlanModelImpl>
      get copyWith => __$$SubscriptionPlanModelImplCopyWithImpl<
          _$SubscriptionPlanModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SubscriptionPlanModelImplToJson(
      this,
    );
  }
}

abstract class _SubscriptionPlanModel implements SubscriptionPlanModel {
  const factory _SubscriptionPlanModel(
      {final String? name,
      @JsonKey(fromJson: _intFromJson, toJson: _intToJson) final int? id,
      @JsonKey(name: 'group_id', fromJson: _intFromJson, toJson: _intToJson)
      final int? groupId,
      @JsonKey(fromJson: _priceFromJson, toJson: _priceToJson)
      final double? price,
      final String? description,
      final String? content,
      final List<String>? tags,
      @JsonKey(
          name: 'transfer_enable', fromJson: _intFromJson, toJson: _intToJson)
      final int? transferEnable,
      @JsonKey(name: 'speed_limit', fromJson: _intFromJson, toJson: _intToJson)
      final int? speedLimit,
      @JsonKey(name: 'device_limit', fromJson: _intFromJson, toJson: _intToJson)
      final int? deviceLimit,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) final bool? show,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) final bool? sell,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) final bool? renew,
      @JsonKey(fromJson: _intFromJson, toJson: _intToJson) final int? sort,
      @JsonKey(
          name: 'onetime_price', fromJson: _priceFromJson, toJson: _priceToJson)
      final double? onetimePrice,
      @JsonKey(
          name: 'month_price', fromJson: _priceFromJson, toJson: _priceToJson)
      final double? monthPrice,
      @JsonKey(
          name: 'quarter_price', fromJson: _priceFromJson, toJson: _priceToJson)
      final double? quarterPrice,
      @JsonKey(
          name: 'half_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      final double? halfYearPrice,
      @JsonKey(
          name: 'year_price', fromJson: _priceFromJson, toJson: _priceToJson)
      final double? yearPrice,
      @JsonKey(
          name: 'two_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      final double? twoYearPrice,
      @JsonKey(
          name: 'three_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      final double? threeYearPrice,
      @JsonKey(
          name: 'reset_price', fromJson: _priceFromJson, toJson: _priceToJson)
      final double? resetPrice,
      @JsonKey(
          name: 'reset_traffic_method',
          fromJson: _intFromJson,
          toJson: _intToJson)
      final int? resetTrafficMethod}) = _$SubscriptionPlanModelImpl;

  factory _SubscriptionPlanModel.fromJson(Map<String, dynamic> json) =
      _$SubscriptionPlanModelImpl.fromJson;

  @override
  String? get name;
  @override
  @JsonKey(fromJson: _intFromJson, toJson: _intToJson)
  int? get id;
  @override
  @JsonKey(name: 'group_id', fromJson: _intFromJson, toJson: _intToJson)
  int? get groupId;
  @override
  @JsonKey(fromJson: _priceFromJson, toJson: _priceToJson)
  double? get price;
  @override
  String? get description;
  @override
  String? get content;
  @override
  List<String>? get tags;
  @override
  @JsonKey(name: 'transfer_enable', fromJson: _intFromJson, toJson: _intToJson)
  int? get transferEnable;
  @override
  @JsonKey(name: 'speed_limit', fromJson: _intFromJson, toJson: _intToJson)
  int? get speedLimit;
  @override
  @JsonKey(name: 'device_limit', fromJson: _intFromJson, toJson: _intToJson)
  int? get deviceLimit;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool? get show;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool? get sell;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool? get renew;
  @override
  @JsonKey(fromJson: _intFromJson, toJson: _intToJson)
  int? get sort;
  @override
  @JsonKey(
      name: 'onetime_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get onetimePrice;
  @override
  @JsonKey(name: 'month_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get monthPrice;
  @override
  @JsonKey(
      name: 'quarter_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get quarterPrice;
  @override
  @JsonKey(
      name: 'half_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get halfYearPrice;
  @override
  @JsonKey(name: 'year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get yearPrice;
  @override
  @JsonKey(
      name: 'two_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get twoYearPrice;
  @override
  @JsonKey(
      name: 'three_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get threeYearPrice;
  @override
  @JsonKey(name: 'reset_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get resetPrice;
  @override
  @JsonKey(
      name: 'reset_traffic_method', fromJson: _intFromJson, toJson: _intToJson)
  int? get resetTrafficMethod;

  /// Create a copy of SubscriptionPlanModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SubscriptionPlanModelImplCopyWith<_$SubscriptionPlanModelImpl>
      get copyWith => throw _privateConstructorUsedError;
}
