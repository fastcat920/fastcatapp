// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'xboard_coupon_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CouponData _$CouponDataFromJson(Map<String, dynamic> json) {
  return _CouponData.fromJson(json);
}

/// @nodoc
mixin _$CouponData {
  int? get id =>
      throw _privateConstructorUsedError; // Changed from String? to int?
  String? get name => throw _privateConstructorUsedError;
  String? get code => throw _privateConstructorUsedError;
  int? get type => throw _privateConstructorUsedError; // 1: 金额折扣, 2: 百分比折扣
  int? get value =>
      throw _privateConstructorUsedError; // Changed from double? to int?
  @JsonKey(name: 'limit_use')
  int? get limitUse => throw _privateConstructorUsedError; // 使用限制次数
  @JsonKey(name: 'limit_use_with_user')
  int? get limitUseWithUser => throw _privateConstructorUsedError; // 单用户使用限制
  @JsonKey(name: 'limit_plan_ids')
  List<String>? get limitPlanIds =>
      throw _privateConstructorUsedError; // 限制的套餐ID列表
  dynamic get limitPeriod =>
      throw _privateConstructorUsedError; // Added limit_period
  @JsonKey(
      name: 'started_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get startedAt => throw _privateConstructorUsedError; // 开始时间
  @JsonKey(
      name: 'ended_at', fromJson: _fromUnixTimestamp, toJson: _toUnixTimestamp)
  DateTime? get endedAt => throw _privateConstructorUsedError; // 结束时间
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool? get show => throw _privateConstructorUsedError; // 是否显示
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this CouponData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CouponData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CouponDataCopyWith<CouponData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CouponDataCopyWith<$Res> {
  factory $CouponDataCopyWith(
          CouponData value, $Res Function(CouponData) then) =
      _$CouponDataCopyWithImpl<$Res, CouponData>;
  @useResult
  $Res call(
      {int? id,
      String? name,
      String? code,
      int? type,
      int? value,
      @JsonKey(name: 'limit_use') int? limitUse,
      @JsonKey(name: 'limit_use_with_user') int? limitUseWithUser,
      @JsonKey(name: 'limit_plan_ids') List<String>? limitPlanIds,
      dynamic limitPeriod,
      @JsonKey(
          name: 'started_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime? startedAt,
      @JsonKey(
          name: 'ended_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime? endedAt,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) bool? show,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime? createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime? updatedAt});
}

/// @nodoc
class _$CouponDataCopyWithImpl<$Res, $Val extends CouponData>
    implements $CouponDataCopyWith<$Res> {
  _$CouponDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CouponData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = freezed,
    Object? code = freezed,
    Object? type = freezed,
    Object? value = freezed,
    Object? limitUse = freezed,
    Object? limitUseWithUser = freezed,
    Object? limitPlanIds = freezed,
    Object? limitPeriod = freezed,
    Object? startedAt = freezed,
    Object? endedAt = freezed,
    Object? show = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      code: freezed == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String?,
      type: freezed == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as int?,
      value: freezed == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as int?,
      limitUse: freezed == limitUse
          ? _value.limitUse
          : limitUse // ignore: cast_nullable_to_non_nullable
              as int?,
      limitUseWithUser: freezed == limitUseWithUser
          ? _value.limitUseWithUser
          : limitUseWithUser // ignore: cast_nullable_to_non_nullable
              as int?,
      limitPlanIds: freezed == limitPlanIds
          ? _value.limitPlanIds
          : limitPlanIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      limitPeriod: freezed == limitPeriod
          ? _value.limitPeriod
          : limitPeriod // ignore: cast_nullable_to_non_nullable
              as dynamic,
      startedAt: freezed == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endedAt: freezed == endedAt
          ? _value.endedAt
          : endedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      show: freezed == show
          ? _value.show
          : show // ignore: cast_nullable_to_non_nullable
              as bool?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CouponDataImplCopyWith<$Res>
    implements $CouponDataCopyWith<$Res> {
  factory _$$CouponDataImplCopyWith(
          _$CouponDataImpl value, $Res Function(_$CouponDataImpl) then) =
      __$$CouponDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int? id,
      String? name,
      String? code,
      int? type,
      int? value,
      @JsonKey(name: 'limit_use') int? limitUse,
      @JsonKey(name: 'limit_use_with_user') int? limitUseWithUser,
      @JsonKey(name: 'limit_plan_ids') List<String>? limitPlanIds,
      dynamic limitPeriod,
      @JsonKey(
          name: 'started_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime? startedAt,
      @JsonKey(
          name: 'ended_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime? endedAt,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) bool? show,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime? createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime? updatedAt});
}

/// @nodoc
class __$$CouponDataImplCopyWithImpl<$Res>
    extends _$CouponDataCopyWithImpl<$Res, _$CouponDataImpl>
    implements _$$CouponDataImplCopyWith<$Res> {
  __$$CouponDataImplCopyWithImpl(
      _$CouponDataImpl _value, $Res Function(_$CouponDataImpl) _then)
      : super(_value, _then);

  /// Create a copy of CouponData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = freezed,
    Object? code = freezed,
    Object? type = freezed,
    Object? value = freezed,
    Object? limitUse = freezed,
    Object? limitUseWithUser = freezed,
    Object? limitPlanIds = freezed,
    Object? limitPeriod = freezed,
    Object? startedAt = freezed,
    Object? endedAt = freezed,
    Object? show = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$CouponDataImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      code: freezed == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String?,
      type: freezed == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as int?,
      value: freezed == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as int?,
      limitUse: freezed == limitUse
          ? _value.limitUse
          : limitUse // ignore: cast_nullable_to_non_nullable
              as int?,
      limitUseWithUser: freezed == limitUseWithUser
          ? _value.limitUseWithUser
          : limitUseWithUser // ignore: cast_nullable_to_non_nullable
              as int?,
      limitPlanIds: freezed == limitPlanIds
          ? _value._limitPlanIds
          : limitPlanIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      limitPeriod: freezed == limitPeriod
          ? _value.limitPeriod
          : limitPeriod // ignore: cast_nullable_to_non_nullable
              as dynamic,
      startedAt: freezed == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endedAt: freezed == endedAt
          ? _value.endedAt
          : endedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      show: freezed == show
          ? _value.show
          : show // ignore: cast_nullable_to_non_nullable
              as bool?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CouponDataImpl implements _CouponData {
  const _$CouponDataImpl(
      {this.id,
      this.name,
      this.code,
      this.type,
      this.value,
      @JsonKey(name: 'limit_use') this.limitUse,
      @JsonKey(name: 'limit_use_with_user') this.limitUseWithUser,
      @JsonKey(name: 'limit_plan_ids') final List<String>? limitPlanIds,
      this.limitPeriod,
      @JsonKey(
          name: 'started_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      this.startedAt,
      @JsonKey(
          name: 'ended_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      this.endedAt,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) this.show,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      this.createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      this.updatedAt})
      : _limitPlanIds = limitPlanIds;

  factory _$CouponDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$CouponDataImplFromJson(json);

  @override
  final int? id;
// Changed from String? to int?
  @override
  final String? name;
  @override
  final String? code;
  @override
  final int? type;
// 1: 金额折扣, 2: 百分比折扣
  @override
  final int? value;
// Changed from double? to int?
  @override
  @JsonKey(name: 'limit_use')
  final int? limitUse;
// 使用限制次数
  @override
  @JsonKey(name: 'limit_use_with_user')
  final int? limitUseWithUser;
// 单用户使用限制
  final List<String>? _limitPlanIds;
// 单用户使用限制
  @override
  @JsonKey(name: 'limit_plan_ids')
  List<String>? get limitPlanIds {
    final value = _limitPlanIds;
    if (value == null) return null;
    if (_limitPlanIds is EqualUnmodifiableListView) return _limitPlanIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// 限制的套餐ID列表
  @override
  final dynamic limitPeriod;
// Added limit_period
  @override
  @JsonKey(
      name: 'started_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime? startedAt;
// 开始时间
  @override
  @JsonKey(
      name: 'ended_at', fromJson: _fromUnixTimestamp, toJson: _toUnixTimestamp)
  final DateTime? endedAt;
// 结束时间
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  final bool? show;
// 是否显示
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime? createdAt;
  @override
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'CouponData(id: $id, name: $name, code: $code, type: $type, value: $value, limitUse: $limitUse, limitUseWithUser: $limitUseWithUser, limitPlanIds: $limitPlanIds, limitPeriod: $limitPeriod, startedAt: $startedAt, endedAt: $endedAt, show: $show, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CouponDataImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.limitUse, limitUse) ||
                other.limitUse == limitUse) &&
            (identical(other.limitUseWithUser, limitUseWithUser) ||
                other.limitUseWithUser == limitUseWithUser) &&
            const DeepCollectionEquality()
                .equals(other._limitPlanIds, _limitPlanIds) &&
            const DeepCollectionEquality()
                .equals(other.limitPeriod, limitPeriod) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.endedAt, endedAt) || other.endedAt == endedAt) &&
            (identical(other.show, show) || other.show == show) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      code,
      type,
      value,
      limitUse,
      limitUseWithUser,
      const DeepCollectionEquality().hash(_limitPlanIds),
      const DeepCollectionEquality().hash(limitPeriod),
      startedAt,
      endedAt,
      show,
      createdAt,
      updatedAt);

  /// Create a copy of CouponData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CouponDataImplCopyWith<_$CouponDataImpl> get copyWith =>
      __$$CouponDataImplCopyWithImpl<_$CouponDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CouponDataImplToJson(
      this,
    );
  }
}

abstract class _CouponData implements CouponData {
  const factory _CouponData(
      {final int? id,
      final String? name,
      final String? code,
      final int? type,
      final int? value,
      @JsonKey(name: 'limit_use') final int? limitUse,
      @JsonKey(name: 'limit_use_with_user') final int? limitUseWithUser,
      @JsonKey(name: 'limit_plan_ids') final List<String>? limitPlanIds,
      final dynamic limitPeriod,
      @JsonKey(
          name: 'started_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      final DateTime? startedAt,
      @JsonKey(
          name: 'ended_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      final DateTime? endedAt,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) final bool? show,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      final DateTime? createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      final DateTime? updatedAt}) = _$CouponDataImpl;

  factory _CouponData.fromJson(Map<String, dynamic> json) =
      _$CouponDataImpl.fromJson;

  @override
  int? get id; // Changed from String? to int?
  @override
  String? get name;
  @override
  String? get code;
  @override
  int? get type; // 1: 金额折扣, 2: 百分比折扣
  @override
  int? get value; // Changed from double? to int?
  @override
  @JsonKey(name: 'limit_use')
  int? get limitUse; // 使用限制次数
  @override
  @JsonKey(name: 'limit_use_with_user')
  int? get limitUseWithUser; // 单用户使用限制
  @override
  @JsonKey(name: 'limit_plan_ids')
  List<String>? get limitPlanIds; // 限制的套餐ID列表
  @override
  dynamic get limitPeriod; // Added limit_period
  @override
  @JsonKey(
      name: 'started_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get startedAt; // 开始时间
  @override
  @JsonKey(
      name: 'ended_at', fromJson: _fromUnixTimestamp, toJson: _toUnixTimestamp)
  DateTime? get endedAt; // 结束时间
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool? get show; // 是否显示
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get createdAt;
  @override
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get updatedAt;

  /// Create a copy of CouponData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CouponDataImplCopyWith<_$CouponDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CouponResponse _$CouponResponseFromJson(Map<String, dynamic> json) {
  return _CouponResponse.fromJson(json);
}

/// @nodoc
mixin _$CouponResponse {
  bool get success => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;
  CouponData? get data => throw _privateConstructorUsedError;
  Map<String, dynamic>? get errors => throw _privateConstructorUsedError;

  /// Serializes this CouponResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CouponResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CouponResponseCopyWith<CouponResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CouponResponseCopyWith<$Res> {
  factory $CouponResponseCopyWith(
          CouponResponse value, $Res Function(CouponResponse) then) =
      _$CouponResponseCopyWithImpl<$Res, CouponResponse>;
  @useResult
  $Res call(
      {bool success,
      String? message,
      CouponData? data,
      Map<String, dynamic>? errors});

  $CouponDataCopyWith<$Res>? get data;
}

/// @nodoc
class _$CouponResponseCopyWithImpl<$Res, $Val extends CouponResponse>
    implements $CouponResponseCopyWith<$Res> {
  _$CouponResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CouponResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? message = freezed,
    Object? data = freezed,
    Object? errors = freezed,
  }) {
    return _then(_value.copyWith(
      success: null == success
          ? _value.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      data: freezed == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as CouponData?,
      errors: freezed == errors
          ? _value.errors
          : errors // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }

  /// Create a copy of CouponResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CouponDataCopyWith<$Res>? get data {
    if (_value.data == null) {
      return null;
    }

    return $CouponDataCopyWith<$Res>(_value.data!, (value) {
      return _then(_value.copyWith(data: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CouponResponseImplCopyWith<$Res>
    implements $CouponResponseCopyWith<$Res> {
  factory _$$CouponResponseImplCopyWith(_$CouponResponseImpl value,
          $Res Function(_$CouponResponseImpl) then) =
      __$$CouponResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool success,
      String? message,
      CouponData? data,
      Map<String, dynamic>? errors});

  @override
  $CouponDataCopyWith<$Res>? get data;
}

/// @nodoc
class __$$CouponResponseImplCopyWithImpl<$Res>
    extends _$CouponResponseCopyWithImpl<$Res, _$CouponResponseImpl>
    implements _$$CouponResponseImplCopyWith<$Res> {
  __$$CouponResponseImplCopyWithImpl(
      _$CouponResponseImpl _value, $Res Function(_$CouponResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of CouponResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? message = freezed,
    Object? data = freezed,
    Object? errors = freezed,
  }) {
    return _then(_$CouponResponseImpl(
      success: null == success
          ? _value.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      data: freezed == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as CouponData?,
      errors: freezed == errors
          ? _value._errors
          : errors // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CouponResponseImpl implements _CouponResponse {
  const _$CouponResponseImpl(
      {required this.success,
      this.message,
      this.data,
      final Map<String, dynamic>? errors})
      : _errors = errors;

  factory _$CouponResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$CouponResponseImplFromJson(json);

  @override
  final bool success;
  @override
  final String? message;
  @override
  final CouponData? data;
  final Map<String, dynamic>? _errors;
  @override
  Map<String, dynamic>? get errors {
    final value = _errors;
    if (value == null) return null;
    if (_errors is EqualUnmodifiableMapView) return _errors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'CouponResponse(success: $success, message: $message, data: $data, errors: $errors)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CouponResponseImpl &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.data, data) || other.data == data) &&
            const DeepCollectionEquality().equals(other._errors, _errors));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, success, message, data,
      const DeepCollectionEquality().hash(_errors));

  /// Create a copy of CouponResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CouponResponseImplCopyWith<_$CouponResponseImpl> get copyWith =>
      __$$CouponResponseImplCopyWithImpl<_$CouponResponseImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CouponResponseImplToJson(
      this,
    );
  }
}

abstract class _CouponResponse implements CouponResponse {
  const factory _CouponResponse(
      {required final bool success,
      final String? message,
      final CouponData? data,
      final Map<String, dynamic>? errors}) = _$CouponResponseImpl;

  factory _CouponResponse.fromJson(Map<String, dynamic> json) =
      _$CouponResponseImpl.fromJson;

  @override
  bool get success;
  @override
  String? get message;
  @override
  CouponData? get data;
  @override
  Map<String, dynamic>? get errors;

  /// Create a copy of CouponResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CouponResponseImplCopyWith<_$CouponResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
