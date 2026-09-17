import 'package:dio/dio.dart';
import '../models/ticket.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiClient {

  static String getBaseUrl() {
  if (kIsWeb) {
    return 'http://localhost:8000'; // Для веба (Chrome, Яндекс)
  } else if (Platform.isAndroid) {
    return 'http://10.0.2.2:8000'; // Для Android-эмулятора
  }
  return 'http://localhost:8000';
}

  final bool _useMock = true;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  Future<Ticket?> getTicketStatus(String ticketId, String clientToken) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      
      return Ticket(
        id: ticketId,
        number: 'П-102',
        sourceType: 'BOOKING',
        status: 'WAITING',
        serviceId: 's1',
        windowNumber: null,
        clientToken: clientToken,
        createdAt: DateTime.now().toIso8601String(),
        estimatedWaitMin: 8,
      );
    }
    
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

  Future<bool> cancelTicket(String ticketId, String clientToken) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      return true; 
    } 
    try {
      final response = await _dio.post(
        '/api/tickets/$ticketId/cancel',
        options: Options(
          headers: {'X-Client-Token': clientToken},
        ),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      print('Ошибка Dio при отмене талона: [${e.response?.statusCode}] ${e.message}');
    } catch (e) {
      print('Ошибка отмены: $e');
    }
    return false;
  }
}