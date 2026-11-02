/// Simple localization support for TGO Widget
class TgoLocalizations {
  final String locale;

  const TgoLocalizations({this.locale = 'en'});

  /// Get localized string
  String get(String key) {
    final strings = locale.startsWith('zh') ? _zhStrings : _enStrings;
    return strings[key] ?? key;
  }

  static const Map<String, String> _enStrings = {
    'mute_sound': 'Mute message sound',
    'enable_sound': 'Enable message sound',
    'sending': 'Sending...',
    'sent': 'Sent',
    'read': 'Read',
    'failed': 'Failed',
    'send_error_auth': 'Authentication failed',
    'send_error_user': 'Visitor account is unavailable',
    'send_error_channel': 'This chat is unavailable',
    'send_error_format': 'Message format is invalid',
    'send_error_permission': 'You are not allowed to send messages here',
    'send_error_rate_limit': 'Too many messages. Try again shortly',
    'retry': 'Retry',
    'delete': 'Delete',
    'cancel': 'Cancel',
    'uploading': 'Uploading',
    'upload_failed': 'Upload failed',
    'loading_history': 'Loading history...',
    'load_history_failed': 'Failed to load history',
    'no_more_messages': 'No more messages',
    'type_message': 'Type a message...',
    'send': 'Send',
    'attach': 'Attach',
    'emoji': 'Emoji',
    'interrupt': 'Stop',
    'just_now': 'Just now',
    'yesterday': 'Yesterday',
    'file_too_large': 'File too large (max {size}MB): {name}',
    'connection_error': 'Connection error',
    'auth_failed': 'Authentication failed',
    'network_error': 'Network error',
    'system_error': 'System error',
    'gallery': 'Gallery',
    'camera': 'Camera',
    'files': 'Files',
  };

  static const Map<String, String> _zhStrings = {
    'mute_sound': '关闭消息声音',
    'enable_sound': '开启消息声音',
    'sending': '发送中...',
    'sent': '已发送',
    'read': '已读',
    'failed': '发送失败',
    'send_error_auth': '连接认证失败，请稍后重试',
    'send_error_user': '访客账号不可用，请重新打开客服窗口',
    'send_error_channel': '客服会话不可用，请重新打开窗口',
    'send_error_format': '消息格式不受支持',
    'send_error_permission': '当前会话不允许发送消息',
    'send_error_rate_limit': '发送过于频繁，请稍后重试',
    'retry': '重试',
    'delete': '删除',
    'cancel': '取消',
    'uploading': '上传中',
    'upload_failed': '上传失败',
    'loading_history': '加载历史消息...',
    'load_history_failed': '加载历史消息失败',
    'no_more_messages': '没有更多消息',
    'type_message': '提出问题...',
    'send': '发送',
    'attach': '附件',
    'emoji': '表情',
    'interrupt': '停止',
    'just_now': '刚刚',
    'yesterday': '昨天',
    'file_too_large': '文件过大（最大 {size}MB）：{name}',
    'connection_error': '连接错误',
    'auth_failed': '认证失败',
    'network_error': '网络错误',
    'system_error': '系统错误',
    'gallery': '相册',
    'camera': '相机',
    'files': '文件',
  };
}
