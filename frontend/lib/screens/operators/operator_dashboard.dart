import 'package:flutter/material.dart';
import '../../models/ticket.dart';

class OperatorDashboard extends StatefulWidget {
  const OperatorDashboard({super.key});

  @override
  State<OperatorDashboard> createState() => _OperatorDashboardState();
}

class _OperatorDashboardState extends State<OperatorDashboard> {
  bool isWindowOpen = true;
  final int windowNumber = 3;

  Ticket? currentTicket = Ticket(
    id: '1',
    number: 'A-042',
    sourceType: 'BOOKING',
    status: 'WAITING',
    serviceId: 'service_1',
    windowNumber: 3,
    clientToken: 'token_123',
    createdAt: '2026-09-17T10:00:00Z',
    estimatedWaitMin: 5,
  );

  void _callNext() {
    setState(() {
      currentTicket = currentTicket?.copyWith(status: 'IN_SERVICE', windowNumber: windowNumber);
    });
  }

  void _complete() {
    setState(() {
      currentTicket = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          Container(
            width: 300,
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.store, size: 32, color: Colors.blue),
                    const SizedBox(width: 12),
                    Text('Окно № $windowNumber', 
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 32),
                const Text('Статус окна', style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text(isWindowOpen ? 'Открыто' : 'Закрыто', 
                      style: TextStyle(fontWeight: FontWeight.bold, color: isWindowOpen ? Colors.green : Colors.red)),
                  value: isWindowOpen,
                  activeColor: Colors.green,
                  onChanged: (val) => setState(() => isWindowOpen = val),
                ),
                const Divider(height: 40),
                const Text('Обслуживаемые услуги:', style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 12),
                _buildServiceChip('Паспорт РФ'),
                const SizedBox(height: 8),
                _buildServiceChip('Справки'),
                const SizedBox(height: 8),
                _buildServiceChip('Посылки'),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (currentTicket == null) ...[
                      const Icon(Icons.hourglass_empty, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Очередь пуста', style: TextStyle(fontSize: 24, color: Colors.grey)),
                    ] else ...[
                      const Text('Текущий клиент', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 16),
                      Text(
                        currentTicket!.number,
                        style: const TextStyle(fontSize: 96, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      const SizedBox(height: 16),
                      _buildSourceBadge(currentTicket!.sourceType),
                      const SizedBox(height: 8),
                      Text(
                        'Ожидаемое время: ~${currentTicket!.estimatedWaitMin} мин',
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 64),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildActionButton(Icons.call, 'Вызвать', Colors.blue, _callNext),
                          _buildActionButton(Icons.check_circle, 'Завершить', Colors.green, _complete),
                          _buildActionButton(Icons.undo, 'Вернуть в очередь', Colors.orange, () {}),
                          _buildActionButton(Icons.swap_horiz, 'Перенаправить', Colors.purple, () {}),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.blue[50],
      labelStyle: const TextStyle(color: Colors.blue),
    );
  }

  Widget _buildSourceBadge(String sourceType) {
    Color color;
    String text;
    switch (sourceType) {
      case 'BOOKING': color = Colors.green; text = 'Предварительная запись'; break;
      case 'QR': color = Colors.blue; text = 'QR-код'; break;
      case 'WALK_IN': color = Colors.orange; text = 'Живая очередь'; break;
      default: color = Colors.grey; text = sourceType;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButton(IconData icon, String text, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: isWindowOpen ? onPressed : null,
      icon: Icon(icon),
      label: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size(180, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

extension TicketCopy on Ticket {
  Ticket copyWith({
    String? id, String? number, String? sourceType, String? status,
    String? serviceId, int? windowNumber, String? clientToken,
    String? createdAt, int? estimatedWaitMin,
  }) {
    return Ticket(
      id: id ?? this.id,
      number: number ?? this.number,
      sourceType: sourceType ?? this.sourceType,
      status: status ?? this.status,
      serviceId: serviceId ?? this.serviceId,
      windowNumber: windowNumber ?? this.windowNumber,
      clientToken: clientToken ?? this.clientToken,
      createdAt: createdAt ?? this.createdAt,
      estimatedWaitMin: estimatedWaitMin ?? this.estimatedWaitMin,
    );
  }
}