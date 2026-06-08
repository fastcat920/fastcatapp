import '../../../core/http/http_service.dart';
import '../../../core/exceptions/xboard_exceptions.dart';
import '../../../core/models/api_response.dart';
import '../../../core/models/response_list_parser.dart';
import '../../xboard/models/xboard_ticket_models.dart';

/// V2Board 工单 API 实现
class V2BoardTicketApi {
  final HttpService _httpService;

  V2BoardTicketApi(this._httpService);

  Future<ApiResponse<List<Ticket>>> fetchTickets() async {
    try {
      final result = await _httpService.getRequest('/user/ticket/fetch');
      return ApiResponse(
        success: true,
        data: parseResponseMapList(
          result,
          listKeys: const ['data', 'tickets', 'items', 'list', 'records'],
        ).map(Ticket.fromJson).toList(),
        message: result['message'] as String?,
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 获取工单列表失败: $e');
    }
  }

  Future<ApiResponse<TicketDetail>> getTicketDetail(int ticketId) async {
    try {
      final result = await _httpService.getRequest(
        '/user/ticket/fetch?id=$ticketId',
      );
      final ticket =
          TicketDetail.fromJson(result['data'] as Map<String, dynamic>);
      return ApiResponse(success: true, data: ticket);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 获取工单详情失败: $e');
    }
  }

  Future<ApiResponse<Ticket?>> createTicket({
    required String subject,
    required int level,
    required String message,
  }) async {
    try {
      await _httpService.postRequest(
        '/user/ticket/save',
        {
          'subject': subject,
          'level': level,
          'message': message,
        },
      );
      // V2Board returns {"data": true} on success — no Ticket object to parse
      return ApiResponse(success: true, data: null);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 创建工单失败: $e');
    }
  }

  Future<ApiResponse<void>> replyTicket({
    required int ticketId,
    required String message,
  }) async {
    try {
      final result = await _httpService.postRequest(
        '/user/ticket/reply',
        {'id': ticketId, 'message': message},
      );
      return ApiResponse.fromJson(result, null);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 回复工单失败: $e');
    }
  }

  Future<ApiResponse<void>> closeTicket(int ticketId) async {
    try {
      final result = await _httpService.postRequest(
        '/user/ticket/close',
        {'id': ticketId},
      );
      return ApiResponse.fromJson(result, null);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 关闭工单失败: $e');
    }
  }
}
