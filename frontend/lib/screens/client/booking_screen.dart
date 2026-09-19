import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/session_storage.dart';
import '../../core/api_client.dart';

class BookingScreen extends StatefulWidget {
  final String serviceName;
  final String serviceId; // Добавлено: идентификатор услуги
  final String branchId;  // Добавлено: идентификатор отделения

  const BookingScreen({
    super.key, 
    required this.serviceName,
    required this.serviceId,
    required this.branchId,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime selectedDate = DateTime.now();
  String? selectedTime;
  bool isBooking = false;

  final List<String> timeSlots = ['09:00', '09:30', '10:00', '10:30', '11:00', '14:00', '15:30'];

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(), // Нельзя записаться в прошлое
      lastDate: DateTime.now().add(const Duration(days: 14)), // Запись на 2 недели вперед
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF0055A5)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        selectedTime = null; 
      });
    }
  }

Future<void> _createBooking() async {
  if (selectedTime == null) return;
  
  setState(() => isBooking = true);

  final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
  
  // Заменяем хардкод 's1' на динамические параметры.
  // Внимание: не забудьте обновить сигнатуру createBooking в ApiClient, 
  // чтобы она принимала branchId.
  final result = await ApiClient().createBooking(
    formattedDate, 
    selectedTime!, 
    widget.serviceId, 
    widget.branchId, 
  );

  if (!mounted) return;

  if (result != null) {
    final newTicketId = result['ticketId']!;
    final newClientToken = result['clientToken']!;

    await SessionStorage.saveSession(newTicketId, newClientToken);
    
    context.go('/ticket?ticketId=$newTicketId&clientToken=$newClientToken');
  } else {
    setState(() => isBooking = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ошибка создания записи')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final dateFormatted = DateFormat('dd.MM.yyyy').format(selectedDate);

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
              
              const Text('Выберите дату:', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dateFormatted, style: const TextStyle(fontSize: 16)),
                      const Icon(Icons.calendar_today, color: Color(0xFF0055A5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text('Доступное время:', style: TextStyle(fontSize: 18)),
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