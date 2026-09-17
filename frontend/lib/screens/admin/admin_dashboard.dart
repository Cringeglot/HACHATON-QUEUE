import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Панель руководителя отделения'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatCard('В очереди', '12', Colors.blue, Icons.people),
                const SizedBox(width: 16),
                _buildStatCard('Среднее ожидание', '8 мин', Colors.green, Icons.timer),
                const SizedBox(width: 16),
                _buildStatCard('Активные окна', '4 / 5', Colors.orange, Icons.store),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Статус окон', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            _buildWindowRow(1, 'Открыто', 'A-040', Colors.green),
                            const Divider(),
                            _buildWindowRow(2, 'Открыто', 'A-041', Colors.green),
                            const Divider(),
                            _buildWindowRow(3, 'Открыто', 'A-042', Colors.green),
                            const Divider(),
                            _buildWindowRow(4, 'Закрыто', '-', Colors.red),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: Card(
                      color: Colors.red[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Аномалии', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildAnomalyItem('A-038', 'Ожидание > 30 мин', 'Живая очередь'),
                            const SizedBox(height: 12),
                            _buildAnomalyItem('A-039', 'Окно закрыто во время обслуживания', 'QR-код'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWindowRow(int number, String status, String currentTicket, Color statusColor) {
    return Row(
      children: [
        Text('Окно $number', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
          child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 16),
        const Text('Текущий:'),
        const SizedBox(width: 8),
        Text(currentTicket, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAnomalyItem(String ticketNumber, String reason, String source) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(ticketNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 8),
              Text('($source)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(reason, style: const TextStyle(color: Colors.red, fontSize: 14)),
        ],
      ),
    );
  }
}