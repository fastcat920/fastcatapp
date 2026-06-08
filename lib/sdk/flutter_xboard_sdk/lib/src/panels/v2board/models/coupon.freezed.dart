// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'coupon.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Coupon _$CouponFromJson(Map<String, dynamic> json) {
  return _Coupon.fromJson(json);
}

/// @nodoc
mixin _$Coupon {
  int? get id => throw _privateConstructorUsedError;
  String? get code => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  int? get type => throw _privateConstructorUsedError;
  int? get value => throw _privateConstructorUsedError;
  @JsonKey(name: 'limit_use')
  int? get limitUse => throw _privateConstructorUsedError;
  @JsonKey(name: 'limit_use_with_user')
  int? get limitUseWithUser => throw _privateConstructorUsedError;
  @JsonKey(name: 'limit_plan_ids')
  List<int>? get limitPlanIds => throw _privateConstructorUsedError;
  @JsonKey(name: 'started_at')
  int? get startedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'ended_at')
  int? get endedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  int? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  int? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Coupon to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Coupon
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CouponCopyWith<Coupon> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CouponCopyWith<$Res> {
  factory $CouponCopyWith(Coupon value, $Res Function(Coupon) then) =
      _$CouponCopyWithImpl<$Res, Coupon>;
  @useResult
  $Res call(
      {int? id,
      String? code,
      String? name,
      int? type,
      int? value,
      @JsonKey(name: 'limit_use') int? limitUse,
      @JsonKey(name: 'limit_use_with_user') int? limitUseWithUser,
      @JsonKey(name: 'limit_plan_ids') List<int>? limitPlanIds,
      @JsonKey(name: 'started_at') int? startedAt,
      @JsonKey(name: 'ended_at') int? endedAt,
      @JsonKey(name: 'created_at') int? createdAt,
      @JsonKey(name: 'updated_at') int? updatedAt});
}

/// @nodoc
class _$CouponCopyWithImpl<$Res, $Val extends Coupon>
    implements $CouponCopyWith<$Res> {
  _$CouponCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Coupon
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? code = freezed,
    Object? name = freezed,
    Object? type = freezed,
    Object? value = freezed,
    Object? limitUse = freezed,
    Object? limitUseWithUser = freezed,
    Object? limitPlanIds = freezed,
    Object? startedAt = freezed,
    Object? endedAt = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      code: freezed == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
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
              as List<int>?,
      startedAt: freezed == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as int?,
      endedAt: freezed == endedAt
          ? _value.endedAt
          : endedAt // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CouponImplCopyWith<$Res> implements $CouponCopyWith<$Res> {
  factory _$$CouponImplCopyWith(
          _$CouponImpl value, $Res Function(_$CouponImpl) then) =
      __$$CouponImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int? id,
      String? code,
      String? name,
      int? type,
      int? value,
      @JsonKey(name: 'limit_use') int? limitUse,
      @JsonKey(name: 'limit_use_with_user') int? limitUseWithUser,
      @JsonKey(name: 'limit_plan_ids') List<int>? limitPlanIds,
      @JsonKey(name: 'started_at') int? startedAt,
      @JsonKey(name: 'ended_at') int? endedAt,
      @JsonKey(name: 'created_at') int? createdAt,
      @JsonKey(name: 'updated_at') int? updatedAt});
}

/// @nodoc
class __$$CouponImplCopyWithImpl<$Res>
    extends _$CouponCopyWithImpl<$Res, _$CouponImpl>
    implements _$$CouponImplCopyWith<$Res> {
  __$$CouponImplCopyWithImpl(
      _$CouponImpl _value, $Res Function(_$CouponImpl) _then)
      : super(_value, _then);

  /// Create a copy of Coupon
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? code = freezed,
    Object? name = freezed,
    Object? type = freezed,
    Object? value = freezed,
    Object? limitUse = freezed,
    Object? limitUseWithUser = freezed,
    Object? limitPlanIds = freezed,
    Object? startedAt = freezed,
    Object? endedAt = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$CouponImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      code: freezed == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
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
              as List<int>?,
      startedAt: freezed == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as int?,
      endedAt: freezed == endedAt
          ? _value.endedAt
          : endedAt // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CouponImpl extends _Coupon {
  const _$CouponImpl(
      {this.id,
      this.code,
      this.name,
      this.type,
      this.value,
      @JsonKey(name: 'limit_use') this.limitUse,
      @JsonKey(name: 'limit_use_with_user') this.limitUseWithUser,
      @JsonKey(name: 'limit_plan_ids') final List<int>? limitPlanIds,
      @JsonKey(name: 'started_at') this.startedAt,
      @JsonKey(name: 'ended_at') this.endedAt,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt})
      : _limitPlanIds = limitPlanIds,
        super._();

  factory _$CouponImpl.fromJson(Map<String, dynamic> json) =>
      _$$CouponImplFromJson(json);

  @override
  final int? id;
  @override
  final String? code;
  @override
  final String? name;
  @override
  final int? type;
  @override
  final int? value;
  @override
  @JsonKey(name: 'limit_use')
  final int? limitUse;
  @override
  @JsonKey(name: 'limit_use_with_user')
  final int? limitUseWithUser;
  final List<int>? _limitPlanIds;
  @override
  @JsonKey(name: 'limit_plan_ids')
  List<int>? get limitPlanIds {
    final value = _limitPlanIds;
    if (value == null) return null;
    if (_limitPlanIds is EqualUnmodifiableListView) return _limitPlanIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'started_at')
  final int? startedAt;
  @override
  @JsonKey(name: 'ended_at')
  final int? endedAt;
  @override
  @JsonKey(name: 'created_at')
  final int? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final int? updatedAt;

  @override
  String toString() {
    return 'Coupon(id: $id, code: $code, name: $name, type: $type, value: $value, limitUse: $limitUse, limitUseWithUser: $limitUseWithUser, limitPlanIds: $limitPlanIds, startedAt: $startedAt, endedAt: $endedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CouponImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.limitUse, limitUse) ||
                other.limitUse == limitUse) &&
            (identical(other.limitUseWithUser, limitUseWithUser) ||
                other.limitUseWithUser == limitUseWithUser) &&
            const DeepCollectionEquality()
                .equals(other._limitPlanIds, _limitPlanIds) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.endedAt, endedAt) || other.endedAt == endedAt) &&
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
      code,
      name,
      type,
      value,
      limitUse,
      limitUseWithUser,
      const DeepCollectionEquality().hash(_limitPlanIds),
      startedAt,
      endedAt,
      createdAt,
      updatedAt);

  /// Create a copy of Coupon
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CouponImplCopyWith<_$CouponImpl> get copyWith =>
      __$$CouponImplCopyWithImpl<_$CouponImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CouponImplToJson(
      this,
    );
  }
}

abstract class _Coupon extends Coupon {
  const factory _Coupon(
      {final int? id,
      final String? code,
      final String? name,
      final int? type,
      final int? value,
      @JsonKey(name: 'limit_use') final int? limitUse,
      @JsonKey(name: 'limit_use_with_user') final int? limitUseWithUser,
      @JsonKey(name: 'limit_plan_ids') final List<int>? limitPlanIds,
      @JsonKey(name: 'started_at') final int? startedAt,
      @JsonKey(name: 'ended_at') final int? endedAt,
      @JsonKey(name: 'created_at') final int? createdAt,
      @JsonKey(name: 'updated_at') final int? updatedAt}) = _$CouponImpl;
  const _Coupon._() : super._();

  factory _Coupon.fromJson(Map<String, dynamic> json) = _$CouponImpl.fromJson;

  @override
  int? get id;
  @override
  String? get code;
  @override
  String? get name;
  @override
  int? get type;
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
  List<int>? get limitPlanIds;
  @override
  @JsonKey(name: 'started_at')
  int? get startedAt;
  @override
  @JsonKey(name: 'ended_at')
  int? get endedAt;
  @override
  @JsonKey(name: 'created_at')
  int? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  int? get updatedAt;

  /// Create a copy of Coupon
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CouponImplCopyWith<_$CouponImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
