class Ticket {
  final String id;
  final String number;
  final String status;
  final int estimatedWaitMin;
  final String? windowNumber;
  final String? branchId; // Добавлено поле
  
  final String? sourceType;
  final String? serviceId;
  final String? clientToken;
  final String? createdAt;

  Ticket({
    required this.id,
    required this.number,
    required this.status,
    required this.estimatedWaitMin,
    this.windowNumber,
    this.branchId,
    this.sourceType,
    this.serviceId,
    this.clientToken,
    this.createdAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id']?.toString() ?? json['ticketId']?.toString() ?? '',
      number: json['number']?.toString() ?? json['ticket_number']?.toString() ?? '---',
      status: (json['status'] as String? ?? 'WAITING').toUpperCase(),
      estimatedWaitMin: (json['estimatedWaitMin'] ?? json['estimated_wait_min'] as num?)?.toInt() ?? 0,
      windowNumber: json['windowNumber']?.toString() ?? 
                    json['window_number']?.toString() ?? 
                    json['window']?.toString(),
      branchId: json['branchId']?.toString() ?? json['branch_id']?.toString(),
      sourceType: json['sourceType']?.toString() ?? json['source_type']?.toString(),
      serviceId: json['serviceId']?.toString() ?? json['service_id']?.toString(),
      clientToken: json['clientToken']?.toString() ?? json['client_token']?.toString(),
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'status': status,
      'estimatedWaitMin': estimatedWaitMin,
      'windowNumber': windowNumber,
      'branchId': branchId,
      'sourceType': sourceType,
      'serviceId': serviceId,
      'clientToken': clientToken,
      'createdAt': createdAt,
    };
  }
}