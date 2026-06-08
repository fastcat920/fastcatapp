// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'xboard_user_info_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserInfo _$UserInfoFromJson(Map<String, dynamic> json) {
  return _UserInfo.fromJson(json);
}

/// @nodoc
mixin _$UserInfo {
  String get email => throw _privateConstructorUsedError;
  @JsonKey(name: 'transfer_enable')
  double get transferEnable => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'last_login_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get lastLoginAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool get banned => throw _privateConstructorUsedError;
  @JsonKey(name: 'remind_expire', fromJson: _intToBool, toJson: _boolToInt)
  bool get remindExpire => throw _privateConstructorUsedError;
  @JsonKey(name: 'remind_traffic', fromJson: _intToBool, toJson: _boolToInt)
  bool get remindTraffic => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'expired_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get expiredAt => throw _privateConstructorUsedError;
  double get balance => throw _privateConstructorUsedError;
  @JsonKey(name: 'commission_balance')
  double get commissionBalance => throw _privateConstructorUsedError;
  @JsonKey(name: 'plan_id')
  int? get planId => throw _privateConstructorUsedError;
  double? get discount => throw _privateConstructorUsedError;
  @JsonKey(name: 'commission_rate')
  double? get commissionRate => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'telegram_id',
      fromJson: _telegramIdFromJson,
      toJson: _telegramIdToJson)
  String? get telegramId => throw _privateConstructorUsedError;
  String get uuid => throw _privateConstructorUsedError;
  @JsonKey(name: 'avatar_url')
  String get avatarUrl => throw _privateConstructorUsedError;

  /// Serializes this UserInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserInfoCopyWith<UserInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserInfoCopyWith<$Res> {
  factory $UserInfoCopyWith(UserInfo value, $Res Function(UserInfo) then) =
      _$UserInfoCopyWithImpl<$Res, UserInfo>;
  @useResult
  $Res call(
      {String email,
      @JsonKey(name: 'transfer_enable') double transferEnable,
      @JsonKey(
          name: 'last_login_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime? lastLoginAt,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime? createdAt,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) bool banned,
      @JsonKey(name: 'remind_expire', fromJson: _intToBool, toJson: _boolToInt)
      bool remindExpire,
      @JsonKey(name: 'remind_traffic', fromJson: _intToBool, toJson: _boolToInt)
      bool remindTraffic,
      @JsonKey(
          name: 'expired_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime? expiredAt,
      double balance,
      @JsonKey(name: 'commission_balance') double commissionBalance,
      @JsonKey(name: 'plan_id') int? planId,
      double? discount,
      @JsonKey(name: 'commission_rate') double? commissionRate,
      @JsonKey(
          name: 'telegram_id',
          fromJson: _telegramIdFromJson,
          toJson: _telegramIdToJson)
      String? telegramId,
      String uuid,
      @JsonKey(name: 'avatar_url') String avatarUrl});
}

/// @nodoc
class _$UserInfoCopyWithImpl<$Res, $Val extends UserInfo>
    implements $UserInfoCopyWith<$Res> {
  _$UserInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? email = null,
    Object? transferEnable = null,
    Object? lastLoginAt = freezed,
    Object? createdAt = freezed,
    Object? banned = null,
    Object? remindExpire = null,
    Object? remindTraffic = null,
    Object? expiredAt = freezed,
    Object? balance = null,
    Object? commissionBalance = null,
    Object? planId = freezed,
    Object? discount = freezed,
    Object? commissionRate = freezed,
    Object? telegramId = freezed,
    Object? uuid = null,
    Object? avatarUrl = null,
  }) {
    return _then(_value.copyWith(
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      transferEnable: null == transferEnable
          ? _value.transferEnable
          : transferEnable // ignore: cast_nullable_to_non_nullable
              as double,
      lastLoginAt: freezed == lastLoginAt
          ? _value.lastLoginAt
          : lastLoginAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      banned: null == banned
          ? _value.banned
          : banned // ignore: cast_nullable_to_non_nullable
              as bool,
      remindExpire: null == remindExpire
          ? _value.remindExpire
          : remindExpire // ignore: cast_nullable_to_non_nullable
              as bool,
      remindTraffic: null == remindTraffic
          ? _value.remindTraffic
          : remindTraffic // ignore: cast_nullable_to_non_nullable
              as bool,
      expiredAt: freezed == expiredAt
          ? _value.expiredAt
          : expiredAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      balance: null == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as double,
      commissionBalance: null == commissionBalance
          ? _value.commissionBalance
          : commissionBalance // ignore: cast_nullable_to_non_nullable
              as double,
      planId: freezed == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as int?,
      discount: freezed == discount
          ? _value.discount
          : discount // ignore: cast_nullable_to_non_nullable
              as double?,
      commissionRate: freezed == commissionRate
          ? _value.commissionRate
          : commissionRate // ignore: cast_nullable_to_non_nullable
              as double?,
      telegramId: freezed == telegramId
          ? _value.telegramId
          : telegramId // ignore: cast_nullable_to_non_nullable
              as String?,
      uuid: null == uuid
          ? _value.uuid
          : uuid // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: null == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserInfoImplCopyWith<$Res>
    implements $UserInfoCopyWith<$Res> {
  factory _$$UserInfoImplCopyWith(
          _$UserInfoImpl value, $Res Function(_$UserInfoImpl) then) =
      __$$UserInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String email,
      @JsonKey(name: 'transfer_enable') double transferEnable,
      @JsonKey(
          name: 'last_login_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime? lastLoginAt,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime? createdAt,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) bool banned,
      @JsonKey(name: 'remind_expire', fromJson: _intToBool, toJson: _boolToInt)
      bool remindExpire,
      @JsonKey(name: 'remind_traffic', fromJson: _intToBool, toJson: _boolToInt)
      bool remindTraffic,
      @JsonKey(
          name: 'expired_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime? expiredAt,
      double balance,
      @JsonKey(name: 'commission_balance') double commissionBalance,
      @JsonKey(name: 'plan_id') int? planId,
      double? discount,
      @JsonKey(name: 'commission_rate') double? commissionRate,
      @JsonKey(
          name: 'telegram_id',
          fromJson: _telegramIdFromJson,
          toJson: _telegramIdToJson)
      String? telegramId,
      String uuid,
      @JsonKey(name: 'avatar_url') String avatarUrl});
}

/// @nodoc
class __$$UserInfoImplCopyWithImpl<$Res>
    extends _$UserInfoCopyWithImpl<$Res, _$UserInfoImpl>
    implements _$$UserInfoImplCopyWith<$Res> {
  __$$UserInfoImplCopyWithImpl(
      _$UserInfoImpl _value, $Res Function(_$UserInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of UserInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? email = null,
    Object? transferEnable = null,
    Object? lastLoginAt = freezed,
    Object? createdAt = freezed,
    Object? banned = null,
    Object? remindExpire = null,
    Object? remindTraffic = null,
    Object? expiredAt = freezed,
    Object? balance = null,
    Object? commissionBalance = null,
    Object? planId = freezed,
    Object? discount = freezed,
    Object? commissionRate = freezed,
    Object? telegramId = freezed,
    Object? uuid = null,
    Object? avatarUrl = null,
  }) {
    return _then(_$UserInfoImpl(
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      transferEnable: null == transferEnable
          ? _value.transferEnable
          : transferEnable // ignore: cast_nullable_to_non_nullable
              as double,
      lastLoginAt: freezed == lastLoginAt
          ? _value.lastLoginAt
          : lastLoginAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      banned: null == banned
          ? _value.banned
          : banned // ignore: cast_nullable_to_non_nullable
              as bool,
      remindExpire: null == remindExpire
          ? _value.remindExpire
          : remindExpire // ignore: cast_nullable_to_non_nullable
              as bool,
      remindTraffic: null == remindTraffic
          ? _value.remindTraffic
          : remindTraffic // ignore: cast_nullable_to_non_nullable
              as bool,
      expiredAt: freezed == expiredAt
          ? _value.expiredAt
          : expiredAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      balance: null == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as double,
      commissionBalance: null == commissionBalance
          ? _value.commissionBalance
          : commissionBalance // ignore: cast_nullable_to_non_nullable
              as double,
      planId: freezed == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as int?,
      discount: freezed == discount
          ? _value.discount
          : discount // ignore: cast_nullable_to_non_nullable
              as double?,
      commissionRate: freezed == commissionRate
          ? _value.commissionRate
          : commissionRate // ignore: cast_nullable_to_non_nullable
              as double?,
      telegramId: freezed == telegramId
          ? _value.telegramId
          : telegramId // ignore: cast_nullable_to_non_nullable
              as String?,
      uuid: null == uuid
          ? _value.uuid
          : uuid // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: null == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserInfoImpl extends _UserInfo {
  const _$UserInfoImpl(
      {required this.email,
      @JsonKey(name: 'transfer_enable') this.transferEnable = 0,
      @JsonKey(
          name: 'last_login_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      this.lastLoginAt,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      this.createdAt,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) this.banned = false,
      @JsonKey(name: 'remind_expire', fromJson: _intToBool, toJson: _boolToInt)
      this.remindExpire = true,
      @JsonKey(name: 'remind_traffic', fromJson: _intToBool, toJson: _boolToInt)
      this.remindTraffic = true,
      @JsonKey(
          name: 'expired_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      this.expiredAt,
      this.balance = 0,
      @JsonKey(name: 'commission_balance') this.commissionBalance = 0,
      @JsonKey(name: 'plan_id') this.planId,
      this.discount,
      @JsonKey(name: 'commission_rate') this.commissionRate,
      @JsonKey(
          name: 'telegram_id',
          fromJson: _telegramIdFromJson,
          toJson: _telegramIdToJson)
      this.telegramId,
      this.uuid = '',
      @JsonKey(name: 'avatar_url') this.avatarUrl = ''})
      : super._();

  factory _$UserInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserInfoImplFromJson(json);

  @override
  final String email;
  @override
  @JsonKey(name: 'transfer_enable')
  final double transferEnable;
  @override
  @JsonKey(
      name: 'last_login_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime? lastLoginAt;
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime? createdAt;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  final bool banned;
  @override
  @JsonKey(name: 'remind_expire', fromJson: _intToBool, toJson: _boolToInt)
  final bool remindExpire;
  @override
  @JsonKey(name: 'remind_traffic', fromJson: _intToBool, toJson: _boolToInt)
  final bool remindTraffic;
  @override
  @JsonKey(
      name: 'expired_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime? expiredAt;
  @override
  @JsonKey()
  final double balance;
  @override
  @JsonKey(name: 'commission_balance')
  final double commissionBalance;
  @override
  @JsonKey(name: 'plan_id')
  final int? planId;
  @override
  final double? discount;
  @override
  @JsonKey(name: 'commission_rate')
  final double? commissionRate;
  @override
  @JsonKey(
      name: 'telegram_id',
      fromJson: _telegramIdFromJson,
      toJson: _telegramIdToJson)
  final String? telegramId;
  @override
  @JsonKey()
  final String uuid;
  @override
  @JsonKey(name: 'avatar_url')
  final String avatarUrl;

  @override
  String toString() {
    return 'UserInfo(email: $email, transferEnable: $transferEnable, lastLoginAt: $lastLoginAt, createdAt: $createdAt, banned: $banned, remindExpire: $remindExpire, remindTraffic: $remindTraffic, expiredAt: $expiredAt, balance: $balance, commissionBalance: $commissionBalance, planId: $planId, discount: $discount, commissionRate: $commissionRate, telegramId: $telegramId, uuid: $uuid, avatarUrl: $avatarUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserInfoImpl &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.transferEnable, transferEnable) ||
                other.transferEnable == transferEnable) &&
            (identical(other.lastLoginAt, lastLoginAt) ||
                other.lastLoginAt == lastLoginAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.banned, banned) || other.banned == banned) &&
            (identical(other.remindExpire, remindExpire) ||
                other.remindExpire == remindExpire) &&
            (identical(other.remindTraffic, remindTraffic) ||
                other.remindTraffic == remindTraffic) &&
            (identical(other.expiredAt, expiredAt) ||
                other.expiredAt == expiredAt) &&
            (identical(other.balance, balance) || other.balance == balance) &&
            (identical(other.commissionBalance, commissionBalance) ||
                other.commissionBalance == commissionBalance) &&
            (identical(other.planId, planId) || other.planId == planId) &&
            (identical(other.discount, discount) ||
                other.discount == discount) &&
            (identical(other.commissionRate, commissionRate) ||
                other.commissionRate == commissionRate) &&
            (identical(other.telegramId, telegramId) ||
                other.telegramId == telegramId) &&
            (identical(other.uuid, uuid) || other.uuid == uuid) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      email,
      transferEnable,
      lastLoginAt,
      createdAt,
      banned,
      remindExpire,
      remindTraffic,
      expiredAt,
      balance,
      commissionBalance,
      planId,
      discount,
      commissionRate,
      telegramId,
      uuid,
      avatarUrl);

  /// Create a copy of UserInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserInfoImplCopyWith<_$UserInfoImpl> get copyWith =>
      __$$UserInfoImplCopyWithImpl<_$UserInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserInfoImplToJson(
      this,
    );
  }
}

abstract class _UserInfo extends UserInfo {
  const factory _UserInfo(
      {required final String email,
      @JsonKey(name: 'transfer_enable') final double transferEnable,
      @JsonKey(
          name: 'last_login_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      final DateTime? lastLoginAt,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      final DateTime? createdAt,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) final bool banned,
      @JsonKey(name: 'remind_expire', fromJson: _intToBool, toJson: _boolToInt)
      final bool remindExpire,
      @JsonKey(name: 'remind_traffic', fromJson: _intToBool, toJson: _boolToInt)
      final bool remindTraffic,
      @JsonKey(
          name: 'expired_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      final DateTime? expiredAt,
      final double balance,
      @JsonKey(name: 'commission_balance') final double commissionBalance,
      @JsonKey(name: 'plan_id') final int? planId,
      final double? discount,
      @JsonKey(name: 'commission_rate') final double? commissionRate,
      @JsonKey(
          name: 'telegram_id',
          fromJson: _telegramIdFromJson,
          toJson: _telegramIdToJson)
      final String? telegramId,
      final String uuid,
      @JsonKey(name: 'avatar_url') final String avatarUrl}) = _$UserInfoImpl;
  const _UserInfo._() : super._();

  factory _UserInfo.fromJson(Map<String, dynamic> json) =
      _$UserInfoImpl.fromJson;

  @override
  String get email;
  @override
  @JsonKey(name: 'transfer_enable')
  double get transferEnable;
  @override
  @JsonKey(
      name: 'last_login_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get lastLoginAt;
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get createdAt;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool get banned;
  @override
  @JsonKey(name: 'remind_expire', fromJson: _intToBool, toJson: _boolToInt)
  bool get remindExpire;
  @override
  @JsonKey(name: 'remind_traffic', fromJson: _intToBool, toJson: _boolToInt)
  bool get remindTraffic;
  @override
  @JsonKey(
      name: 'expired_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime? get expiredAt;
  @override
  double get balance;
  @override
  @JsonKey(name: 'commission_balance')
  double get commissionBalance;
  @override
  @JsonKey(name: 'plan_id')
  int? get planId;
  @override
  double? get discount;
  @override
  @JsonKey(name: 'commission_rate')
  double? get commissionRate;
  @override
  @JsonKey(
      name: 'telegram_id',
      fromJson: _telegramIdFromJson,
      toJson: _telegramIdToJson)
  String? get telegramId;
  @override
  String get uuid;
  @override
  @JsonKey(name: 'avatar_url')
  String get avatarUrl;

  /// Create a copy of UserInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserInfoImplCopyWith<_$UserInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
