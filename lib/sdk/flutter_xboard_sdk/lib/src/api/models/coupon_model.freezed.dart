// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'coupon_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CouponModel _$CouponModelFromJson(Map<String, dynamic> json) {
  return _CouponModel.fromJson(json);
}

/// @nodoc
mixin _$CouponModel {
  int? get id => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  String? get code => throw _privateConstructorUsedError;
  int? get type => throw _privateConstructorUsedError; // 1: 金额折扣, 2: 百分比折扣
  int? get value => throw _privateConstructorUsedError;
  @JsonKey(name: 'limit_use')
  int? get limitUse => throw _privateConstructorUsedError;
  @JsonKey(name: 'limit_use_with_user')
  int? get limitUseWithUser => throw _privateConstructorUsedError;
  @JsonKey(name: 'limit_plan_ids')
  List<String>? get limitPlanIds => throw _privateConstructorUsedError;
  dynamic get limitPeriod => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'started_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get startedAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'ended_at', fromJson: _fromUnixTimestamp, toJson: _toUnixTimestamp)
  DateTime? get endedAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool? get show => throw _privateConstructorUsedError;
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

  /// Serializes this CouponModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CouponModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CouponModelCopyWith<CouponModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CouponModelCopyWith<$Res> {
  factory $CouponModelCopyWith(
          CouponModel value, $Res Function(CouponModel) then) =
      _$CouponModelCopyWithImpl<$Res, CouponModel>;
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
class _$CouponModelCopyWithImpl<$Res, $Val extends CouponModel>
    implements $CouponModelCopyWith<$Res> {
  _$CouponModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CouponModel
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
abstract class _$$CouponModelImplCopyWith<$Res>
    implements $CouponModelCopyWith<$Res> {
  factory _$$CouponModelImplCopyWith(
          _$CouponModelImpl value, $Res Function(_$CouponModelImpl) then) =
      __$$CouponModelImplCopyWithImpl<$Res>;
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
class __$$CouponModelImplCopyWithImpl<$Res>
    extends _$CouponModelCopyWithImpl<$Res, _$CouponModelImpl>
    implements _$$CouponModelImplCopyWith<$Res> {
  __$$CouponModelImplCopyWithImpl(
      _$CouponModelImpl _value, $Res Function(_$CouponModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of CouponModel
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
    return _then(_$CouponModelImpl(
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
class _$CouponModelImpl implements _CouponModel {
  const _$CouponModelImpl(
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

  factory _$CouponModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$CouponModelImplFromJson(json);

  @override
  final int? id;
  @override
  final String? name;
  @override
  final String? code;
  @override
  final int? type;
// 1: 金额折扣, 2: 百分比折扣
  @override
  final int? value;
  @override
  @JsonKey(name: 'limit_use')
  final int? limitUse;
  @override
  @JsonKey(name: 'limit_use_with_user')
  final int? limitUseWithUser;
  final List<String>? _limitPlanIds;
  @override
  @JsonKey(name: 'limit_plan_ids')
  List<String>? get limitPlanIds {
    final value = _limitPlanIds;
    if (value == null) return null;
    if (_limitPlanIds is EqualUnmodifiableListView) return _limitPlanIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final dynamic limitPeriod;
  @override
  @JsonKey(
      name: 'started_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime? startedAt;
  @override
  @JsonKey(
      name: 'ended_at', fromJson: _fromUnixTimestamp, toJson: _toUnixTimestamp)
  final DateTime? endedAt;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  final bool? show;
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
    return 'CouponModel(id: $id, name: $name, code: $code, type: $type, value: $value, limitUse: $limitUse, limitUseWithUser: $limitUseWithUser, limitPlanIds: $limitPlanIds, limitPeriod: $limitPeriod, startedAt: $startedAt, endedAt: $endedAt, show: $show, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CouponModelImpl &&
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

  /// Create a copy of CouponModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CouponModelImplCopyWith<_$CouponModelImpl> get copyWith =>
      __$$CouponModelImplCopyWithImpl<_$CouponModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CouponModelImplToJson(
      this,
    );
  }
}

abstract class _CouponModel implements CouponModel {
  const factory _CouponModel(
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
      final DateTime? updatedAt}) = _$CouponModelImpl;

  factory _CouponModel.fromJson(Map<String, dynamic> json) =
      _$CouponModelImpl.fromJson;

  @override
  int? get id;
  @override
  String? get name;
  @override
  String? get code;
  @override
  int? get type; // 1: 金额折扣, 2: 百分比折扣
  @override
  int? get value;
  @override
  @JsonKey(name: 'limit_use')
  int? get limitUse;
  @override
  @JsonKey(name: 'limit_use_with_user')
  int? get limitUseWithUser;
  @override
  @JsonKey(name: 'limit_plan_ids')
  List<String>? get limitPlanIds;
  @override
  dynamic get limitPeriod;
  @override
  @JsonKey(
      name: 'started_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get startedAt;
  @override
  @JsonKey(
      name: 'ended_at', fromJson: _fromUnixTimestamp, toJson: _toUnixTimestamp)
  DateTime? get endedAt;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool? get show;
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

  /// Create a copy of CouponModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CouponModelImplCopyWith<_$CouponModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
