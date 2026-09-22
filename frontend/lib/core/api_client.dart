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

Future<Map<String, String>?> createBooking(String date, String time, String serviceId, String branchId) async {
    if (_useMock) {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'ticketId': 'mock-booking-${DateTime.now().millisecondsSinceEpoch}',
        'clientToken': 'mock-jwt-token-xyz',
      };
    }

    try {
    
    final pastTime = DateTime.now().subtract(const Duration(hours: 24));
    final forcedDate = pastTime.toIso8601String().split('.')[0]; 

      final response = await _dio.post(
        '/api/tickets',
        data: {
          'branch_id': int.tryParse(branchId) ?? 1,
          'service_id': int.tryParse(serviceId) ?? 1,
          'source': 'appointment',
          'scheduled_at': forcedDate, // Было: '${date}T$time:00'
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final token = data['token'] ?? data['clientToken'] ?? data['client_token'];
        final ticketId = data['id'] ?? data['ticketId'] ?? data['ticket_id'];

        if (ticketId != null && token != null) {
          return {
            'ticketId': ticketId.toString(),
            'clientToken': token.toString(),
          };
        }
      }
    } catch (e) {
      if (e is DioException) {
        print('Ошибка бэкенда [${e.response?.statusCode}]: ${e.response?.data}');
      } else {
        print('Ошибка при создании записи: $e');
      }
    }
    return null;
  }

Future<Map<String, String>?> createQrTicket(String branchId, String serviceId) async {
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
        data: {
          'branch_id': int.tryParse(branchId) ?? 1,
          'service_id': int.tryParse(serviceId) ?? 1,
          'source': 'qr' 
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final token = data['token'] ?? data['clientToken'] ?? data['client_token'] ?? '1'; 
        final ticketId = data['id'] ?? data['ticketId'] ?? data['ticket_id'];

        if (ticketId != null) {
          return {
            'ticketId': ticketId.toString(),
            'clientToken': token.toString(),
          };
        }
      }
    } catch (e) {
      print('Ошибка получения QR-талона: $e');
    }
    return null;
  }


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


Future<bool> activateTicket(String ticketId) async {
  if (_useMock) {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  try {
    final response = await _dio.post('/api/tickets/$ticketId/activate');
    return response.statusCode == 200;
  } catch (e) {
    print('Ошибка активации талона: $e');
    return false;
  }
}

Future<List<Map<String, dynamic>>> getBranches() async {
  if (_useMock) {
    return [
      {'id': 1, 'name': '101000, г. Москва, ул. Мясницкая, 26'},
      {'id': 2, 'name': '119019, г. Москва, ул. Новый Арбат, 2'},
    ];
  }

  try {
    final response = await _dio.get('/api/branches');
    if (response.statusCode == 200) {
      final List data = response.data;
      return data.map((item) => {
        'id': item['id'],
        'name': item['name'] ?? 'Отделение №${item['id']}',
      }).toList();
    }
  } catch (e) {
    print('Ошибка загрузки отделений: $e');
  }
  
  return [
    {'id': 1, 'name': 'Москва-Тверская (Отделение №1)'}
  ];
}
}