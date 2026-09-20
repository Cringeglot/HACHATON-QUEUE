import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/app_config.dart';
import '../../models/ticket.dart';

class OperatorDashboard extends StatefulWidget {
  const OperatorDashboard({super.key});

  @override
  State<OperatorDashboard> createState() => _OperatorDashboardState();
}

class _OperatorDashboardState extends State<OperatorDashboard> {
  final Dio _dio = Dio(BaseOptions(baseUrl: AppConfig.httpBaseUrl));
  final _storage = const FlutterSecureStorage();

  bool isLoading = false;
  final int windowId = 1; 

  List<Ticket> _queue = [];
  Ticket? currentTicket;

  @override
  void initState() {
    super.initState();
    _fetchQueueAndStatus();
  }

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // Настоящее чтение базы данных PostgreSQL с обходом ошибок Pydantic
  Future<void> _fetchQueueAndStatus() async {
    setState(() => isLoading = true);
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/api/tickets', options: options);

      if (response.statusCode == 200 && response.data != null) {
        final List data = response.data;
        setState(() {
          final allTickets = data.map((json) {
            return Ticket(
              id: json['id']?.toString() ?? '',
              number: json['number']?.toString() ?? json['public_code']?.toString() ?? 'A-000',
              sourceType: json['source_type']?.toString() ?? json['source']?.toString() ?? 'qr',
              status: json['status']?.toString() ?? 'waiting',
              serviceId: json['service_id']?.toString() ?? '1',
              // Всеядный парсинг: примет от СУБД и число 1, и строку "1"
              windowNumber: json['window_number']?.toString() ?? json['window_id']?.toString(),
              clientToken: json['client_token']?.toString(),
              createdAt: json['created_at']?.toString() ?? '',
              estimatedWaitMin: json['estimated_wait_min'] as int? ?? 0,
            );
          }).toList();
          
          // Фильтруем только тех, кто реально ожидает в зале вызова
          _queue = allTickets
              .where((t) => t.status == 'waiting' || t.status == 'scheduled')
              .toList();

          // Ищем активный талон, привязанный к нашему окну
          final calledInThisWindow = allTickets.firstWhere(
            (t) => t.status == 'called' && t.windowNumber == windowId.toString(),
            orElse: () => Ticket(
              id: '', number: '', sourceType: '', status: '', serviceId: '',
              windowNumber: null, clientToken: null, createdAt: '', estimatedWaitMin: 0,
            ),
          );
          currentTicket = calledInThisWindow.id.isNotEmpty ? calledInThisWindow : null;
        });
      }
    } catch (e) {
      print('Ошибка получения данных очереди: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Функция вызова из ОБЩЕГО пуЛА (Предзапись / QR)
  Future<void> _callNext() async {
    if (currentTicket != null) return;
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post('/api/windows/$windowId/call-next', options: options);

      if (response.statusCode == 200 && response.data != null && response.data['ticket'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Клиент успешно вызван из общего пула!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.data['message'] ?? 'Общий пул пуст'), backgroundColor: Colors.orange),
        );
      }
      _fetchQueueAndStatus();
    } catch (e) {
      print('Ошибка вызова из общего пула: $e');
    }
  }

  // ИСПРАВЛЕННАЯ функция вызова из ЖИВОЙ очереди (FIFO эндпоинт Ромашки)
  Future<void> _callNextLive() async {
    if (currentTicket != null) return;
    try {
      final options = await _getAuthOptions();
      // Вызываем строгий URL-эндпоинт Ромашки из main.py
      final response = await _dio.post('/api/windows/$windowId/call-live', options: options);

      if (response.statusCode == 200 && response.data != null && response.data['ticket'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Клиент успешно вызван из ЖИВОЙ очереди!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.data['message'] ?? 'Живая очередь пуста'), backgroundColor: Colors.orange),
        );
      }
      _fetchQueueAndStatus();
    } catch (e) {
      print('Ошибка вызова живой очереди: $e');
    }
  }

  Future<void> _complete() async {
    if (currentTicket == null) return;
    try {
      final options = await _getAuthOptions();
      await _dio.post('/api/tickets/${currentTicket!.id}/complete', options: options);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Обслуживание талона ${currentTicket!.number} завершено'), backgroundColor: Colors.green),
      );
      setState(() => currentTicket = null);
      _fetchQueueAndStatus();
    } catch (e) {
      print('Ошибка завершения: $e');
    }
  }

  Future<void> _returnToQueue() async {
    if (currentTicket == null) return;
    try {
      final options = await _getAuthOptions();
      await _dio.post('/api/tickets/${currentTicket!.id}/return', options: options);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Талон ${currentTicket!.number} возвращен в очередь'), backgroundColor: Colors.orange),
      );
      setState(() => currentTicket = null);
      _fetchQueueAndStatus();
    } catch (e) {
      print('Ошибка возврата: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Рабочее место оператора — Окно № $windowId'),
        backgroundColor: const Color(0xFF0055A5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchQueueAndStatus),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => context.go('/login'))
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0055A5)))
          : Row(
              children: [
                // Левая боковая панель — Монитор зала ожидания СУБД
                Container(
                  width: 310,
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0055A5).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0055A5).withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.people, color: Color(0xFF0055A5), size: 28),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Ожидают в зале', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                Text(
                                  '${_queue.length}',
                                  style: const TextStyle(color: Color(0xFF0055A5), fontSize: 26, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_queue.isNotEmpty) Expanded(child: _buildQueuePreview()),
                    ],
                  ),
                ),
                // Центральная панель управления вызовами талонов
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: currentTicket == null ? _buildEmptyState() : _buildCurrentTicket(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildQueuePreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Монитор зала ожидания', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0055A5))),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _queue.length,
              itemBuilder: (context, index) {
                final ticket = _queue[index];
                
                String displayType = ticket.sourceType?.toUpperCase() ?? 'QR';
                if (displayType == 'APPOINTMENT') displayType = 'Предзапись';
                if (displayType == 'LIVE') displayType = 'Живая очередь';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ticket.number, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(displayType, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 650),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_none, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text('Окно готово к приему посетителей', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _queue.any((t) => t.sourceType?.toLowerCase() != 'live') ? _callNext : null,
              icon: const Icon(Icons.call),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0055A5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
              label: const Text('Вызвать следующего (Предзапись / QR)', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _queue.any((t) => t.sourceType?.toLowerCase() == 'live') ? _callNextLive : null,
              icon: const Icon(Icons.flash_on),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange), foregroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 16)),
              label: const Text('Вызвать из Живой очереди', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTicket() {
    String currentType = currentTicket!.sourceType?.toUpperCase() ?? 'QR';
    if (currentType == 'APPOINTMENT') currentType = 'Предварительная запись';
    if (currentType == 'LIVE') currentType = 'Живая очередь';

    return Container(
      constraints: const BoxConstraints(maxWidth: 650),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Текущий обслуживаемый талон', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(currentTicket!.number, style: const TextStyle(fontSize: 84, fontWeight: FontWeight.bold, color: Color(0xFF0055A5))),
          const SizedBox(height: 10),
          Text('Категория: $currentType', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 35),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _complete, icon: const Icon(Icons.check), label: const Text('Завершить'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _returnToQueue, icon: const Icon(Icons.undo), label: const Text('Вернуть в очередь'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
