import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../../core/session_storage.dart';
import '../../models/ticket.dart';

class TicketScreen extends StatefulWidget {
  final String ticketId;
  final String clientToken;

  const TicketScreen({
    super.key,
    required this.ticketId,
    required this.clientToken,
  });

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final ApiClient _apiClient = ApiClient();

  late String _activeTicketId;
  late String _activeClientToken;

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  Timer? _fallbackTimer;
  Timer? _wsReconnectTimer;

  Ticket? _ticket;
  bool _isLoading = true;
  bool _isCancelling = false;
  bool _isWsConnected = false;
  String? _errorMessage;

  bool _hasNotifiedApproaching = false;
  bool _hasNotifiedCalled = false;

  @override
  void initState() {
    super.initState();
    _activeTicketId = widget.ticketId;
    _activeClientToken = widget.clientToken;

    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // 1. Восстановление сессии из хранилища при случайной перезагрузке (F5)
    if (_activeTicketId.isEmpty || _activeClientToken.isEmpty) {
      final session = await SessionStorage.getSession();
      if (session != null) {
        _activeTicketId = session['ticketId'] ?? '';
        _activeClientToken = session['clientToken'] ?? '';
      }
    }

    if (_activeTicketId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Сессия не найдена';
        });
      }
      return;
    }

    // 2. Первичная загрузка и запуск WebSocket
    await _fetchTicketStatus();
    _initWebSocket();
  }

  void _initWebSocket() {
    if (_activeTicketId.isEmpty || _isWsConnected) return;

    try {
      final wsBase = AppConfig.wsBaseUrl;
      final wsUrl = Uri.parse('$wsBase/ws/tickets/$_activeTicketId?token=$_activeClientToken');
      
      _wsSubscription?.cancel();
      _wsChannel?.sink.close();
      _wsChannel = WebSocketChannel.connect(wsUrl);

      _wsSubscription = _wsChannel!.stream.listen(
        (message) {
          if (!_isWsConnected) {
            _isWsConnected = true;
            _stopFallbackPolling();
          }
          final data = jsonDecode(message);
          _updateTicketFromData(data);
        },
        onError: (_) => _handleWsDisconnect(),
        onDone: () => _handleWsDisconnect(),
      );
    } catch (_) {
      _handleWsDisconnect();
    }
  }

  void _handleWsDisconnect() {
    if (!mounted) return;
    _isWsConnected = false;
    
    // Переходим на резервный поллинг
    _startFallbackPolling();

    // Запускаем фоновые попытки восстановить WebSocket
    _scheduleWsReconnect();
  }

  void _scheduleWsReconnect() {
    if (_wsReconnectTimer != null && _wsReconnectTimer!.isActive) return;

    _wsReconnectTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isWsConnected && mounted) {
        _initWebSocket();
      }
    });
  }

  void _startFallbackPolling() {
    if (_fallbackTimer != null && _fallbackTimer!.isActive) return;

    _fallbackTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchTicketStatus();
    });
  }

  void _stopFallbackPolling() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _fallbackTimer?.cancel();
    _wsReconnectTimer?.cancel();
    super.dispose();
  }

  void _updateTicketFromData(Map<String, dynamic> data) {
    if (!mounted) return;

    final updatedTicket = Ticket.fromJson(data);

    if (updatedTicket.status == 'WAITING' &&
        updatedTicket.estimatedWaitMin <= 5 &&
        !_hasNotifiedApproaching) {
      _hasNotifiedApproaching = true;
      _showNotificationDialog(
        'Очередь подходит',
        'Пожалуйста, подойдите ближе к зоне обслуживания. Ваша очередь подойдет примерно через ${updatedTicket.estimatedWaitMin} мин.',
        Icons.access_time_filled,
        Colors.orange,
      );
    }

    if ((updatedTicket.status == 'CALLED' || updatedTicket.status == 'IN_SERVICE') &&
        !_hasNotifiedCalled) {
      _hasNotifiedCalled = true;
      _showNotificationDialog(
        'Вас вызывают!',
        'Пройдите к окну № ${updatedTicket.windowNumber ?? "..."}.',
        Icons.notifications_active,
        Colors.green,
      );
    }

    setState(() {
      _ticket = updatedTicket;
      _isLoading = false;
      _errorMessage = null;
    });

    if (updatedTicket.status == 'COMPLETED' || updatedTicket.status == 'CANCELLED') {
      _wsChannel?.sink.close();
      _stopFallbackPolling();
      _wsReconnectTimer?.cancel();
      SessionStorage.clearSession();
    }
  }

   Future<void> _fetchTicketStatus() async {
    if (_activeTicketId.isEmpty) return;

    final updatedTicket = await _apiClient.getTicketStatus(
      _activeTicketId,
      _activeClientToken,
    );

    if (!mounted) return;

    if (updatedTicket != null) {
      _updateTicketFromData(updatedTicket.toJson());
    } else {
      // Если бэкенд не вернул данные (битая сессия / талон удален), 
      // сбрасываем кэш и отправляем на главную.
      _wsSubscription?.cancel();
      _wsChannel?.sink.close();
      _stopFallbackPolling();
      _wsReconnectTimer?.cancel();
      
      await SessionStorage.clearSession();
      
      if (mounted) {
        context.go('/');
      }
    }
  }

  void _showNotificationDialog(String title, String message, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Понятно', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCancel() async {
    setState(() => _isCancelling = true);

    final success = await _apiClient.cancelTicket(
      _activeTicketId,
      _activeClientToken,
    );

    if (!mounted) return;

    if (success) {
      _wsChannel?.sink.close();
      _stopFallbackPolling();
      _wsReconnectTimer?.cancel();
      await SessionStorage.clearSession();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запись успешно отменена')),
      );

      setState(() {
        _ticket = null;
        _isCancelling = false;
      });
    } else {
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка отмены записи')),
      );
    }
  }

(String label, Color color) _getStatusDisplay(String status) {
    switch (status) {
      case 'IN_SERVICE':
      case 'CALLED':
        return ('Вызван к окну', Colors.green);
      case 'WAITING':
        return ('В очереди', Colors.orange);
      case 'SCHEDULED':
      case 'scheduled': 
        return ('Запланировано', Colors.teal); 
      case 'COMPLETED':
        return ('Завершено', Colors.blue);
      case 'CANCELLED':
        return ('Отменён', Colors.red);
      default:
        return (status, Colors.grey);
    }
  }

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
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildCardContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _ticket == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _initializeScreen();
            },
            child: const Text('Повторить'),
          ),
        ],
      );
    }

    if (_ticket == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Нет активного талона', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('На главную'),
          ),
        ],
      );
    }

    final (statusLabel, statusColor) = _getStatusDisplay(_ticket!.status);
    final isCalled = _ticket!.status == 'IN_SERVICE' || _ticket!.status == 'CALLED';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Отделение № ${_ticket!.branchId ?? "1"}', style: const TextStyle(color: Colors.grey, fontSize: 14),),
        const SizedBox(height: 16),
        Text(
          _ticket!.number,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0055A5),
          ),
        ),
        const SizedBox(height: 8),
        Chip(
          label: Text(
            statusLabel,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: statusColor,
        ),
        const Divider(height: 32),
        if (isCalled) ...[
          const Text('Пройдите к окну:', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Окно № ${_ticket!.windowNumber ?? "-"}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ] else ...[
          Row(
  children: [
    Icon(Icons.info),
    SizedBox(width: 8),
    Expanded( // <-- Занимает только оставшееся свободное место
      child: Text(
        'Примерное время: ~${_ticket!.estimatedWaitMin} мин.',
        overflow: TextOverflow.ellipsis, // <-- Добавляет "..." в конце, если не влезает
        maxLines: 1,
      ),
    ),
  ],
)
        ],
        const SizedBox(height: 24),
        if (_ticket!.status == 'WAITING' || 
          _ticket!.status == 'scheduled' || 
          _ticket!.status == 'SCHEDULED')
          OutlinedButton(
            onPressed: _isCancelling ? null : _handleCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            child: _isCancelling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                  )
                : const Text('Отменить запись'),
          ),
      ],
    );
  }
}