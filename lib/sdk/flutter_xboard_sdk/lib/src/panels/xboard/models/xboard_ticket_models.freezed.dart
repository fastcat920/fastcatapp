// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'xboard_ticket_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Ticket _$TicketFromJson(Map<String, dynamic> json) {
  return _Ticket.fromJson(json);
}

/// @nodoc
mixin _$Ticket {
  int get id => throw _privateConstructorUsedError;
  int get level => throw _privateConstructorUsedError; // 优先级: 0=低, 1=中, 2=高
  @JsonKey(name: 'reply_status')
  int get replyStatus =>
      throw _privateConstructorUsedError; // 回复状态: 0=已回复, 1=等待回复
  int get status => throw _privateConstructorUsedError; // 工单状态: 0=处理中, 1=已关闭
  String get subject => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  int get userId => throw _privateConstructorUsedError;

  /// Serializes this Ticket to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Ticket
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TicketCopyWith<Ticket> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TicketCopyWith<$Res> {
  factory $TicketCopyWith(Ticket value, $Res Function(Ticket) then) =
      _$TicketCopyWithImpl<$Res, Ticket>;
  @useResult
  $Res call(
      {int id,
      int level,
      @JsonKey(name: 'reply_status') int replyStatus,
      int status,
      String subject,
      String? message,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime updatedAt,
      @JsonKey(name: 'user_id') int userId});
}

/// @nodoc
class _$TicketCopyWithImpl<$Res, $Val extends Ticket>
    implements $TicketCopyWith<$Res> {
  _$TicketCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Ticket
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? level = null,
    Object? replyStatus = null,
    Object? status = null,
    Object? subject = null,
    Object? message = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? userId = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
      replyStatus: null == replyStatus
          ? _value.replyStatus
          : replyStatus // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as int,
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TicketImplCopyWith<$Res> implements $TicketCopyWith<$Res> {
  factory _$$TicketImplCopyWith(
          _$TicketImpl value, $Res Function(_$TicketImpl) then) =
      __$$TicketImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      int level,
      @JsonKey(name: 'reply_status') int replyStatus,
      int status,
      String subject,
      String? message,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime updatedAt,
      @JsonKey(name: 'user_id') int userId});
}

/// @nodoc
class __$$TicketImplCopyWithImpl<$Res>
    extends _$TicketCopyWithImpl<$Res, _$TicketImpl>
    implements _$$TicketImplCopyWith<$Res> {
  __$$TicketImplCopyWithImpl(
      _$TicketImpl _value, $Res Function(_$TicketImpl) _then)
      : super(_value, _then);

  /// Create a copy of Ticket
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? level = null,
    Object? replyStatus = null,
    Object? status = null,
    Object? subject = null,
    Object? message = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? userId = null,
  }) {
    return _then(_$TicketImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
      replyStatus: null == replyStatus
          ? _value.replyStatus
          : replyStatus // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as int,
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TicketImpl implements _Ticket {
  const _$TicketImpl(
      {required this.id,
      required this.level,
      @JsonKey(name: 'reply_status') required this.replyStatus,
      required this.status,
      required this.subject,
      this.message,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required this.createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required this.updatedAt,
      @JsonKey(name: 'user_id') required this.userId});

  factory _$TicketImpl.fromJson(Map<String, dynamic> json) =>
      _$$TicketImplFromJson(json);

  @override
  final int id;
  @override
  final int level;
// 优先级: 0=低, 1=中, 2=高
  @override
  @JsonKey(name: 'reply_status')
  final int replyStatus;
// 回复状态: 0=已回复, 1=等待回复
  @override
  final int status;
// 工单状态: 0=处理中, 1=已关闭
  @override
  final String subject;
  @override
  final String? message;
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime createdAt;
  @override
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime updatedAt;
  @override
  @JsonKey(name: 'user_id')
  final int userId;

  @override
  String toString() {
    return 'Ticket(id: $id, level: $level, replyStatus: $replyStatus, status: $status, subject: $subject, message: $message, createdAt: $createdAt, updatedAt: $updatedAt, userId: $userId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TicketImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.level, level) || other.level == level) &&
            (identical(other.replyStatus, replyStatus) ||
                other.replyStatus == replyStatus) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.subject, subject) || other.subject == subject) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.userId, userId) || other.userId == userId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, level, replyStatus, status,
      subject, message, createdAt, updatedAt, userId);

  /// Create a copy of Ticket
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TicketImplCopyWith<_$TicketImpl> get copyWith =>
      __$$TicketImplCopyWithImpl<_$TicketImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TicketImplToJson(
      this,
    );
  }
}

abstract class _Ticket implements Ticket {
  const factory _Ticket(
      {required final int id,
      required final int level,
      @JsonKey(name: 'reply_status') required final int replyStatus,
      required final int status,
      required final String subject,
      final String? message,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required final DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required final DateTime updatedAt,
      @JsonKey(name: 'user_id') required final int userId}) = _$TicketImpl;

  factory _Ticket.fromJson(Map<String, dynamic> json) = _$TicketImpl.fromJson;

  @override
  int get id;
  @override
  int get level; // 优先级: 0=低, 1=中, 2=高
  @override
  @JsonKey(name: 'reply_status')
  int get replyStatus; // 回复状态: 0=已回复, 1=等待回复
  @override
  int get status; // 工单状态: 0=处理中, 1=已关闭
  @override
  String get subject;
  @override
  String? get message;
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get createdAt;
  @override
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get updatedAt;
  @override
  @JsonKey(name: 'user_id')
  int get userId;

  /// Create a copy of Ticket
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TicketImplCopyWith<_$TicketImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TicketMessage _$TicketMessageFromJson(Map<String, dynamic> json) {
  return _TicketMessage.fromJson(json);
}

/// @nodoc
mixin _$TicketMessage {
  int get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'ticket_id')
  int get ticketId => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_me')
  bool get isMe => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this TicketMessage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TicketMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TicketMessageCopyWith<TicketMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TicketMessageCopyWith<$Res> {
  factory $TicketMessageCopyWith(
          TicketMessage value, $Res Function(TicketMessage) then) =
      _$TicketMessageCopyWithImpl<$Res, TicketMessage>;
  @useResult
  $Res call(
      {int id,
      @JsonKey(name: 'ticket_id') int ticketId,
      @JsonKey(name: 'is_me') bool isMe,
      String message,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime updatedAt});
}

/// @nodoc
class _$TicketMessageCopyWithImpl<$Res, $Val extends TicketMessage>
    implements $TicketMessageCopyWith<$Res> {
  _$TicketMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TicketMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ticketId = null,
    Object? isMe = null,
    Object? message = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      ticketId: null == ticketId
          ? _value.ticketId
          : ticketId // ignore: cast_nullable_to_non_nullable
              as int,
      isMe: null == isMe
          ? _value.isMe
          : isMe // ignore: cast_nullable_to_non_nullable
              as bool,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TicketMessageImplCopyWith<$Res>
    implements $TicketMessageCopyWith<$Res> {
  factory _$$TicketMessageImplCopyWith(
          _$TicketMessageImpl value, $Res Function(_$TicketMessageImpl) then) =
      __$$TicketMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      @JsonKey(name: 'ticket_id') int ticketId,
      @JsonKey(name: 'is_me') bool isMe,
      String message,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime updatedAt});
}

/// @nodoc
class __$$TicketMessageImplCopyWithImpl<$Res>
    extends _$TicketMessageCopyWithImpl<$Res, _$TicketMessageImpl>
    implements _$$TicketMessageImplCopyWith<$Res> {
  __$$TicketMessageImplCopyWithImpl(
      _$TicketMessageImpl _value, $Res Function(_$TicketMessageImpl) _then)
      : super(_value, _then);

  /// Create a copy of TicketMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ticketId = null,
    Object? isMe = null,
    Object? message = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$TicketMessageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      ticketId: null == ticketId
          ? _value.ticketId
          : ticketId // ignore: cast_nullable_to_non_nullable
              as int,
      isMe: null == isMe
          ? _value.isMe
          : isMe // ignore: cast_nullable_to_non_nullable
              as bool,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TicketMessageImpl implements _TicketMessage {
  const _$TicketMessageImpl(
      {required this.id,
      @JsonKey(name: 'ticket_id') required this.ticketId,
      @JsonKey(name: 'is_me') required this.isMe,
      required this.message,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required this.createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required this.updatedAt});

  factory _$TicketMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$TicketMessageImplFromJson(json);

  @override
  final int id;
  @override
  @JsonKey(name: 'ticket_id')
  final int ticketId;
  @override
  @JsonKey(name: 'is_me')
  final bool isMe;
  @override
  final String message;
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime createdAt;
  @override
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime updatedAt;

  @override
  String toString() {
    return 'TicketMessage(id: $id, ticketId: $ticketId, isMe: $isMe, message: $message, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TicketMessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.ticketId, ticketId) ||
                other.ticketId == ticketId) &&
            (identical(other.isMe, isMe) || other.isMe == isMe) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, ticketId, isMe, message, createdAt, updatedAt);

  /// Create a copy of TicketMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TicketMessageImplCopyWith<_$TicketMessageImpl> get copyWith =>
      __$$TicketMessageImplCopyWithImpl<_$TicketMessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TicketMessageImplToJson(
      this,
    );
  }
}

abstract class _TicketMessage implements TicketMessage {
  const factory _TicketMessage(
      {required final int id,
      @JsonKey(name: 'ticket_id') required final int ticketId,
      @JsonKey(name: 'is_me') required final bool isMe,
      required final String message,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required final DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required final DateTime updatedAt}) = _$TicketMessageImpl;

  factory _TicketMessage.fromJson(Map<String, dynamic> json) =
      _$TicketMessageImpl.fromJson;

  @override
  int get id;
  @override
  @JsonKey(name: 'ticket_id')
  int get ticketId;
  @override
  @JsonKey(name: 'is_me')
  bool get isMe;
  @override
  String get message;
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get createdAt;
  @override
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get updatedAt;

  /// Create a copy of TicketMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TicketMessageImplCopyWith<_$TicketMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TicketDetail _$TicketDetailFromJson(Map<String, dynamic> json) {
  return _TicketDetail.fromJson(json);
}

/// @nodoc
mixin _$TicketDetail {
  int get id => throw _privateConstructorUsedError;
  int get level => throw _privateConstructorUsedError;
  @JsonKey(name: 'reply_status')
  int get replyStatus => throw _privateConstructorUsedError;
  int get status => throw _privateConstructorUsedError;
  String get subject => throw _privateConstructorUsedError;
  List<TicketMessage> get messages => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  int get userId => throw _privateConstructorUsedError;

  /// Serializes this TicketDetail to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TicketDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TicketDetailCopyWith<TicketDetail> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TicketDetailCopyWith<$Res> {
  factory $TicketDetailCopyWith(
          TicketDetail value, $Res Function(TicketDetail) then) =
      _$TicketDetailCopyWithImpl<$Res, TicketDetail>;
  @useResult
  $Res call(
      {int id,
      int level,
      @JsonKey(name: 'reply_status') int replyStatus,
      int status,
      String subject,
      List<TicketMessage> messages,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime updatedAt,
      @JsonKey(name: 'user_id') int userId});
}

/// @nodoc
class _$TicketDetailCopyWithImpl<$Res, $Val extends TicketDetail>
    implements $TicketDetailCopyWith<$Res> {
  _$TicketDetailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TicketDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? level = null,
    Object? replyStatus = null,
    Object? status = null,
    Object? subject = null,
    Object? messages = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? userId = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
      replyStatus: null == replyStatus
          ? _value.replyStatus
          : replyStatus // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as int,
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      messages: null == messages
          ? _value.messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<TicketMessage>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TicketDetailImplCopyWith<$Res>
    implements $TicketDetailCopyWith<$Res> {
  factory _$$TicketDetailImplCopyWith(
          _$TicketDetailImpl value, $Res Function(_$TicketDetailImpl) then) =
      __$$TicketDetailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      int level,
      @JsonKey(name: 'reply_status') int replyStatus,
      int status,
      String subject,
      List<TicketMessage> messages,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime updatedAt,
      @JsonKey(name: 'user_id') int userId});
}

/// @nodoc
class __$$TicketDetailImplCopyWithImpl<$Res>
    extends _$TicketDetailCopyWithImpl<$Res, _$TicketDetailImpl>
    implements _$$TicketDetailImplCopyWith<$Res> {
  __$$TicketDetailImplCopyWithImpl(
      _$TicketDetailImpl _value, $Res Function(_$TicketDetailImpl) _then)
      : super(_value, _then);

  /// Create a copy of TicketDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? level = null,
    Object? replyStatus = null,
    Object? status = null,
    Object? subject = null,
    Object? messages = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? userId = null,
  }) {
    return _then(_$TicketDetailImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
      replyStatus: null == replyStatus
          ? _value.replyStatus
          : replyStatus // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as int,
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      messages: null == messages
          ? _value._messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<TicketMessage>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TicketDetailImpl implements _TicketDetail {
  const _$TicketDetailImpl(
      {required this.id,
      required this.level,
      @JsonKey(name: 'reply_status') required this.replyStatus,
      required this.status,
      required this.subject,
      final List<TicketMessage> messages = const [],
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required this.createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required this.updatedAt,
      @JsonKey(name: 'user_id') required this.userId})
      : _messages = messages;

  factory _$TicketDetailImpl.fromJson(Map<String, dynamic> json) =>
      _$$TicketDetailImplFromJson(json);

  @override
  final int id;
  @override
  final int level;
  @override
  @JsonKey(name: 'reply_status')
  final int replyStatus;
  @override
  final int status;
  @override
  final String subject;
  final List<TicketMessage> _messages;
  @override
  @JsonKey()
  List<TicketMessage> get messages {
    if (_messages is EqualUnmodifiableListView) return _messages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_messages);
  }

  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime createdAt;
  @override
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime updatedAt;
  @override
  @JsonKey(name: 'user_id')
  final int userId;

  @override
  String toString() {
    return 'TicketDetail(id: $id, level: $level, replyStatus: $replyStatus, status: $status, subject: $subject, messages: $messages, createdAt: $createdAt, updatedAt: $updatedAt, userId: $userId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TicketDetailImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.level, level) || other.level == level) &&
            (identical(other.replyStatus, replyStatus) ||
                other.replyStatus == replyStatus) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.subject, subject) || other.subject == subject) &&
            const DeepCollectionEquality().equals(other._messages, _messages) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.userId, userId) || other.userId == userId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      level,
      replyStatus,
      status,
      subject,
      const DeepCollectionEquality().hash(_messages),
      createdAt,
      updatedAt,
      userId);

  /// Create a copy of TicketDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TicketDetailImplCopyWith<_$TicketDetailImpl> get copyWith =>
      __$$TicketDetailImplCopyWithImpl<_$TicketDetailImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TicketDetailImplToJson(
      this,
    );
  }
}

abstract class _TicketDetail implements TicketDetail {
  const factory _TicketDetail(
          {required final int id,
          required final int level,
          @JsonKey(name: 'reply_status') required final int replyStatus,
          required final int status,
          required final String subject,
          final List<TicketMessage> messages,
          @JsonKey(
              name: 'created_at',
              fromJson: _fromUnixTimestamp,
              toJson: _toUnixTimestamp)
          required final DateTime createdAt,
          @JsonKey(
              name: 'updated_at',
              fromJson: _fromUnixTimestamp,
              toJson: _toUnixTimestamp)
          required final DateTime updatedAt,
          @JsonKey(name: 'user_id') required final int userId}) =
      _$TicketDetailImpl;

  factory _TicketDetail.fromJson(Map<String, dynamic> json) =
      _$TicketDetailImpl.fromJson;

  @override
  int get id;
  @override
  int get level;
  @override
  @JsonKey(name: 'reply_status')
  int get replyStatus;
  @override
  int get status;
  @override
  String get subject;
  @override
  List<TicketMessage> get messages;
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get createdAt;
  @override
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get updatedAt;
  @override
  @JsonKey(name: 'user_id')
  int get userId;

  /// Create a copy of TicketDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TicketDetailImplCopyWith<_$TicketDetailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
