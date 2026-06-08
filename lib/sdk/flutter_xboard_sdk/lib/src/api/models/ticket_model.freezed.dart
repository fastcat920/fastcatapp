// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ticket_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TicketModel _$TicketModelFromJson(Map<String, dynamic> json) {
  return _TicketModel.fromJson(json);
}

/// @nodoc
mixin _$TicketModel {
  int get id => throw _privateConstructorUsedError;
  int get level => throw _privateConstructorUsedError;
  @JsonKey(name: 'reply_status')
  int get replyStatus => throw _privateConstructorUsedError;
  int get status => throw _privateConstructorUsedError;
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

  /// Serializes this TicketModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TicketModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TicketModelCopyWith<TicketModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TicketModelCopyWith<$Res> {
  factory $TicketModelCopyWith(
          TicketModel value, $Res Function(TicketModel) then) =
      _$TicketModelCopyWithImpl<$Res, TicketModel>;
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
class _$TicketModelCopyWithImpl<$Res, $Val extends TicketModel>
    implements $TicketModelCopyWith<$Res> {
  _$TicketModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TicketModel
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
abstract class _$$TicketModelImplCopyWith<$Res>
    implements $TicketModelCopyWith<$Res> {
  factory _$$TicketModelImplCopyWith(
          _$TicketModelImpl value, $Res Function(_$TicketModelImpl) then) =
      __$$TicketModelImplCopyWithImpl<$Res>;
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
class __$$TicketModelImplCopyWithImpl<$Res>
    extends _$TicketModelCopyWithImpl<$Res, _$TicketModelImpl>
    implements _$$TicketModelImplCopyWith<$Res> {
  __$$TicketModelImplCopyWithImpl(
      _$TicketModelImpl _value, $Res Function(_$TicketModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of TicketModel
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
    return _then(_$TicketModelImpl(
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
class _$TicketModelImpl implements _TicketModel {
  const _$TicketModelImpl(
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

  factory _$TicketModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$TicketModelImplFromJson(json);

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
    return 'TicketModel(id: $id, level: $level, replyStatus: $replyStatus, status: $status, subject: $subject, message: $message, createdAt: $createdAt, updatedAt: $updatedAt, userId: $userId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TicketModelImpl &&
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

  /// Create a copy of TicketModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TicketModelImplCopyWith<_$TicketModelImpl> get copyWith =>
      __$$TicketModelImplCopyWithImpl<_$TicketModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TicketModelImplToJson(
      this,
    );
  }
}

abstract class _TicketModel implements TicketModel {
  const factory _TicketModel(
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
      @JsonKey(name: 'user_id') required final int userId}) = _$TicketModelImpl;

  factory _TicketModel.fromJson(Map<String, dynamic> json) =
      _$TicketModelImpl.fromJson;

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

  /// Create a copy of TicketModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TicketModelImplCopyWith<_$TicketModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TicketMessageModel _$TicketMessageModelFromJson(Map<String, dynamic> json) {
  return _TicketMessageModel.fromJson(json);
}

/// @nodoc
mixin _$TicketMessageModel {
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

  /// Serializes this TicketMessageModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TicketMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TicketMessageModelCopyWith<TicketMessageModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TicketMessageModelCopyWith<$Res> {
  factory $TicketMessageModelCopyWith(
          TicketMessageModel value, $Res Function(TicketMessageModel) then) =
      _$TicketMessageModelCopyWithImpl<$Res, TicketMessageModel>;
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
class _$TicketMessageModelCopyWithImpl<$Res, $Val extends TicketMessageModel>
    implements $TicketMessageModelCopyWith<$Res> {
  _$TicketMessageModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TicketMessageModel
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
abstract class _$$TicketMessageModelImplCopyWith<$Res>
    implements $TicketMessageModelCopyWith<$Res> {
  factory _$$TicketMessageModelImplCopyWith(_$TicketMessageModelImpl value,
          $Res Function(_$TicketMessageModelImpl) then) =
      __$$TicketMessageModelImplCopyWithImpl<$Res>;
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
class __$$TicketMessageModelImplCopyWithImpl<$Res>
    extends _$TicketMessageModelCopyWithImpl<$Res, _$TicketMessageModelImpl>
    implements _$$TicketMessageModelImplCopyWith<$Res> {
  __$$TicketMessageModelImplCopyWithImpl(_$TicketMessageModelImpl _value,
      $Res Function(_$TicketMessageModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of TicketMessageModel
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
    return _then(_$TicketMessageModelImpl(
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
class _$TicketMessageModelImpl implements _TicketMessageModel {
  const _$TicketMessageModelImpl(
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

  factory _$TicketMessageModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$TicketMessageModelImplFromJson(json);

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
    return 'TicketMessageModel(id: $id, ticketId: $ticketId, isMe: $isMe, message: $message, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TicketMessageModelImpl &&
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

  /// Create a copy of TicketMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TicketMessageModelImplCopyWith<_$TicketMessageModelImpl> get copyWith =>
      __$$TicketMessageModelImplCopyWithImpl<_$TicketMessageModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TicketMessageModelImplToJson(
      this,
    );
  }
}

abstract class _TicketMessageModel implements TicketMessageModel {
  const factory _TicketMessageModel(
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
      required final DateTime updatedAt}) = _$TicketMessageModelImpl;

  factory _TicketMessageModel.fromJson(Map<String, dynamic> json) =
      _$TicketMessageModelImpl.fromJson;

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

  /// Create a copy of TicketMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TicketMessageModelImplCopyWith<_$TicketMessageModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TicketDetailModel _$TicketDetailModelFromJson(Map<String, dynamic> json) {
  return _TicketDetailModel.fromJson(json);
}

/// @nodoc
mixin _$TicketDetailModel {
  int get id => throw _privateConstructorUsedError;
  int get level => throw _privateConstructorUsedError;
  @JsonKey(name: 'reply_status')
  int get replyStatus => throw _privateConstructorUsedError;
  int get status => throw _privateConstructorUsedError;
  String get subject => throw _privateConstructorUsedError;
  List<TicketMessageModel> get messages => throw _privateConstructorUsedError;
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

  /// Serializes this TicketDetailModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TicketDetailModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TicketDetailModelCopyWith<TicketDetailModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TicketDetailModelCopyWith<$Res> {
  factory $TicketDetailModelCopyWith(
          TicketDetailModel value, $Res Function(TicketDetailModel) then) =
      _$TicketDetailModelCopyWithImpl<$Res, TicketDetailModel>;
  @useResult
  $Res call(
      {int id,
      int level,
      @JsonKey(name: 'reply_status') int replyStatus,
      int status,
      String subject,
      List<TicketMessageModel> messages,
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
class _$TicketDetailModelCopyWithImpl<$Res, $Val extends TicketDetailModel>
    implements $TicketDetailModelCopyWith<$Res> {
  _$TicketDetailModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TicketDetailModel
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
              as List<TicketMessageModel>,
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
abstract class _$$TicketDetailModelImplCopyWith<$Res>
    implements $TicketDetailModelCopyWith<$Res> {
  factory _$$TicketDetailModelImplCopyWith(_$TicketDetailModelImpl value,
          $Res Function(_$TicketDetailModelImpl) then) =
      __$$TicketDetailModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      int level,
      @JsonKey(name: 'reply_status') int replyStatus,
      int status,
      String subject,
      List<TicketMessageModel> messages,
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
class __$$TicketDetailModelImplCopyWithImpl<$Res>
    extends _$TicketDetailModelCopyWithImpl<$Res, _$TicketDetailModelImpl>
    implements _$$TicketDetailModelImplCopyWith<$Res> {
  __$$TicketDetailModelImplCopyWithImpl(_$TicketDetailModelImpl _value,
      $Res Function(_$TicketDetailModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of TicketDetailModel
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
    return _then(_$TicketDetailModelImpl(
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
              as List<TicketMessageModel>,
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
class _$TicketDetailModelImpl implements _TicketDetailModel {
  const _$TicketDetailModelImpl(
      {required this.id,
      required this.level,
      @JsonKey(name: 'reply_status') required this.replyStatus,
      required this.status,
      required this.subject,
      final List<TicketMessageModel> messages = const [],
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

  factory _$TicketDetailModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$TicketDetailModelImplFromJson(json);

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
  final List<TicketMessageModel> _messages;
  @override
  @JsonKey()
  List<TicketMessageModel> get messages {
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
    return 'TicketDetailModel(id: $id, level: $level, replyStatus: $replyStatus, status: $status, subject: $subject, messages: $messages, createdAt: $createdAt, updatedAt: $updatedAt, userId: $userId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TicketDetailModelImpl &&
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

  /// Create a copy of TicketDetailModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TicketDetailModelImplCopyWith<_$TicketDetailModelImpl> get copyWith =>
      __$$TicketDetailModelImplCopyWithImpl<_$TicketDetailModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TicketDetailModelImplToJson(
      this,
    );
  }
}

abstract class _TicketDetailModel implements TicketDetailModel {
  const factory _TicketDetailModel(
          {required final int id,
          required final int level,
          @JsonKey(name: 'reply_status') required final int replyStatus,
          required final int status,
          required final String subject,
          final List<TicketMessageModel> messages,
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
      _$TicketDetailModelImpl;

  factory _TicketDetailModel.fromJson(Map<String, dynamic> json) =
      _$TicketDetailModelImpl.fromJson;

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
  List<TicketMessageModel> get messages;
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

  /// Create a copy of TicketDetailModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TicketDetailModelImplCopyWith<_$TicketDetailModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
