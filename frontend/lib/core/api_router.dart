class ApiRouter {
  ApiRouter._();

  // Талоны
  static const String tickets = '/api/tickets';
  static String ticket(String ticketId) => '/api/tickets/$ticketId';
  static String cancelTicket(String ticketId) => '/api/tickets/$ticketId/cancel';
  static String completeTicket(String ticketId) => '/api/tickets/$ticketId/complete';
  static String returnTicket(String ticketId) => '/api/tickets/$ticketId/return';

  // Окна операторов
  static const String windows = '/api/windows';
  static String closeWindow(String windowId) => '/api/windows/$windowId/close';
  
  // Новые эндпоинты вызова
  static String callNext(String windowId) => '/api/windows/$windowId/call-next';
  static String callLive(String windowId) => '/api/windows/$windowId/call-live';

  // Справочники
  static const String branches = '/api/branches';
}