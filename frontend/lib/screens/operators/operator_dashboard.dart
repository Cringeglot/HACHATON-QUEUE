import 'dart:async';
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
  
  // ИСПРАВЛЕНО: Динамические переменные вместо захардкоженного Окна №1
  int windowId = 1;
  int branchId = 1;
  Timer? _autoRefreshTimer;

  List<Ticket> _queue = [];
  Ticket? currentTicket;

  @override
  void initState() {
    super.initState();
    _loadWorkerConfig();
  }

  // Загрузка динамических параметров окна, выбранных на экране авторизации
  Future<void> _loadWorkerConfig() async {
    final savedBranch = await _storage.read(key: 'user_branch_id');
    final savedWindow = await _storage.read(key: 'user_window_id');
    
    setState(() {
      branchId = int.tryParse(savedBranch ?? '1') ?? 1;
      windowId = int.tryParse(savedWindow ?? '1') ?? 1;
    });

    _fetchQueueAndStatus();
    
    // ИСПРАВЛЕНО: Добавлен фоновый WebSocket/Поллинг клиент для автообновления зала ожидания
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) _fetchQueueAndStatus();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel(); // Очищаем таймер при выходе из панели оператора
    super.dispose();
  }

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<void> _fetchQueueAndStatus() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/api/tickets', options: options);

      if (response.statusCode == 200 && response.data != null) {
        final List data = response.data;
        if (!mounted) return;
        setState(() {
          final allTickets = data.map((json) {
            return Ticket(
              id: json['id']?.toString() ?? '',
              number: json['number']?.toString() ?? json['public_code']?.toString() ?? 'A-000',
              sourceType: json['source_type']?.toString() ?? json['source']?.toString() ?? 'qr',
              status: json['status']?.toString() ?? 'waiting',
              serviceId: json['service_id']?.toString() ?? '1',
              windowNumber: json['window_number']?.toString() ?? json['window_id']?.toString(),
              clientToken: json['client_token']?.toString(),
              createdAt: json['created_at']?.toString() ?? '',
              estimatedWaitMin: json['estimated_wait_min'] as int? ?? 0,
            );
          }).toList();
          
          // Фильтруем талоны строго под выбранный филиал
          _queue = allTickets
              .where((t) => (t.status == 'waiting' || t.status == 'scheduled') && t.serviceId == branchId.toString())
              .toList();

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
      print('Ошибка обновления данных очереди: $e');
    }
  }

  Future<void> _callNext() async {
    if (currentTicket != null) return;
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post('/api/windows/$windowId/call-next', options: options);

      if (response.statusCode == 200 && response.data != null && response.data['ticket'] != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Клиент успешно вызван в Окно №$windowId!'), backgroundColor: Colors.green),
        );
      }
      _fetchQueueAndStatus();
    } catch (e) {
      print('Ошибка вызова из общего пула: $e');
    }
  }

  Future<void> _callNextLive() async {
    if (currentTicket != null) return;
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post('/api/windows/$windowId/call-live', options: options);

      if (response.statusCode == 200 && response.data != null && response.data['ticket'] != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Клиент успешно вызван из живой очереди в Окно №$windowId!'), backgroundColor: Colors.green),
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
      setState(() => currentTicket = null);
      _fetchQueueAndStatus();
    } catch (e) {
      print('Ошибка завершения талона: $e');
    }
  }

  Future<void> _returnToQueue() async {
    if (currentTicket == null) return;
    try {
      final options = await _getAuthOptions();
      await _dio.post('/api/tickets/${currentTicket!.id}/return', options: options);
      setState(() => currentTicket = null);
      _fetchQueueAndStatus();
    } catch (e) {
      print('Ошибка возврата талона: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Рабочее место оператора — ОПС №$branchId, Окно №$windowId'),
        backgroundColor: const Color(0xFF0055A5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchQueueAndStatus),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => context.go('/login'))
        ],
      ),
      body: Row(
        children: [
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
                    color: const Color(0xFF0055A5).withValues(alpha:0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0055A5).withValues(alpha:0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people, color: Color(0xFF0055A5), size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ожидают в зале', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          Text('${_queue.length}', style: const TextStyle(color: Color(0xFF0055A5), fontSize: 26, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(child: _buildQueuePreview()),
              ],
            ),
          ),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Монитор зала ожидания (Автообновление)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0055A5))),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10)]),
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
              onPressed: _queue.isNotEmpty ? _callNext : null,
              icon: const Icon(Icons.call),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0055A5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
              label: const Text('Вызвать следующего (Предзапись / QR)', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _queue.isNotEmpty ? _callNextLive : null,
              icon: const Icon(Icons.flash_on),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange), foregroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 16)),
              label: const Text('Вызвать из Живой очереди (FIFO)', style: TextStyle(fontSize: 16)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10)]),
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
