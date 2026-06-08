// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'config_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ConfigModel _$ConfigModelFromJson(Map<String, dynamic> json) {
  return _ConfigModel.fromJson(json);
}

/// @nodoc
mixin _$ConfigModel {
  @JsonKey(name: 'tos_url')
  String? get tosUrl => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'is_email_verify', fromJson: _intToBoolSafe, toJson: _boolToInt)
  bool get isEmailVerify => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'is_invite_force', fromJson: _intToBoolSafe, toJson: _boolToInt)
  bool get isInviteForce => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'email_whitelist_suffix',
      fromJson: _emailWhitelistFromJson,
      toJson: _emailWhitelistToJson)
  List<String> get emailWhitelistSuffix => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_captcha', fromJson: _intToBoolSafe, toJson: _boolToInt)
  bool get isCaptcha => throw _privateConstructorUsedError;
  @JsonKey(name: 'captcha_type')
  String get captchaType => throw _privateConstructorUsedError;
  @JsonKey(name: 'recaptcha_site_key')
  String? get recaptchaSiteKey => throw _privateConstructorUsedError;
  @JsonKey(name: 'recaptcha_v3_site_key')
  String? get recaptchaV3SiteKey => throw _privateConstructorUsedError;
  @JsonKey(name: 'recaptcha_v3_score_threshold')
  double get recaptchaV3ScoreThreshold => throw _privateConstructorUsedError;
  @JsonKey(name: 'turnstile_site_key')
  String? get turnstileSiteKey => throw _privateConstructorUsedError;
  @JsonKey(name: 'app_description')
  String get appDescription => throw _privateConstructorUsedError;
  @JsonKey(name: 'app_url')
  String get appUrl => throw _privateConstructorUsedError;
  String? get logo => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_recaptcha', fromJson: _intToBoolSafe, toJson: _boolToInt)
  bool get isRecaptcha => throw _privateConstructorUsedError;

  /// Serializes this ConfigModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ConfigModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConfigModelCopyWith<ConfigModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConfigModelCopyWith<$Res> {
  factory $ConfigModelCopyWith(
          ConfigModel value, $Res Function(ConfigModel) then) =
      _$ConfigModelCopyWithImpl<$Res, ConfigModel>;
  @useResult
  $Res call(
      {@JsonKey(name: 'tos_url') String? tosUrl,
      @JsonKey(
          name: 'is_email_verify', fromJson: _intToBoolSafe, toJson: _boolToInt)
      bool isEmailVerify,
      @JsonKey(
          name: 'is_invite_force', fromJson: _intToBoolSafe, toJson: _boolToInt)
      bool isInviteForce,
      @JsonKey(
          name: 'email_whitelist_suffix',
          fromJson: _emailWhitelistFromJson,
          toJson: _emailWhitelistToJson)
      List<String> emailWhitelistSuffix,
      @JsonKey(name: 'is_captcha', fromJson: _intToBoolSafe, toJson: _boolToInt)
      bool isCaptcha,
      @JsonKey(name: 'captcha_type') String captchaType,
      @JsonKey(name: 'recaptcha_site_key') String? recaptchaSiteKey,
      @JsonKey(name: 'recaptcha_v3_site_key') String? recaptchaV3SiteKey,
      @JsonKey(name: 'recaptcha_v3_score_threshold')
      double recaptchaV3ScoreThreshold,
      @JsonKey(name: 'turnstile_site_key') String? turnstileSiteKey,
      @JsonKey(name: 'app_description') String appDescription,
      @JsonKey(name: 'app_url') String appUrl,
      String? logo,
      @JsonKey(
          name: 'is_recaptcha', fromJson: _intToBoolSafe, toJson: _boolToInt)
      bool isRecaptcha});
}

/// @nodoc
class _$ConfigModelCopyWithImpl<$Res, $Val extends ConfigModel>
    implements $ConfigModelCopyWith<$Res> {
  _$ConfigModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConfigModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tosUrl = freezed,
    Object? isEmailVerify = null,
    Object? isInviteForce = null,
    Object? emailWhitelistSuffix = null,
    Object? isCaptcha = null,
    Object? captchaType = null,
    Object? recaptchaSiteKey = freezed,
    Object? recaptchaV3SiteKey = freezed,
    Object? recaptchaV3ScoreThreshold = null,
    Object? turnstileSiteKey = freezed,
    Object? appDescription = null,
    Object? appUrl = null,
    Object? logo = freezed,
    Object? isRecaptcha = null,
  }) {
    return _then(_value.copyWith(
      tosUrl: freezed == tosUrl
          ? _value.tosUrl
          : tosUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isEmailVerify: null == isEmailVerify
          ? _value.isEmailVerify
          : isEmailVerify // ignore: cast_nullable_to_non_nullable
              as bool,
      isInviteForce: null == isInviteForce
          ? _value.isInviteForce
          : isInviteForce // ignore: cast_nullable_to_non_nullable
              as bool,
      emailWhitelistSuffix: null == emailWhitelistSuffix
          ? _value.emailWhitelistSuffix
          : emailWhitelistSuffix // ignore: cast_nullable_to_non_nullable
              as List<String>,
      isCaptcha: null == isCaptcha
          ? _value.isCaptcha
          : isCaptcha // ignore: cast_nullable_to_non_nullable
              as bool,
      captchaType: null == captchaType
          ? _value.captchaType
          : captchaType // ignore: cast_nullable_to_non_nullable
              as String,
      recaptchaSiteKey: freezed == recaptchaSiteKey
          ? _value.recaptchaSiteKey
          : recaptchaSiteKey // ignore: cast_nullable_to_non_nullable
              as String?,
      recaptchaV3SiteKey: freezed == recaptchaV3SiteKey
          ? _value.recaptchaV3SiteKey
          : recaptchaV3SiteKey // ignore: cast_nullable_to_non_nullable
              as String?,
      recaptchaV3ScoreThreshold: null == recaptchaV3ScoreThreshold
          ? _value.recaptchaV3ScoreThreshold
          : recaptchaV3ScoreThreshold // ignore: cast_nullable_to_non_nullable
              as double,
      turnstileSiteKey: freezed == turnstileSiteKey
          ? _value.turnstileSiteKey
          : turnstileSiteKey // ignore: cast_nullable_to_non_nullable
              as String?,
      appDescription: null == appDescription
          ? _value.appDescription
          : appDescription // ignore: cast_nullable_to_non_nullable
              as String,
      appUrl: null == appUrl
          ? _value.appUrl
          : appUrl // ignore: cast_nullable_to_non_nullable
              as String,
      logo: freezed == logo
          ? _value.logo
          : logo // ignore: cast_nullable_to_non_nullable
              as String?,
      isRecaptcha: null == isRecaptcha
          ? _value.isRecaptcha
          : isRecaptcha // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ConfigModelImplCopyWith<$Res>
    implements $ConfigModelCopyWith<$Res> {
  factory _$$ConfigModelImplCopyWith(
          _$ConfigModelImpl value, $Res Function(_$ConfigModelImpl) then) =
      __$$ConfigModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'tos_url') String? tosUrl,
      @JsonKey(
          name: 'is_email_verify', fromJson: _intToBoolSafe, toJson: _boolToInt)
      bool isEmailVerify,
      @JsonKey(
          name: 'is_invite_force', fromJson: _intToBoolSafe, toJson: _boolToInt)
      bool isInviteForce,
      @JsonKey(
          name: 'email_whitelist_suffix',
          fromJson: _emailWhitelistFromJson,
          toJson: _emailWhitelistToJson)
      List<String> emailWhitelistSuffix,
      @JsonKey(name: 'is_captcha', fromJson: _intToBoolSafe, toJson: _boolToInt)
      bool isCaptcha,
      @JsonKey(name: 'captcha_type') String captchaType,
      @JsonKey(name: 'recaptcha_site_key') String? recaptchaSiteKey,
      @JsonKey(name: 'recaptcha_v3_site_key') String? recaptchaV3SiteKey,
      @JsonKey(name: 'recaptcha_v3_score_threshold')
      double recaptchaV3ScoreThreshold,
      @JsonKey(name: 'turnstile_site_key') String? turnstileSiteKey,
      @JsonKey(name: 'app_description') String appDescription,
      @JsonKey(name: 'app_url') String appUrl,
      String? logo,
      @JsonKey(
          name: 'is_recaptcha', fromJson: _intToBoolSafe, toJson: _boolToInt)
      bool isRecaptcha});
}

/// @nodoc
class __$$ConfigModelImplCopyWithImpl<$Res>
    extends _$ConfigModelCopyWithImpl<$Res, _$ConfigModelImpl>
    implements _$$ConfigModelImplCopyWith<$Res> {
  __$$ConfigModelImplCopyWithImpl(
      _$ConfigModelImpl _value, $Res Function(_$ConfigModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of ConfigModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tosUrl = freezed,
    Object? isEmailVerify = null,
    Object? isInviteForce = null,
    Object? emailWhitelistSuffix = null,
    Object? isCaptcha = null,
    Object? captchaType = null,
    Object? recaptchaSiteKey = freezed,
    Object? recaptchaV3SiteKey = freezed,
    Object? recaptchaV3ScoreThreshold = null,
    Object? turnstileSiteKey = freezed,
    Object? appDescription = null,
    Object? appUrl = null,
    Object? logo = freezed,
    Object? isRecaptcha = null,
  }) {
    return _then(_$ConfigModelImpl(
      tosUrl: freezed == tosUrl
          ? _value.tosUrl
          : tosUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isEmailVerify: null == isEmailVerify
          ? _value.isEmailVerify
          : isEmailVerify // ignore: cast_nullable_to_non_nullable
              as bool,
      isInviteForce: null == isInviteForce
          ? _value.isInviteForce
          : isInviteForce // ignore: cast_nullable_to_non_nullable
              as bool,
      emailWhitelistSuffix: null == emailWhitelistSuffix
          ? _value._emailWhitelistSuffix
          : emailWhitelistSuffix // ignore: cast_nullable_to_non_nullable
              as List<String>,
      isCaptcha: null == isCaptcha
          ? _value.isCaptcha
          : isCaptcha // ignore: cast_nullable_to_non_nullable
              as bool,
      captchaType: null == captchaType
          ? _value.captchaType
          : captchaType // ignore: cast_nullable_to_non_nullable
              as String,
      recaptchaSiteKey: freezed == recaptchaSiteKey
          ? _value.recaptchaSiteKey
          : recaptchaSiteKey // ignore: cast_nullable_to_non_nullable
              as String?,
      recaptchaV3SiteKey: freezed == recaptchaV3SiteKey
          ? _value.recaptchaV3SiteKey
          : recaptchaV3SiteKey // ignore: cast_nullable_to_non_nullable
              as String?,
      recaptchaV3ScoreThreshold: null == recaptchaV3ScoreThreshold
          ? _value.recaptchaV3ScoreThreshold
          : recaptchaV3ScoreThreshold // ignore: cast_nullable_to_non_nullable
              as double,
      turnstileSiteKey: freezed == turnstileSiteKey
          ? _value.turnstileSiteKey
          : turnstileSiteKey // ignore: cast_nullable_to_non_nullable
              as String?,
      appDescription: null == appDescription
          ? _value.appDescription
          : appDescription // ignore: cast_nullable_to_non_nullable
              as String,
      appUrl: null == appUrl
          ? _value.appUrl
          : appUrl // ignore: cast_nullable_to_non_nullable
              as String,
      logo: freezed == logo
          ? _value.logo
          : logo // ignore: cast_nullable_to_non_nullable
              as String?,
      isRecaptcha: null == isRecaptcha
          ? _value.isRecaptcha
          : isRecaptcha // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ConfigModelImpl implements _ConfigModel {
  const _$ConfigModelImpl(
      {@JsonKey(name: 'tos_url') this.tosUrl,
      @JsonKey(
          name: 'is_email_verify', fromJson: _intToBoolSafe, toJson: _boolToInt)
      this.isEmailVerify = false,
      @JsonKey(
          name: 'is_invite_force', fromJson: _intToBoolSafe, toJson: _boolToInt)
      this.isInviteForce = false,
      @JsonKey(
          name: 'email_whitelist_suffix',
          fromJson: _emailWhitelistFromJson,
          toJson: _emailWhitelistToJson)
      final List<String> emailWhitelistSuffix = const [],
      @JsonKey(name: 'is_captcha', fromJson: _intToBoolSafe, toJson: _boolToInt)
      this.isCaptcha = false,
      @JsonKey(name: 'captcha_type') this.captchaType = '',
      @JsonKey(name: 'recaptcha_site_key') this.recaptchaSiteKey,
      @JsonKey(name: 'recaptcha_v3_site_key') this.recaptchaV3SiteKey,
      @JsonKey(name: 'recaptcha_v3_score_threshold')
      this.recaptchaV3ScoreThreshold = 0.5,
      @JsonKey(name: 'turnstile_site_key') this.turnstileSiteKey,
      @JsonKey(name: 'app_description') this.appDescription = '',
      @JsonKey(name: 'app_url') this.appUrl = '',
      this.logo,
      @JsonKey(
          name: 'is_recaptcha', fromJson: _intToBoolSafe, toJson: _boolToInt)
      this.isRecaptcha = false})
      : _emailWhitelistSuffix = emailWhitelistSuffix;

  factory _$ConfigModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConfigModelImplFromJson(json);

  @override
  @JsonKey(name: 'tos_url')
  final String? tosUrl;
  @override
  @JsonKey(
      name: 'is_email_verify', fromJson: _intToBoolSafe, toJson: _boolToInt)
  final bool isEmailVerify;
  @override
  @JsonKey(
      name: 'is_invite_force', fromJson: _intToBoolSafe, toJson: _boolToInt)
  final bool isInviteForce;
  final List<String> _emailWhitelistSuffix;
  @override
  @JsonKey(
      name: 'email_whitelist_suffix',
      fromJson: _emailWhitelistFromJson,
      toJson: _emailWhitelistToJson)
  List<String> get emailWhitelistSuffix {
    if (_emailWhitelistSuffix is EqualUnmodifiableListView)
      return _emailWhitelistSuffix;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_emailWhitelistSuffix);
  }

  @override
  @JsonKey(name: 'is_captcha', fromJson: _intToBoolSafe, toJson: _boolToInt)
  final bool isCaptcha;
  @override
  @JsonKey(name: 'captcha_type')
  final String captchaType;
  @override
  @JsonKey(name: 'recaptcha_site_key')
  final String? recaptchaSiteKey;
  @override
  @JsonKey(name: 'recaptcha_v3_site_key')
  final String? recaptchaV3SiteKey;
  @override
  @JsonKey(name: 'recaptcha_v3_score_threshold')
  final double recaptchaV3ScoreThreshold;
  @override
  @JsonKey(name: 'turnstile_site_key')
  final String? turnstileSiteKey;
  @override
  @JsonKey(name: 'app_description')
  final String appDescription;
  @override
  @JsonKey(name: 'app_url')
  final String appUrl;
  @override
  final String? logo;
  @override
  @JsonKey(name: 'is_recaptcha', fromJson: _intToBoolSafe, toJson: _boolToInt)
  final bool isRecaptcha;

  @override
  String toString() {
    return 'ConfigModel(tosUrl: $tosUrl, isEmailVerify: $isEmailVerify, isInviteForce: $isInviteForce, emailWhitelistSuffix: $emailWhitelistSuffix, isCaptcha: $isCaptcha, captchaType: $captchaType, recaptchaSiteKey: $recaptchaSiteKey, recaptchaV3SiteKey: $recaptchaV3SiteKey, recaptchaV3ScoreThreshold: $recaptchaV3ScoreThreshold, turnstileSiteKey: $turnstileSiteKey, appDescription: $appDescription, appUrl: $appUrl, logo: $logo, isRecaptcha: $isRecaptcha)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConfigModelImpl &&
            (identical(other.tosUrl, tosUrl) || other.tosUrl == tosUrl) &&
            (identical(other.isEmailVerify, isEmailVerify) ||
                other.isEmailVerify == isEmailVerify) &&
            (identical(other.isInviteForce, isInviteForce) ||
                other.isInviteForce == isInviteForce) &&
            const DeepCollectionEquality()
                .equals(other._emailWhitelistSuffix, _emailWhitelistSuffix) &&
            (identical(other.isCaptcha, isCaptcha) ||
                other.isCaptcha == isCaptcha) &&
            (identical(other.captchaType, captchaType) ||
                other.captchaType == captchaType) &&
            (identical(other.recaptchaSiteKey, recaptchaSiteKey) ||
                other.recaptchaSiteKey == recaptchaSiteKey) &&
            (identical(other.recaptchaV3SiteKey, recaptchaV3SiteKey) ||
                other.recaptchaV3SiteKey == recaptchaV3SiteKey) &&
            (identical(other.recaptchaV3ScoreThreshold,
                    recaptchaV3ScoreThreshold) ||
                other.recaptchaV3ScoreThreshold == recaptchaV3ScoreThreshold) &&
            (identical(other.turnstileSiteKey, turnstileSiteKey) ||
                other.turnstileSiteKey == turnstileSiteKey) &&
            (identical(other.appDescription, appDescription) ||
                other.appDescription == appDescription) &&
            (identical(other.appUrl, appUrl) || other.appUrl == appUrl) &&
            (identical(other.logo, logo) || other.logo == logo) &&
            (identical(other.isRecaptcha, isRecaptcha) ||
                other.isRecaptcha == isRecaptcha));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      tosUrl,
      isEmailVerify,
      isInviteForce,
      const DeepCollectionEquality().hash(_emailWhitelistSuffix),
      isCaptcha,
      captchaType,
      recaptchaSiteKey,
      recaptchaV3SiteKey,
      recaptchaV3ScoreThreshold,
      turnstileSiteKey,
      appDescription,
      appUrl,
      logo,
      isRecaptcha);

  /// Create a copy of ConfigModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConfigModelImplCopyWith<_$ConfigModelImpl> get copyWith =>
      __$$ConfigModelImplCopyWithImpl<_$ConfigModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ConfigModelImplToJson(
      this,
    );
  }
}

abstract class _ConfigModel implements ConfigModel {
  const factory _ConfigModel(
      {@JsonKey(name: 'tos_url') final String? tosUrl,
      @JsonKey(
          name: 'is_email_verify', fromJson: _intToBoolSafe, toJson: _boolToInt)
      final bool isEmailVerify,
      @JsonKey(
          name: 'is_invite_force', fromJson: _intToBoolSafe, toJson: _boolToInt)
      final bool isInviteForce,
      @JsonKey(
          name: 'email_whitelist_suffix',
          fromJson: _emailWhitelistFromJson,
          toJson: _emailWhitelistToJson)
      final List<String> emailWhitelistSuffix,
      @JsonKey(name: 'is_captcha', fromJson: _intToBoolSafe, toJson: _boolToInt)
      final bool isCaptcha,
      @JsonKey(name: 'captcha_type') final String captchaType,
      @JsonKey(name: 'recaptcha_site_key') final String? recaptchaSiteKey,
      @JsonKey(name: 'recaptcha_v3_site_key') final String? recaptchaV3SiteKey,
      @JsonKey(name: 'recaptcha_v3_score_threshold')
      final double recaptchaV3ScoreThreshold,
      @JsonKey(name: 'turnstile_site_key') final String? turnstileSiteKey,
      @JsonKey(name: 'app_description') final String appDescription,
      @JsonKey(name: 'app_url') final String appUrl,
      final String? logo,
      @JsonKey(
          name: 'is_recaptcha', fromJson: _intToBoolSafe, toJson: _boolToInt)
      final bool isRecaptcha}) = _$ConfigModelImpl;

  factory _ConfigModel.fromJson(Map<String, dynamic> json) =
      _$ConfigModelImpl.fromJson;

  @override
  @JsonKey(name: 'tos_url')
  String? get tosUrl;
  @override
  @JsonKey(
      name: 'is_email_verify', fromJson: _intToBoolSafe, toJson: _boolToInt)
  bool get isEmailVerify;
  @override
  @JsonKey(
      name: 'is_invite_force', fromJson: _intToBoolSafe, toJson: _boolToInt)
  bool get isInviteForce;
  @override
  @JsonKey(
      name: 'email_whitelist_suffix',
      fromJson: _emailWhitelistFromJson,
      toJson: _emailWhitelistToJson)
  List<String> get emailWhitelistSuffix;
  @override
  @JsonKey(name: 'is_captcha', fromJson: _intToBoolSafe, toJson: _boolToInt)
  bool get isCaptcha;
  @override
  @JsonKey(name: 'captcha_type')
  String get captchaType;
  @override
  @JsonKey(name: 'recaptcha_site_key')
  String? get recaptchaSiteKey;
  @override
  @JsonKey(name: 'recaptcha_v3_site_key')
  String? get recaptchaV3SiteKey;
  @override
  @JsonKey(name: 'recaptcha_v3_score_threshold')
  double get recaptchaV3ScoreThreshold;
  @override
  @JsonKey(name: 'turnstile_site_key')
  String? get turnstileSiteKey;
  @override
  @JsonKey(name: 'app_description')
  String get appDescription;
  @override
  @JsonKey(name: 'app_url')
  String get appUrl;
  @override
  String? get logo;
  @override
  @JsonKey(name: 'is_recaptcha', fromJson: _intToBoolSafe, toJson: _boolToInt)
  bool get isRecaptcha;

  /// Create a copy of ConfigModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConfigModelImplCopyWith<_$ConfigModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
