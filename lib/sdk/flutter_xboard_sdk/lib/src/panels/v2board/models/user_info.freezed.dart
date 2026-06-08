// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_info.dart';

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
  int? get transferEnable => throw _privateConstructorUsedError;
  @JsonKey(name: 'device_limit')
  int? get deviceLimit => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_login_at')
  int? get lastLoginAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  int? get createdAt => throw _privateConstructorUsedError;
  int? get banned => throw _privateConstructorUsedError;
  @JsonKey(name: 'auto_renewal')
  int? get autoRenewal => throw _privateConstructorUsedError;
  @JsonKey(name: 'remind_expire')
  int? get remindExpire => throw _privateConstructorUsedError;
  @JsonKey(name: 'remind_traffic')
  int? get remindTraffic => throw _privateConstructorUsedError;
  @JsonKey(name: 'expired_at')
  int? get expiredAt => throw _privateConstructorUsedError;
  int? get balance => throw _privateConstructorUsedError;
  @JsonKey(name: 'commission_balance')
  int? get commissionBalance => throw _privateConstructorUsedError;
  @JsonKey(name: 'plan_id')
  int? get planId => throw _privateConstructorUsedError;
  int? get discount => throw _privateConstructorUsedError;
  @JsonKey(name: 'commission_rate')
  int? get commissionRate => throw _privateConstructorUsedError;
  @JsonKey(name: 'telegram_id')
  int? get telegramId => throw _privateConstructorUsedError;
  String? get uuid => throw _privateConstructorUsedError;
  @JsonKey(name: 'avatar_url')
  String? get avatarUrl => throw _privateConstructorUsedError;

  /// 已上传流量 (bytes)
  int? get u => throw _privateConstructorUsedError;

  /// 已下载流量 (bytes)
  int? get d => throw _privateConstructorUsedError;

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
      @JsonKey(name: 'transfer_enable') int? transferEnable,
      @JsonKey(name: 'device_limit') int? deviceLimit,
      @JsonKey(name: 'last_login_at') int? lastLoginAt,
      @JsonKey(name: 'created_at') int? createdAt,
      int? banned,
      @JsonKey(name: 'auto_renewal') int? autoRenewal,
      @JsonKey(name: 'remind_expire') int? remindExpire,
      @JsonKey(name: 'remind_traffic') int? remindTraffic,
      @JsonKey(name: 'expired_at') int? expiredAt,
      int? balance,
      @JsonKey(name: 'commission_balance') int? commissionBalance,
      @JsonKey(name: 'plan_id') int? planId,
      int? discount,
      @JsonKey(name: 'commission_rate') int? commissionRate,
      @JsonKey(name: 'telegram_id') int? telegramId,
      String? uuid,
      @JsonKey(name: 'avatar_url') String? avatarUrl,
      int? u,
      int? d});
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
    Object? transferEnable = freezed,
    Object? deviceLimit = freezed,
    Object? lastLoginAt = freezed,
    Object? createdAt = freezed,
    Object? banned = freezed,
    Object? autoRenewal = freezed,
    Object? remindExpire = freezed,
    Object? remindTraffic = freezed,
    Object? expiredAt = freezed,
    Object? balance = freezed,
    Object? commissionBalance = freezed,
    Object? planId = freezed,
    Object? discount = freezed,
    Object? commissionRate = freezed,
    Object? telegramId = freezed,
    Object? uuid = freezed,
    Object? avatarUrl = freezed,
    Object? u = freezed,
    Object? d = freezed,
  }) {
    return _then(_value.copyWith(
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      transferEnable: freezed == transferEnable
          ? _value.transferEnable
          : transferEnable // ignore: cast_nullable_to_non_nullable
              as int?,
      deviceLimit: freezed == deviceLimit
          ? _value.deviceLimit
          : deviceLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      lastLoginAt: freezed == lastLoginAt
          ? _value.lastLoginAt
          : lastLoginAt // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int?,
      banned: freezed == banned
          ? _value.banned
          : banned // ignore: cast_nullable_to_non_nullable
              as int?,
      autoRenewal: freezed == autoRenewal
          ? _value.autoRenewal
          : autoRenewal // ignore: cast_nullable_to_non_nullable
              as int?,
      remindExpire: freezed == remindExpire
          ? _value.remindExpire
          : remindExpire // ignore: cast_nullable_to_non_nullable
              as int?,
      remindTraffic: freezed == remindTraffic
          ? _value.remindTraffic
          : remindTraffic // ignore: cast_nullable_to_non_nullable
              as int?,
      expiredAt: freezed == expiredAt
          ? _value.expiredAt
          : expiredAt // ignore: cast_nullable_to_non_nullable
              as int?,
      balance: freezed == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as int?,
      commissionBalance: freezed == commissionBalance
          ? _value.commissionBalance
          : commissionBalance // ignore: cast_nullable_to_non_nullable
              as int?,
      planId: freezed == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as int?,
      discount: freezed == discount
          ? _value.discount
          : discount // ignore: cast_nullable_to_non_nullable
              as int?,
      commissionRate: freezed == commissionRate
          ? _value.commissionRate
          : commissionRate // ignore: cast_nullable_to_non_nullable
              as int?,
      telegramId: freezed == telegramId
          ? _value.telegramId
          : telegramId // ignore: cast_nullable_to_non_nullable
              as int?,
      uuid: freezed == uuid
          ? _value.uuid
          : uuid // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      u: freezed == u
          ? _value.u
          : u // ignore: cast_nullable_to_non_nullable
              as int?,
      d: freezed == d
          ? _value.d
          : d // ignore: cast_nullable_to_non_nullable
              as int?,
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
      @JsonKey(name: 'transfer_enable') int? transferEnable,
      @JsonKey(name: 'device_limit') int? deviceLimit,
      @JsonKey(name: 'last_login_at') int? lastLoginAt,
      @JsonKey(name: 'created_at') int? createdAt,
      int? banned,
      @JsonKey(name: 'auto_renewal') int? autoRenewal,
      @JsonKey(name: 'remind_expire') int? remindExpire,
      @JsonKey(name: 'remind_traffic') int? remindTraffic,
      @JsonKey(name: 'expired_at') int? expiredAt,
      int? balance,
      @JsonKey(name: 'commission_balance') int? commissionBalance,
      @JsonKey(name: 'plan_id') int? planId,
      int? discount,
      @JsonKey(name: 'commission_rate') int? commissionRate,
      @JsonKey(name: 'telegram_id') int? telegramId,
      String? uuid,
      @JsonKey(name: 'avatar_url') String? avatarUrl,
      int? u,
      int? d});
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
    Object? transferEnable = freezed,
    Object? deviceLimit = freezed,
    Object? lastLoginAt = freezed,
    Object? createdAt = freezed,
    Object? banned = freezed,
    Object? autoRenewal = freezed,
    Object? remindExpire = freezed,
    Object? remindTraffic = freezed,
    Object? expiredAt = freezed,
    Object? balance = freezed,
    Object? commissionBalance = freezed,
    Object? planId = freezed,
    Object? discount = freezed,
    Object? commissionRate = freezed,
    Object? telegramId = freezed,
    Object? uuid = freezed,
    Object? avatarUrl = freezed,
    Object? u = freezed,
    Object? d = freezed,
  }) {
    return _then(_$UserInfoImpl(
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      transferEnable: freezed == transferEnable
          ? _value.transferEnable
          : transferEnable // ignore: cast_nullable_to_non_nullable
              as int?,
      deviceLimit: freezed == deviceLimit
          ? _value.deviceLimit
          : deviceLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      lastLoginAt: freezed == lastLoginAt
          ? _value.lastLoginAt
          : lastLoginAt // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int?,
      banned: freezed == banned
          ? _value.banned
          : banned // ignore: cast_nullable_to_non_nullable
              as int?,
      autoRenewal: freezed == autoRenewal
          ? _value.autoRenewal
          : autoRenewal // ignore: cast_nullable_to_non_nullable
              as int?,
      remindExpire: freezed == remindExpire
          ? _value.remindExpire
          : remindExpire // ignore: cast_nullable_to_non_nullable
              as int?,
      remindTraffic: freezed == remindTraffic
          ? _value.remindTraffic
          : remindTraffic // ignore: cast_nullable_to_non_nullable
              as int?,
      expiredAt: freezed == expiredAt
          ? _value.expiredAt
          : expiredAt // ignore: cast_nullable_to_non_nullable
              as int?,
      balance: freezed == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as int?,
      commissionBalance: freezed == commissionBalance
          ? _value.commissionBalance
          : commissionBalance // ignore: cast_nullable_to_non_nullable
              as int?,
      planId: freezed == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as int?,
      discount: freezed == discount
          ? _value.discount
          : discount // ignore: cast_nullable_to_non_nullable
              as int?,
      commissionRate: freezed == commissionRate
          ? _value.commissionRate
          : commissionRate // ignore: cast_nullable_to_non_nullable
              as int?,
      telegramId: freezed == telegramId
          ? _value.telegramId
          : telegramId // ignore: cast_nullable_to_non_nullable
              as int?,
      uuid: freezed == uuid
          ? _value.uuid
          : uuid // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      u: freezed == u
          ? _value.u
          : u // ignore: cast_nullable_to_non_nullable
              as int?,
      d: freezed == d
          ? _value.d
          : d // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserInfoImpl extends _UserInfo {
  const _$UserInfoImpl(
      {required this.email,
      @JsonKey(name: 'transfer_enable') this.transferEnable,
      @JsonKey(name: 'device_limit') this.deviceLimit,
      @JsonKey(name: 'last_login_at') this.lastLoginAt,
      @JsonKey(name: 'created_at') this.createdAt,
      this.banned,
      @JsonKey(name: 'auto_renewal') this.autoRenewal,
      @JsonKey(name: 'remind_expire') this.remindExpire,
      @JsonKey(name: 'remind_traffic') this.remindTraffic,
      @JsonKey(name: 'expired_at') this.expiredAt,
      this.balance,
      @JsonKey(name: 'commission_balance') this.commissionBalance,
      @JsonKey(name: 'plan_id') this.planId,
      this.discount,
      @JsonKey(name: 'commission_rate') this.commissionRate,
      @JsonKey(name: 'telegram_id') this.telegramId,
      this.uuid,
      @JsonKey(name: 'avatar_url') this.avatarUrl,
      this.u,
      this.d})
      : super._();

  factory _$UserInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserInfoImplFromJson(json);

  @override
  final String email;
  @override
  @JsonKey(name: 'transfer_enable')
  final int? transferEnable;
  @override
  @JsonKey(name: 'device_limit')
  final int? deviceLimit;
  @override
  @JsonKey(name: 'last_login_at')
  final int? lastLoginAt;
  @override
  @JsonKey(name: 'created_at')
  final int? createdAt;
  @override
  final int? banned;
  @override
  @JsonKey(name: 'auto_renewal')
  final int? autoRenewal;
  @override
  @JsonKey(name: 'remind_expire')
  final int? remindExpire;
  @override
  @JsonKey(name: 'remind_traffic')
  final int? remindTraffic;
  @override
  @JsonKey(name: 'expired_at')
  final int? expiredAt;
  @override
  final int? balance;
  @override
  @JsonKey(name: 'commission_balance')
  final int? commissionBalance;
  @override
  @JsonKey(name: 'plan_id')
  final int? planId;
  @override
  final int? discount;
  @override
  @JsonKey(name: 'commission_rate')
  final int? commissionRate;
  @override
  @JsonKey(name: 'telegram_id')
  final int? telegramId;
  @override
  final String? uuid;
  @override
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  /// 已上传流量 (bytes)
  @override
  final int? u;

  /// 已下载流量 (bytes)
  @override
  final int? d;

  @override
  String toString() {
    return 'UserInfo(email: $email, transferEnable: $transferEnable, deviceLimit: $deviceLimit, lastLoginAt: $lastLoginAt, createdAt: $createdAt, banned: $banned, autoRenewal: $autoRenewal, remindExpire: $remindExpire, remindTraffic: $remindTraffic, expiredAt: $expiredAt, balance: $balance, commissionBalance: $commissionBalance, planId: $planId, discount: $discount, commissionRate: $commissionRate, telegramId: $telegramId, uuid: $uuid, avatarUrl: $avatarUrl, u: $u, d: $d)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserInfoImpl &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.transferEnable, transferEnable) ||
                other.transferEnable == transferEnable) &&
            (identical(other.deviceLimit, deviceLimit) ||
                other.deviceLimit == deviceLimit) &&
            (identical(other.lastLoginAt, lastLoginAt) ||
                other.lastLoginAt == lastLoginAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.banned, banned) || other.banned == banned) &&
            (identical(other.autoRenewal, autoRenewal) ||
                other.autoRenewal == autoRenewal) &&
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
                other.avatarUrl == avatarUrl) &&
            (identical(other.u, u) || other.u == u) &&
            (identical(other.d, d) || other.d == d));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        email,
        transferEnable,
        deviceLimit,
        lastLoginAt,
        createdAt,
        banned,
        autoRenewal,
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
        avatarUrl,
        u,
        d
      ]);

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
      @JsonKey(name: 'transfer_enable') final int? transferEnable,
      @JsonKey(name: 'device_limit') final int? deviceLimit,
      @JsonKey(name: 'last_login_at') final int? lastLoginAt,
      @JsonKey(name: 'created_at') final int? createdAt,
      final int? banned,
      @JsonKey(name: 'auto_renewal') final int? autoRenewal,
      @JsonKey(name: 'remind_expire') final int? remindExpire,
      @JsonKey(name: 'remind_traffic') final int? remindTraffic,
      @JsonKey(name: 'expired_at') final int? expiredAt,
      final int? balance,
      @JsonKey(name: 'commission_balance') final int? commissionBalance,
      @JsonKey(name: 'plan_id') final int? planId,
      final int? discount,
      @JsonKey(name: 'commission_rate') final int? commissionRate,
      @JsonKey(name: 'telegram_id') final int? telegramId,
      final String? uuid,
      @JsonKey(name: 'avatar_url') final String? avatarUrl,
      final int? u,
      final int? d}) = _$UserInfoImpl;
  const _UserInfo._() : super._();

  factory _UserInfo.fromJson(Map<String, dynamic> json) =
      _$UserInfoImpl.fromJson;

  @override
  String get email;
  @override
  @JsonKey(name: 'transfer_enable')
  int? get transferEnable;
  @override
  @JsonKey(name: 'device_limit')
  int? get deviceLimit;
  @override
  @JsonKey(name: 'last_login_at')
  int? get lastLoginAt;
  @override
  @JsonKey(name: 'created_at')
  int? get createdAt;
  @override
  int? get banned;
  @override
  @JsonKey(name: 'auto_renewal')
  int? get autoRenewal;
  @override
  @JsonKey(name: 'remind_expire')
  int? get remindExpire;
  @override
  @JsonKey(name: 'remind_traffic')
  int? get remindTraffic;
  @override
  @JsonKey(name: 'expired_at')
  int? get expiredAt;
  @override
  int? get balance;
  @override
  @JsonKey(name: 'commission_balance')
  int? get commissionBalance;
  @override
  @JsonKey(name: 'plan_id')
  int? get planId;
  @override
  int? get discount;
  @override
  @JsonKey(name: 'commission_rate')
  int? get commissionRate;
  @override
  @JsonKey(name: 'telegram_id')
  int? get telegramId;
  @override
  String? get uuid;
  @override
  @JsonKey(name: 'avatar_url')
  String? get avatarUrl;

  /// 已上传流量 (bytes)
  @override
  int? get u;

  /// 已下载流量 (bytes)
  @override
  int? get d;

  /// Create a copy of UserInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserInfoImplCopyWith<_$UserInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
