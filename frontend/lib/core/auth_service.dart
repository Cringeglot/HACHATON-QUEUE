import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_config.dart'; // Используем новый конфиг сокомандника

class AuthService {
  final Dio _dio;
  final _storage = const FlutterSecureStorage();

  AuthService({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    // Берём базовый HTTP URL, который ваш коллега настроил для докера и локалки
    baseUrl: AppConfig.httpBaseUrl, 
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  /// Регистрация (FastAPI ожидает стандартный JSON-объект)
  Future<bool> register({
    required String username,
    required String password,
    String? email,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/',
        data: {
          'username': username,
          'password': password,
          if (email != null) 'email': email,
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      print('Ошибка регистрации на бэкенде: ${e.response?.data ?? e.message}');
      return false;
    }
  }

  /// Логин (FastAPI ожидает OAuth2 Form Data URL-encoded)
  Future<String?> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/token',
        data: {
          'username': username,
          'password': password,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final accessToken = response.data['access_token'];
        if (accessToken != null) {
          // Сохраняем JWT-токен в защищенную память устройства
          await _storage.write(key: 'jwt_token', value: accessToken);
          return accessToken;
        }
      }
    } on DioException catch (e) {
      print('Ошибка входа на бэкенде: ${e.response?.data ?? e.message}');
    }
    return null;
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
  }
}
