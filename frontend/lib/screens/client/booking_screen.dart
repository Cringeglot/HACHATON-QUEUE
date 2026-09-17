import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/session_storage.dart';

class BookingScreen extends StatefulWidget {
  final String serviceName;
  const BookingScreen({super.key, required this.serviceName});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String? selectedTime;
  bool isBooking = false;

  final List<String> timeSlots = ['09:00', '09:30', '10:00', '10:30', '11:00', '14:00', '15:30'];

  Future<void> _createBooking() async {
    if (selectedTime == null) return;
    
    setState(() => isBooking = true);

    // TODO: Здесь должен быть вызов ApiClient для создания записи на бэкенде
    await Future.delayed(const Duration(seconds: 1)); // Эмуляция запроса

    // Демонстрационные данные полученного талона
    final newTicketId = 'ticket-${DateTime.now().millisecondsSinceEpoch}';
    final newClientToken = 'token-xyz-789';

    // Сохраняем сессию
    await SessionStorage.saveSession(newTicketId, newClientToken);

    if (!mounted) return;
    // Переходим на экран талона, очищая историю (чтобы кнопка "Назад" не возвращала на выбор времени)
    context.go('/ticket', extra: {'ticketId': newTicketId, 'clientToken': newClientToken});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0055A5),
        title: const Text('Запись на прием', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Услуга: ${widget.serviceName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              const Text('Выберите время на сегодня:', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: timeSlots.map((time) => ChoiceChip(
                  label: Text(time),
                  selected: selectedTime == time,
                  onSelected: (selected) {
                    setState(() => selectedTime = selected ? time : null);
                  },
                  selectedColor: const Color(0xFF0055A5).withOpacity(0.2),
                )).toList(),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (selectedTime != null && !isBooking) ? _createBooking : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0055A5),
                    foregroundColor: Colors.white,
                  ),
                  child: isBooking
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                      : const Text('Записаться', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}