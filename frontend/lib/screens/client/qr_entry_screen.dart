import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/session_storage.dart';

class QrEntryScreen extends StatefulWidget {
  const QrEntryScreen({super.key});

  @override
  State<QrEntryScreen> createState() => _QrEntryScreenState();
}

class _QrEntryScreenState extends State<QrEntryScreen> {
  bool isLoading = false;

  Future<void> _simulateQrScan() async {
    setState(() => isLoading = true);

    // Эмуляция сетевого запроса к бэкенду для взятия талона из "Живой очереди" (WALK_IN)
    await Future.delayed(const Duration(seconds: 1)); 

    final newTicketId = 'qr-ticket-${DateTime.now().millisecondsSinceEpoch}';
    final newClientToken = 'token-qr-123';

    await SessionStorage.saveSession(newTicketId, newClientToken);

    if (!mounted) return;
    context.go('/ticket', extra: {'ticketId': newTicketId, 'clientToken': newClientToken});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0055A5),
        title: const Text('Живая очередь', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_2, size: 120, color: Color(0xFF0055A5)),
              const SizedBox(height: 24),
              const Text(
                'Наведите камеру на QR-код в отделении или нажмите кнопку ниже для тестового получения талона.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 250,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _simulateQrScan,
                  icon: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                      : const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text('Сканировать QR', style: TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0055A5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}