// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TicketModelImpl _$$TicketModelImplFromJson(Map<String, dynamic> json) =>
    _$TicketModelImpl(
      id: (json['id'] as num).toInt(),
      level: (json['level'] as num).toInt(),
      replyStatus: (json['reply_status'] as num).toInt(),
      status: (json['status'] as num).toInt(),
      subject: json['subject'] as String,
      message: json['message'] as String?,
      createdAt: _fromUnixTimestamp((json['created_at'] as num).toInt()),
      updatedAt: _fromUnixTimestamp((json['updated_at'] as num).toInt()),
      userId: (json['user_id'] as num).toInt(),
    );

Map<String, dynamic> _$$TicketModelImplToJson(_$TicketModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'level': instance.level,
      'reply_status': instance.replyStatus,
      'status': instance.status,
      'subject': instance.subject,
      'message': instance.message,
      'created_at': _toUnixTimestamp(instance.createdAt),
      'updated_at': _toUnixTimestamp(instance.updatedAt),
      'user_id': instance.userId,
    };

_$TicketMessageModelImpl _$$TicketMessageModelImplFromJson(
        Map<String, dynamic> json) =>
    _$TicketMessageModelImpl(
      id: (json['id'] as num).toInt(),
      ticketId: (json['ticket_id'] as num).toInt(),
      isMe: json['is_me'] as bool,
      message: json['message'] as String,
      createdAt: _fromUnixTimestamp((json['created_at'] as num).toInt()),
      updatedAt: _fromUnixTimestamp((json['updated_at'] as num).toInt()),
    );

Map<String, dynamic> _$$TicketMessageModelImplToJson(
        _$TicketMessageModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ticket_id': instance.ticketId,
      'is_me': instance.isMe,
      'message': instance.message,
      'created_at': _toUnixTimestamp(instance.createdAt),
      'updated_at': _toUnixTimestamp(instance.updatedAt),
    };

_$TicketDetailModelImpl _$$TicketDetailModelImplFromJson(
        Map<String, dynamic> json) =>
    _$TicketDetailModelImpl(
      id: (json['id'] as num).toInt(),
      level: (json['level'] as num).toInt(),
      replyStatus: (json['reply_status'] as num).toInt(),
      status: (json['status'] as num).toInt(),
      subject: json['subject'] as String,
      messages: (json['messages'] as List<dynamic>?)
              ?.map(
                  (e) => TicketMessageModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: _fromUnixTimestamp((json['created_at'] as num).toInt()),
      updatedAt: _fromUnixTimestamp((json['updated_at'] as num).toInt()),
      userId: (json['user_id'] as num).toInt(),
    );

Map<String, dynamic> _$$TicketDetailModelImplToJson(
        _$TicketDetailModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'level': instance.level,
      'reply_status': instance.replyStatus,
      'status': instance.status,
      'subject': instance.subject,
      'messages': instance.messages,
      'created_at': _toUnixTimestamp(instance.createdAt),
      'updated_at': _toUnixTimestamp(instance.updatedAt),
      'user_id': instance.userId,
    };
