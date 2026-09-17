class Ticket {
  final String id;                  // UUID
  final String number;              // например: A-101
  final String sourceType;          // BOOKING, QR, WALK_IN
  final String status;              // WAITING, IN_SERVICE, COMPLETED, CANCELLED
  final String serviceId;           // UUID выбранной услуги
  final int? windowNumber;          // Номер окна (null если еще в очереди)
  final String clientToken;         // Секретный токен сессии
  final String createdAt;           // ISO время
  final int estimatedWaitMin;       // Прогнозируемое время ожидания (в минутах)

  Ticket({
    required this.id,
    required this.number,
    required this.sourceType,
    required this.status,
    required this.serviceId,
    this.windowNumber,
    required this.clientToken,
    required this.createdAt,
    required this.estimatedWaitMin,
  });


  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as String,
      number: json['number'] as String,
      sourceType: json['sourceType'] as String,
      status: json['status'] as String,
      serviceId: json['serviceId'] as String,
      windowNumber: json['windowNumber'] as int?,
      clientToken: json['clientToken'] as String,
      createdAt: json['createdAt'] as String,
      estimatedWaitMin: json['estimatedWaitMin'] as int? ?? 0,
    );
  }

  // Сериализация обратно в JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'sourceType': sourceType,
      'status': status,
      'serviceId': serviceId,
      'windowNumber': windowNumber,
      'clientToken': clientToken,
      'createdAt': createdAt,
      'estimatedWaitMin': estimatedWaitMin,
    };
  }
}