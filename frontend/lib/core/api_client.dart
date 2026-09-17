import 'package:dio/dio.dart';
import '../models/ticket.dart';

class ApiClient {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  Future<Ticket?> getTicketStatus(String ticketId, String clientToken) async {
    try {
      final response = await _dio.get(
        '/api/tickets/$ticketId',
        options: Options(
          headers: {'X-Client-Token': clientToken},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return Ticket.fromJson(response.data);
      }
    } on DioException catch (e) {
      print('Ошибка Dio при запросе талона: [${e.response?.statusCode}] ${e.message}');
    } catch (e) {
      print('Непредвиденная ошибка: $e');
    }
    return null;
  }
}