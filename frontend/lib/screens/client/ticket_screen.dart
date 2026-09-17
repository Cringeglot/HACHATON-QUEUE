import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
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
  Timer? _pollingTimer;

  Ticket? _ticket;
  bool _isLoading = true;
  bool _isCancelling = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 1. Сразу делаем первый запрос
    _fetchTicketStatus();
    // 2. Настраиваем Polling раз в 3 секунды
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchTicketStatus();
    });
  }

  @override
  void dispose() {
    // Обязательно отменяем таймер при уходе с экрана!
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTicketStatus() async {
    final updatedTicket = await _apiClient.getTicketStatus(
      widget.ticketId,
      widget.clientToken,
    );

    if (!mounted) return;

    if (updatedTicket != null) {
      setState(() {
        _ticket = updatedTicket;
        _isLoading = false;
        _errorMessage = null;
      });

      // Если талон завершён или отменён на сервере — очищаем сессию
      if (updatedTicket.status == 'COMPLETED' || updatedTicket.status == 'CANCELLED') {
        _pollingTimer?.cancel();
        await SessionStorage.clearSession();
      }
    } else {
      if (_isLoading) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Не удалось загрузить данные талона';
        });
      }
    }
  }

  Future<void> _handleCancel() async {
    setState(() => _isCancelling = true);

    final success = await _apiClient.cancelTicket(
      widget.ticketId,
      widget.clientToken,
    );

    if (!mounted) return;

    if (success) {
      _pollingTimer?.cancel();
      await SessionStorage.clearSession();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запись успешно отменена')),
      );

      // Тут в будущем будет переход на главный экран выбора услуг
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

  // Вспомогательный метод для статуса (текст и цвет)
  (String label, Color color) _getStatusDisplay(String status) {
    switch (status) {
      case 'IN_SERVICE':
      case 'CALLED':
        return ('Вызван к окну', Colors.green);
      case 'WAITING':
        return ('В очереди', Colors.orange);
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
if (_ticket == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Нет активного талона', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.go('/');
            },
            child: const Text('Получить новый талон'),
          ),
        ],
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
            onPressed: _fetchTicketStatus,
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
            onPressed: () {
              // В будущем: переход к выбору услуги
            },
            child: const Text('Получить новый талон'),
          ),
        ],
      );
    }

    final (statusLabel, statusColor) = _getStatusDisplay(_ticket!.status);
    final isCalled = _ticket!.status == 'IN_SERVICE' || _ticket!.status == 'CALLED';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Отделение № 101000', style: TextStyle(color: Colors.grey, fontSize: 14)),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Примерное время: ~${_ticket!.estimatedWaitMin} мин.',
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        if (_ticket!.status == 'WAITING')
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