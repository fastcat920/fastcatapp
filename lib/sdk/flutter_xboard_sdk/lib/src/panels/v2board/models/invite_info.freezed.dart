// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invite_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

InviteInfo _$InviteInfoFromJson(Map<String, dynamic> json) {
  return _InviteInfo.fromJson(json);
}

/// @nodoc
mixin _$InviteInfo {
  List<InviteCode>? get codes => throw _privateConstructorUsedError;
  InviteStat? get stat => throw _privateConstructorUsedError;

  /// Serializes this InviteInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of InviteInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InviteInfoCopyWith<InviteInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InviteInfoCopyWith<$Res> {
  factory $InviteInfoCopyWith(
          InviteInfo value, $Res Function(InviteInfo) then) =
      _$InviteInfoCopyWithImpl<$Res, InviteInfo>;
  @useResult
  $Res call({List<InviteCode>? codes, InviteStat? stat});

  $InviteStatCopyWith<$Res>? get stat;
}

/// @nodoc
class _$InviteInfoCopyWithImpl<$Res, $Val extends InviteInfo>
    implements $InviteInfoCopyWith<$Res> {
  _$InviteInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of InviteInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? codes = freezed,
    Object? stat = freezed,
  }) {
    return _then(_value.copyWith(
      codes: freezed == codes
          ? _value.codes
          : codes // ignore: cast_nullable_to_non_nullable
              as List<InviteCode>?,
      stat: freezed == stat
          ? _value.stat
          : stat // ignore: cast_nullable_to_non_nullable
              as InviteStat?,
    ) as $Val);
  }

  /// Create a copy of InviteInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $InviteStatCopyWith<$Res>? get stat {
    if (_value.stat == null) {
      return null;
    }

    return $InviteStatCopyWith<$Res>(_value.stat!, (value) {
      return _then(_value.copyWith(stat: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$InviteInfoImplCopyWith<$Res>
    implements $InviteInfoCopyWith<$Res> {
  factory _$$InviteInfoImplCopyWith(
          _$InviteInfoImpl value, $Res Function(_$InviteInfoImpl) then) =
      __$$InviteInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<InviteCode>? codes, InviteStat? stat});

  @override
  $InviteStatCopyWith<$Res>? get stat;
}

/// @nodoc
class __$$InviteInfoImplCopyWithImpl<$Res>
    extends _$InviteInfoCopyWithImpl<$Res, _$InviteInfoImpl>
    implements _$$InviteInfoImplCopyWith<$Res> {
  __$$InviteInfoImplCopyWithImpl(
      _$InviteInfoImpl _value, $Res Function(_$InviteInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of InviteInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? codes = freezed,
    Object? stat = freezed,
  }) {
    return _then(_$InviteInfoImpl(
      codes: freezed == codes
          ? _value._codes
          : codes // ignore: cast_nullable_to_non_nullable
              as List<InviteCode>?,
      stat: freezed == stat
          ? _value.stat
          : stat // ignore: cast_nullable_to_non_nullable
              as InviteStat?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$InviteInfoImpl implements _InviteInfo {
  const _$InviteInfoImpl({final List<InviteCode>? codes, this.stat})
      : _codes = codes;

  factory _$InviteInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$InviteInfoImplFromJson(json);

  final List<InviteCode>? _codes;
  @override
  List<InviteCode>? get codes {
    final value = _codes;
    if (value == null) return null;
    if (_codes is EqualUnmodifiableListView) return _codes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final InviteStat? stat;

  @override
  String toString() {
    return 'InviteInfo(codes: $codes, stat: $stat)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InviteInfoImpl &&
            const DeepCollectionEquality().equals(other._codes, _codes) &&
            (identical(other.stat, stat) || other.stat == stat));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_codes), stat);

  /// Create a copy of InviteInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InviteInfoImplCopyWith<_$InviteInfoImpl> get copyWith =>
      __$$InviteInfoImplCopyWithImpl<_$InviteInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InviteInfoImplToJson(
      this,
    );
  }
}

abstract class _InviteInfo implements InviteInfo {
  const factory _InviteInfo(
      {final List<InviteCode>? codes,
      final InviteStat? stat}) = _$InviteInfoImpl;

  factory _InviteInfo.fromJson(Map<String, dynamic> json) =
      _$InviteInfoImpl.fromJson;

  @override
  List<InviteCode>? get codes;
  @override
  InviteStat? get stat;

  /// Create a copy of InviteInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InviteInfoImplCopyWith<_$InviteInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

InviteCode _$InviteCodeFromJson(Map<String, dynamic> json) {
  return _InviteCode.fromJson(json);
}

/// @nodoc
mixin _$InviteCode {
  int? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  int? get userId => throw _privateConstructorUsedError;
  String? get code => throw _privateConstructorUsedError;
  int? get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  int? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  int? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this InviteCode to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of InviteCode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InviteCodeCopyWith<InviteCode> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InviteCodeCopyWith<$Res> {
  factory $InviteCodeCopyWith(
          InviteCode value, $Res Function(InviteCode) then) =
      _$InviteCodeCopyWithImpl<$Res, InviteCode>;
  @useResult
  $Res call(
      {int? id,
      @JsonKey(name: 'user_id') int? userId,
      String? code,
      int? status,
      @JsonKey(name: 'created_at') int? createdAt,
      @JsonKey(name: 'updated_at') int? updatedAt});
}

/// @nodoc
class _$InviteCodeCopyWithImpl<$Res, $Val extends InviteCode>
    implements $InviteCodeCopyWith<$Res> {
  _$InviteCodeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of InviteCode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? userId = freezed,
    Object? code = freezed,
    Object? status = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      userId: freezed == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as int?,
      code: freezed == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
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
abstract class _$$InviteCodeImplCopyWith<$Res>
    implements $InviteCodeCopyWith<$Res> {
  factory _$$InviteCodeImplCopyWith(
          _$InviteCodeImpl value, $Res Function(_$InviteCodeImpl) then) =
      __$$InviteCodeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int? id,
      @JsonKey(name: 'user_id') int? userId,
      String? code,
      int? status,
      @JsonKey(name: 'created_at') int? createdAt,
      @JsonKey(name: 'updated_at') int? updatedAt});
}

/// @nodoc
class __$$InviteCodeImplCopyWithImpl<$Res>
    extends _$InviteCodeCopyWithImpl<$Res, _$InviteCodeImpl>
    implements _$$InviteCodeImplCopyWith<$Res> {
  __$$InviteCodeImplCopyWithImpl(
      _$InviteCodeImpl _value, $Res Function(_$InviteCodeImpl) _then)
      : super(_value, _then);

  /// Create a copy of InviteCode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? userId = freezed,
    Object? code = freezed,
    Object? status = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$InviteCodeImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      userId: freezed == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as int?,
      code: freezed == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
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
class _$InviteCodeImpl extends _InviteCode {
  const _$InviteCodeImpl(
      {this.id,
      @JsonKey(name: 'user_id') this.userId,
      this.code,
      this.status,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt})
      : super._();

  factory _$InviteCodeImpl.fromJson(Map<String, dynamic> json) =>
      _$$InviteCodeImplFromJson(json);

  @override
  final int? id;
  @override
  @JsonKey(name: 'user_id')
  final int? userId;
  @override
  final String? code;
  @override
  final int? status;
  @override
  @JsonKey(name: 'created_at')
  final int? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final int? updatedAt;

  @override
  String toString() {
    return 'InviteCode(id: $id, userId: $userId, code: $code, status: $status, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InviteCodeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, userId, code, status, createdAt, updatedAt);

  /// Create a copy of InviteCode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InviteCodeImplCopyWith<_$InviteCodeImpl> get copyWith =>
      __$$InviteCodeImplCopyWithImpl<_$InviteCodeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InviteCodeImplToJson(
      this,
    );
  }
}

abstract class _InviteCode extends InviteCode {
  const factory _InviteCode(
      {final int? id,
      @JsonKey(name: 'user_id') final int? userId,
      final String? code,
      final int? status,
      @JsonKey(name: 'created_at') final int? createdAt,
      @JsonKey(name: 'updated_at') final int? updatedAt}) = _$InviteCodeImpl;
  const _InviteCode._() : super._();

  factory _InviteCode.fromJson(Map<String, dynamic> json) =
      _$InviteCodeImpl.fromJson;

  @override
  int? get id;
  @override
  @JsonKey(name: 'user_id')
  int? get userId;
  @override
  String? get code;
  @override
  int? get status;
  @override
  @JsonKey(name: 'created_at')
  int? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  int? get updatedAt;

  /// Create a copy of InviteCode
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InviteCodeImplCopyWith<_$InviteCodeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

InviteStat _$InviteStatFromJson(Map<String, dynamic> json) {
  return _InviteStat.fromJson(json);
}

/// @nodoc
mixin _$InviteStat {
  @JsonKey(name: 'register_count')
  int? get registerCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'commission_rate')
  int? get commissionRate => throw _privateConstructorUsedError;
  @JsonKey(name: 'commission_balance')
  int? get commissionBalance => throw _privateConstructorUsedError;
  @JsonKey(name: 'commission_pending_balance')
  int? get commissionPendingBalance => throw _privateConstructorUsedError;

  /// Serializes this InviteStat to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of InviteStat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InviteStatCopyWith<InviteStat> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InviteStatCopyWith<$Res> {
  factory $InviteStatCopyWith(
          InviteStat value, $Res Function(InviteStat) then) =
      _$InviteStatCopyWithImpl<$Res, InviteStat>;
  @useResult
  $Res call(
      {@JsonKey(name: 'register_count') int? registerCount,
      @JsonKey(name: 'commission_rate') int? commissionRate,
      @JsonKey(name: 'commission_balance') int? commissionBalance,
      @JsonKey(name: 'commission_pending_balance')
      int? commissionPendingBalance});
}

/// @nodoc
class _$InviteStatCopyWithImpl<$Res, $Val extends InviteStat>
    implements $InviteStatCopyWith<$Res> {
  _$InviteStatCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of InviteStat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? registerCount = freezed,
    Object? commissionRate = freezed,
    Object? commissionBalance = freezed,
    Object? commissionPendingBalance = freezed,
  }) {
    return _then(_value.copyWith(
      registerCount: freezed == registerCount
          ? _value.registerCount
          : registerCount // ignore: cast_nullable_to_non_nullable
              as int?,
      commissionRate: freezed == commissionRate
          ? _value.commissionRate
          : commissionRate // ignore: cast_nullable_to_non_nullable
              as int?,
      commissionBalance: freezed == commissionBalance
          ? _value.commissionBalance
          : commissionBalance // ignore: cast_nullable_to_non_nullable
              as int?,
      commissionPendingBalance: freezed == commissionPendingBalance
          ? _value.commissionPendingBalance
          : commissionPendingBalance // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$InviteStatImplCopyWith<$Res>
    implements $InviteStatCopyWith<$Res> {
  factory _$$InviteStatImplCopyWith(
          _$InviteStatImpl value, $Res Function(_$InviteStatImpl) then) =
      __$$InviteStatImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'register_count') int? registerCount,
      @JsonKey(name: 'commission_rate') int? commissionRate,
      @JsonKey(name: 'commission_balance') int? commissionBalance,
      @JsonKey(name: 'commission_pending_balance')
      int? commissionPendingBalance});
}

/// @nodoc
class __$$InviteStatImplCopyWithImpl<$Res>
    extends _$InviteStatCopyWithImpl<$Res, _$InviteStatImpl>
    implements _$$InviteStatImplCopyWith<$Res> {
  __$$InviteStatImplCopyWithImpl(
      _$InviteStatImpl _value, $Res Function(_$InviteStatImpl) _then)
      : super(_value, _then);

  /// Create a copy of InviteStat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? registerCount = freezed,
    Object? commissionRate = freezed,
    Object? commissionBalance = freezed,
    Object? commissionPendingBalance = freezed,
  }) {
    return _then(_$InviteStatImpl(
      registerCount: freezed == registerCount
          ? _value.registerCount
          : registerCount // ignore: cast_nullable_to_non_nullable
              as int?,
      commissionRate: freezed == commissionRate
          ? _value.commissionRate
          : commissionRate // ignore: cast_nullable_to_non_nullable
              as int?,
      commissionBalance: freezed == commissionBalance
          ? _value.commissionBalance
          : commissionBalance // ignore: cast_nullable_to_non_nullable
              as int?,
      commissionPendingBalance: freezed == commissionPendingBalance
          ? _value.commissionPendingBalance
          : commissionPendingBalance // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$InviteStatImpl implements _InviteStat {
  const _$InviteStatImpl(
      {@JsonKey(name: 'register_count') this.registerCount,
      @JsonKey(name: 'commission_rate') this.commissionRate,
      @JsonKey(name: 'commission_balance') this.commissionBalance,
      @JsonKey(name: 'commission_pending_balance')
      this.commissionPendingBalance});

  factory _$InviteStatImpl.fromJson(Map<String, dynamic> json) =>
      _$$InviteStatImplFromJson(json);

  @override
  @JsonKey(name: 'register_count')
  final int? registerCount;
  @override
  @JsonKey(name: 'commission_rate')
  final int? commissionRate;
  @override
  @JsonKey(name: 'commission_balance')
  final int? commissionBalance;
  @override
  @JsonKey(name: 'commission_pending_balance')
  final int? commissionPendingBalance;

  @override
  String toString() {
    return 'InviteStat(registerCount: $registerCount, commissionRate: $commissionRate, commissionBalance: $commissionBalance, commissionPendingBalance: $commissionPendingBalance)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InviteStatImpl &&
            (identical(other.registerCount, registerCount) ||
                other.registerCount == registerCount) &&
            (identical(other.commissionRate, commissionRate) ||
                other.commissionRate == commissionRate) &&
            (identical(other.commissionBalance, commissionBalance) ||
                other.commissionBalance == commissionBalance) &&
            (identical(
                    other.commissionPendingBalance, commissionPendingBalance) ||
                other.commissionPendingBalance == commissionPendingBalance));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, registerCount, commissionRate,
      commissionBalance, commissionPendingBalance);

  /// Create a copy of InviteStat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InviteStatImplCopyWith<_$InviteStatImpl> get copyWith =>
      __$$InviteStatImplCopyWithImpl<_$InviteStatImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InviteStatImplToJson(
      this,
    );
  }
}

abstract class _InviteStat implements InviteStat {
  const factory _InviteStat(
      {@JsonKey(name: 'register_count') final int? registerCount,
      @JsonKey(name: 'commission_rate') final int? commissionRate,
      @JsonKey(name: 'commission_balance') final int? commissionBalance,
      @JsonKey(name: 'commission_pending_balance')
      final int? commissionPendingBalance}) = _$InviteStatImpl;

  factory _InviteStat.fromJson(Map<String, dynamic> json) =
      _$InviteStatImpl.fromJson;

  @override
  @JsonKey(name: 'register_count')
  int? get registerCount;
  @override
  @JsonKey(name: 'commission_rate')
  int? get commissionRate;
  @override
  @JsonKey(name: 'commission_balance')
  int? get commissionBalance;
  @override
  @JsonKey(name: 'commission_pending_balance')
  int? get commissionPendingBalance;

  /// Create a copy of InviteStat
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InviteStatImplCopyWith<_$InviteStatImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
