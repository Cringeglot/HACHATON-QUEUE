import 'package:dio/dio.dart';
import '../models/ticket.dart';
import 'app_config.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.httpBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
  }

  // Флаг для переключения между тестовыми данными и реальным бэкендом
  final bool _useMock = false;

  // 1. Создание записи (предварительная запись)
  Future<Map<String, String>?> createBooking(String date, String time, String serviceId, String branchId) async {
    if (_useMock) {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'ticketId': 'mock-booking-${DateTime.now().millisecondsSinceEpoch}',
        'clientToken': 'mock-jwt-token-xyz',
      };
    }

    try {
// Пример отправки корректного JSON в ApiClient:
final response = await _dio.post(
  '/api/tickets',
  data: {
    'branch_id': 1,         // int, не String
    'service_id': 1,        // int (число, например 1, 2, 3)
    'source': 'qr',         // "appointment", "qr" или "live"
    'scheduled_at': null,   // ISO-строка даты или null
  },
);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'ticketId': (response.data['id'] ?? response.data['ticketId']).toString(),
          'clientToken': (response.data['token'] ?? response.data['clientToken']).toString(),
        };
      }
    } catch (e) {
  // Добавьте эти строки для детального лога:
  if (e is DioException) {
    print('Ошибка бэкенда [${e.response?.statusCode}]: ${e.response?.data}');
  } else {
    print('Ошибка при создании записи: $e');
  }
}
  }

  // 2. Создание талона по QR-коду
  Future<Map<String, String>?> createQrTicket() async {
    if (_useMock) {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'ticketId': 'mock-qr-${DateTime.now().millisecondsSinceEpoch}',
        'clientToken': 'mock-jwt-token-qr',
      };
    }

    try {
      final response = await _dio.post(
        '/api/tickets',
        data: {'source': 'qr'},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'ticketId': (response.data['id'] ?? response.data['ticketId']).toString(),
          'clientToken': (response.data['token'] ?? response.data['clientToken']).toString(),
        };
      }
    } catch (e) {
      print('Ошибка получения QR-талона: $e');
    }
    return null;
  }

  // 3. Получение статуса талона
  Future<Ticket?> getTicketStatus(String ticketId, String clientToken) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      return Ticket(
        id: ticketId,
        number: 'A-012',
        status: 'WAITING',
        estimatedWaitMin: 4,
        windowNumber: null,
      );
    }

    try {
      final response = await _dio.get(
        '/api/tickets/$ticketId',
        options: Options(headers: {'Authorization': 'Bearer $clientToken'}),
      );

      if (response.statusCode == 200) {
        return Ticket.fromJson(response.data);
      }
    } catch (e) {
      print('Ошибка получения статуса талона: $e');
    }
    return null;
  }

  // 4. Отмена талона
  Future<bool> cancelTicket(String ticketId, String clientToken) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }

    try {
      final response = await _dio.post(
        '/api/tickets/$ticketId/cancel',
        options: Options(headers: {'Authorization': 'Bearer $clientToken'}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Ошибка отмены талона: $e');
      return false;
    }
  }
}