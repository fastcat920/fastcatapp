class FastCatMessage {
  const FastCatMessage({
    required this.id,
    required this.visitorId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.streaming = false,
  });
  final String id;
  final String visitorId;
  final String role;
  final String content;
  final DateTime? createdAt;
  final bool streaming;
  factory FastCatMessage.fromJson(Map<String, dynamic> json) => FastCatMessage(
        id: '${json['id'] ?? ''}',
        visitorId: '${json['visitor_id'] ?? ''}',
        role: '${json['role'] ?? 'ai'}',
        content: '${json['content'] ?? ''}',
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
        streaming: json['streaming'] == true,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'visitor_id': visitorId,
        'role': role,
        'content': content,
        'created_at': createdAt?.toIso8601String(),
        'streaming': false,
      };
  FastCatMessage copyWith({String? content, bool? streaming}) => FastCatMessage(
        id: id,
        visitorId: visitorId,
        role: role,
        content: content ?? this.content,
        createdAt: createdAt,
        streaming: streaming ?? this.streaming,
      );
}

class FastCatProfile {
  const FastCatProfile({
    this.name,
    this.nickname,
    this.email,
    this.phone,
    this.systemInfo = const {},
  });
  final String? name;
  final String? nickname;
  final String? email;
  final String? phone;
  final Map<String, dynamic> systemInfo;
  Map<String, dynamic> toJson() => {
        'name': name,
        'nickname': nickname,
        'email': email,
        'phone': phone,
        'platform': 'flutter',
        'system_info': systemInfo,
      }..removeWhere((_, value) => value == null);
}
