import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _envApiUrl = String.fromEnvironment('API_URL');
  static const String _envWsUrl = String.fromEnvironment('WS_URL');

  /// Динамическое получение HTTP Base URL
  static String get httpBaseUrl {
    if (_envApiUrl.isNotEmpty) return _envApiUrl;

    if (kIsWeb) {
      final Uri base = Uri.base;
      if (base.host.isNotEmpty && base.host != 'localhost') {
        final scheme = base.scheme == 'https' ? 'https' : 'http';
        final port = base.port != 0 && base.port != 80 && base.port != 443 ? ':${base.port}' : '';
        return '$scheme://${base.host}$port';
      }
    }
    
    // По умолчанию для локальной разработки
    return 'http://localhost:8000';
  }

  /// Динамическое получение WS Base URL
  static String get wsBaseUrl {
    if (_envWsUrl.isNotEmpty) return _envWsUrl;

    final httpUri = Uri.parse(httpBaseUrl);
    final wsScheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    final port = httpUri.hasPort ? ':${httpUri.port}' : '';

    return '$wsScheme://${httpUri.host}$port';
  }
}