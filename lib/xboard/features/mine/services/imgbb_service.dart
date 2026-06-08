import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// ImgBB 图床上传服务
///
/// 使用方式：在远程配置中设置 ticket.imgbb_api_key，
/// 前往 https://imgbb.com 注册并获取 API Key。
class ImgBBService {
  static const String _apiUrl = 'https://api.imgbb.com/1/upload';

  final String apiKey;

  const ImgBBService(this.apiKey);

  bool get isEnabled => apiKey.isNotEmpty;

  /// 上传图片文件到 ImgBB，返回图片托管 URL
  Future<String> uploadImage(File file) async {
    if (!isEnabled) throw Exception('图片上传未配置（请在远程配置中设置 ticket.imgbb_api_key）');

    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw Exception('图片不能超过 5MB');
    }

    final base64Image = base64Encode(bytes);

    final response = await http
        .post(
          Uri.parse('$_apiUrl?key=$apiKey'),
          body: {'image': base64Image},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        return json['data']['url'] as String;
      }
      final errorMsg =
          (json['error'] as Map<String, dynamic>?)?['message'] as String? ??
              '上传失败';
      throw Exception(errorMsg);
    }
    throw Exception('上传失败 (HTTP ${response.statusCode})');
  }
}
