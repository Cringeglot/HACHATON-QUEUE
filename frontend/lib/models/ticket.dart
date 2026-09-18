class Ticket {
  final String id;
  final String number;
  final String status;
  final int estimatedWaitMin;
  final String? windowNumber;

  Ticket({
    required this.id,
    required this.number,
    required this.status,
    required this.estimatedWaitMin,
    this.windowNumber,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      // Безопасное считывание ID (как id, так и ticketId)
      id: json['id']?.toString() ?? json['ticketId']?.toString() ?? '',

      // Если номер отсутствует, выводим '---' вместо падения приложения
      number: json['number']?.toString() ?? json['ticket_number']?.toString() ?? '---',

      // ПРИВЕДЕНИЕ К ВЕРХНЕМУ РЕГИСТРУ: "waiting" -> "WAITING"
      status: (json['status'] as String? ?? 'WAITING').toUpperCase(),

      // Защита от null и поддержка snake_case / camelCase
      estimatedWaitMin: (json['estimatedWaitMin'] ?? json['estimated_wait_min'] as num?)?.toInt() ?? 0,

      // Поддержка различных вариантов названия поля окна от бэкенда
      windowNumber: json['windowNumber']?.toString() ?? 
                    json['window_number']?.toString() ?? 
                    json['window']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'status': status,
      'estimatedWaitMin': estimatedWaitMin,
      'windowNumber': windowNumber,
    };
  }
}