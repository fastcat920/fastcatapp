import 'package:fl_clash/xboard/features/auth/services/device_identity_service.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

/// Gateway-backed, one-time QR authorization.  The QR has no account token;
/// the target keeps [pollToken] and the signed-in phone approves the challenge.
class QrLoginChallenge {
  const QrLoginChallenge({
    required this.id,
    required this.pollToken,
    required this.qrData,
    required this.expiresAt,
  });

  final String id;
  final String pollToken;
  final String qrData;
  final DateTime expiresAt;
}

class QrLoginResult {
  const QrLoginResult({required this.token, required this.email});
  final String token;
  final String email;
}

class QrLoginExpiredException implements Exception {
  const QrLoginExpiredException();
}

class QrLoginService {
  QrLoginService._();

  static Future<QrLoginChallenge> create() async {
    final sdk = XBoardSDK.instance;
    final payload = await XBoardDeviceIdentityService.buildLoginPayload();
    final response = await sdk.httpService.postRequest(
      '/auth/qr/sessions',
      payload,
    );
    final data = Map<String, dynamic>.from(response['data'] as Map);
    final expiresAt = DateTime.tryParse((data['expires_at'] ?? '').toString());
    return QrLoginChallenge(
      id: data['id'] as String,
      pollToken: data['poll_token'] as String,
      qrData: data['qr_data'] as String,
      expiresAt: expiresAt?.toUtc() ??
          DateTime.now().toUtc().add(const Duration(minutes: 2)),
    );
  }

  static Future<void> cancel(QrLoginChallenge challenge) async {
    await XBoardSDK.instance.httpService.deleteRequest(
      '/auth/qr/sessions/${challenge.id}?poll_token=${Uri.encodeQueryComponent(challenge.pollToken)}',
    );
  }

  static Future<QrLoginResult?> poll(QrLoginChallenge challenge) async {
    final response = await XBoardSDK.instance.httpService.getRequest(
      '/auth/qr/sessions/${challenge.id}?poll_token=${Uri.encodeQueryComponent(challenge.pollToken)}',
    );
    final data = Map<String, dynamic>.from(response['data'] as Map);
    if (data['status'] == 'expired') {
      throw const QrLoginExpiredException();
    }
    if (data['status'] != 'approved') return null;
    final login = Map<String, dynamic>.from(data['login'] as Map);
    final token = (login['auth_data'] ?? login['token'] ?? '').toString();
    if (token.isEmpty) throw StateError('扫码登录响应缺少登录凭证');
    return QrLoginResult(
        token: token, email: (login['email'] ?? '').toString());
  }

  static ScannedQrLoginChallenge parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme != 'fastcat' ||
        uri.host != 'login' ||
        uri.path != '/qr') {
      throw const FormatException('请扫描快猫电脑或电视上的登录二维码');
    }
    final id = uri.queryParameters['challenge']?.trim() ?? '';
    if (id.isEmpty) throw const FormatException('登录二维码无效');
    return ScannedQrLoginChallenge(id);
  }

  static Future<Map<String, dynamic>> approve(String challengeID) async {
    final token = await XBoardSDK.instance.getToken();
    if (token == null || token.isEmpty) throw StateError('请先登录账号');
    return XBoardSDK.instance.httpService.postRequest(
      '/auth/qr/sessions/$challengeID',
      const {},
      headers: {'Authorization': token},
    );
  }
}

class ScannedQrLoginChallenge {
  const ScannedQrLoginChallenge(this.id);
  final String id;
}
