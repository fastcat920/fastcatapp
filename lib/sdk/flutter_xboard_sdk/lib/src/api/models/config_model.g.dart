// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ConfigModelImpl _$$ConfigModelImplFromJson(Map<String, dynamic> json) =>
    _$ConfigModelImpl(
      tosUrl: json['tos_url'] as String?,
      isEmailVerify: json['is_email_verify'] == null
          ? false
          : _intToBoolSafe(json['is_email_verify']),
      isInviteForce: json['is_invite_force'] == null
          ? false
          : _intToBoolSafe(json['is_invite_force']),
      emailWhitelistSuffix: json['email_whitelist_suffix'] == null
          ? const []
          : _emailWhitelistFromJson(json['email_whitelist_suffix']),
      isCaptcha: json['is_captcha'] == null
          ? false
          : _intToBoolSafe(json['is_captcha']),
      captchaType: json['captcha_type'] as String? ?? '',
      recaptchaSiteKey: json['recaptcha_site_key'] as String?,
      recaptchaV3SiteKey: json['recaptcha_v3_site_key'] as String?,
      recaptchaV3ScoreThreshold:
          (json['recaptcha_v3_score_threshold'] as num?)?.toDouble() ?? 0.5,
      turnstileSiteKey: json['turnstile_site_key'] as String?,
      appDescription: json['app_description'] as String? ?? '',
      appUrl: json['app_url'] as String? ?? '',
      logo: json['logo'] as String?,
      isRecaptcha: json['is_recaptcha'] == null
          ? false
          : _intToBoolSafe(json['is_recaptcha']),
    );

Map<String, dynamic> _$$ConfigModelImplToJson(_$ConfigModelImpl instance) =>
    <String, dynamic>{
      'tos_url': instance.tosUrl,
      'is_email_verify': _boolToInt(instance.isEmailVerify),
      'is_invite_force': _boolToInt(instance.isInviteForce),
      'email_whitelist_suffix':
          _emailWhitelistToJson(instance.emailWhitelistSuffix),
      'is_captcha': _boolToInt(instance.isCaptcha),
      'captcha_type': instance.captchaType,
      'recaptcha_site_key': instance.recaptchaSiteKey,
      'recaptcha_v3_site_key': instance.recaptchaV3SiteKey,
      'recaptcha_v3_score_threshold': instance.recaptchaV3ScoreThreshold,
      'turnstile_site_key': instance.turnstileSiteKey,
      'app_description': instance.appDescription,
      'app_url': instance.appUrl,
      'logo': instance.logo,
      'is_recaptcha': _boolToInt(instance.isRecaptcha),
    };
