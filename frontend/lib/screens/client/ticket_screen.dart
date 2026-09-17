import 'package:flutter/material.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  String ticketNumber = "П-102";
  String status = "Ожидание"; 
  String windowNumber = "3";
  int estimatedWaitMinutes = 8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0055A5),
        title: const Text('Электронный талон', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
  constraints: const BoxConstraints(maxWidth: 400), // Ограничиваем максимальную ширину
  padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Отделение № 101000', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 16),
                  Text(
                    ticketNumber,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0055A5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      status,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: status == "Вызван" ? Colors.green : Colors.orange,
                  ),
                  const Divider(height: 32),
                  if (status == "Вызван") ...[
                    const Text('Пройдите к окну:', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      'Окно № $windowNumber',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Примерное время: ~$estimatedWaitMinutes мин.',
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () {
                      // Логика запроса отмены записи
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Отменить запись'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}