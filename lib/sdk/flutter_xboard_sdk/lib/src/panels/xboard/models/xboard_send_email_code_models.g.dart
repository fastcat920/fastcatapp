// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'xboard_send_email_code_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VerificationCodeResponseImpl _$$VerificationCodeResponseImplFromJson(
        Map<String, dynamic> json) =>
    _$VerificationCodeResponseImpl(
      success: json['success'] as bool,
      message: json['message'] as String?,
    );

Map<String, dynamic> _$$VerificationCodeResponseImplToJson(
        _$VerificationCodeResponseImpl instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
    };
