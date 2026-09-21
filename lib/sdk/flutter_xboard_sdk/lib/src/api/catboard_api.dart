import '../core/http/http_service.dart';
import '../core/exceptions/xboard_exceptions.dart';
import 'models/catboard_model.dart';

class CatboardApi {
  final HttpService _http;

  CatboardApi(this._http);

  Future<CatboardFeatures> getFeatures() async {
    final response = await _http.getRequest('/user/comm/config');
    final data = _asMap(response['data']);
    return CatboardFeatures.fromJson(_asMap(data['features']));
  }

  Future<List<CatboardCoupon>> getCouponWallet() async {
    final response = await _http.getRequest('/user/coupon/wallet');
    return _asList(response['data']).map(CatboardCoupon.fromJson).toList();
  }

  Future<CatboardOrderPreview> previewOrder({
    required int planId,
    required String period,
    int? userCouponId,
    bool disableAutoCoupon = false,
  }) async {
    final response = await _http.postRequest('/user/order/preview', {
      'plan_id': planId,
      'period': period,
      if (userCouponId != null) 'user_coupon_id': userCouponId,
      'disable_auto_coupon': disableAutoCoupon,
    });
    return CatboardOrderPreview.fromJson(_asMap(response['data']));
  }

  Future<String> createOrder({
    required int planId,
    required String period,
    int? userCouponId,
    bool disableAutoCoupon = false,
  }) async {
    final response = await _http.postRequest('/user/order/save', {
      'plan_id': planId,
      'period': period,
      if (userCouponId != null) 'user_coupon_id': userCouponId,
      'disable_auto_coupon': disableAutoCoupon,
    });
    return response['data']?.toString() ?? '';
  }

  Future<CatboardPagedResult<CatboardLedgerEntry>> getBalanceRecords({
    int current = 1,
  }) async {
    final response =
        await _http.getRequest('/user/balance/records?current=$current');
    final items =
        _asList(response['data']).map(CatboardLedgerEntry.fromJson).toList();
    return CatboardPagedResult(
      items: items,
      total: _int(response['total']),
      current: _int(response['current'], current),
      pageSize: _int(response['pageSize'], 10),
    );
  }

  Future<CatboardPagedResult<CatboardLedgerEntry>> getCommissionRecords({
    int current = 1,
    int pageSize = 20,
    String? type,
  }) async {
    final query = StringBuffer(
      '/user/invite/ledger?current=$current&page_size=$pageSize',
    );
    if (type != null && type.isNotEmpty) query.write('&type=$type');
    late Map<String, dynamic> response;
    try {
      response = await _http.getRequest(query.toString());
    } on ApiException catch (error) {
      if (error.code != 404) rethrow;
      final legacyQuery = StringBuffer(
        '/user/invite/details?current=$current&page_size=$pageSize',
      );
      if (type != null && type.isNotEmpty) legacyQuery.write('&type=$type');
      response = await _http.getRequest(legacyQuery.toString());
    }
    final items =
        _asList(response['data']).map(CatboardLedgerEntry.fromJson).toList();
    return CatboardPagedResult(
      items: items,
      total: _int(response['total']),
      current: current,
      pageSize: pageSize,
    );
  }

  Future<CatboardPagedResult<CatboardInviteUser>> getInviteUsers({
    int current = 1,
    int pageSize = 20,
  }) async {
    final response = await _http.getRequest(
      '/user/invite/users?current=$current&page_size=$pageSize',
    );
    final items =
        _asList(response['data']).map(CatboardInviteUser.fromJson).toList();
    return CatboardPagedResult(
      items: items,
      total: _int(response['total']),
      current: current,
      pageSize: pageSize,
    );
  }

  Future<CatboardReferralProgram?> getReferralProgram() async {
    late Map<String, dynamic> response;
    try {
      response = await _http.getRequest('/user/invite/program');
    } on ApiException catch (error) {
      if (error.code != 404) rethrow;
      response = await _http.getRequest('/user/invite/fetch');
    }
    final data = _asMap(response['data']);
    final program = _asMap(data['program']);
    return program.isEmpty ? null : CatboardReferralProgram.fromJson(program);
  }

  static int _int(dynamic value, [int fallback = 0]) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? fallback;

  static Map<String, dynamic> _asMap(dynamic value) => value is Map
      ? value.map((key, item) => MapEntry(key.toString(), item))
      : <String, dynamic>{};

  static List<Map<String, dynamic>> _asList(dynamic value) => value is List
      ? value.map(_asMap).where((item) => item.isNotEmpty).toList()
      : const [];
}
