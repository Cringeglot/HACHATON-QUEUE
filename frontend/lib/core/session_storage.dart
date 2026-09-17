import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const String _keyTicketId = 'ticket_id';
  static const String _keyClientToken = 'client_token';

  /// Сохранить данные талона
  static Future<void> saveSession(String ticketId, String clientToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTicketId, ticketId);
    await prefs.setString(_keyClientToken, clientToken);
  }

  /// Получить сохранённые данные (вернёт null, если талона нет)
  static Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final ticketId = prefs.getString(_keyTicketId);
    final clientToken = prefs.getString(_keyClientToken);

    if (ticketId != null && clientToken != null) {
      return {
        'ticketId': ticketId,
        'clientToken': clientToken,
      };
    }
    return null;
  }

  /// Очистить данные сессии (при отмене или завершении обслуживания)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTicketId);
    await prefs.remove(_keyClientToken);
  }
}