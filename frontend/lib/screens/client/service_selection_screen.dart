import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ServiceSelectionScreen extends StatelessWidget {
  const ServiceSelectionScreen({super.key});

  // Демонстрационный список услуг
  final List<Map<String, String>> services = const [
    {'id': 's1', 'name': 'Получить посылку или письмо', 'icon': 'inventory'},
    {'id': 's2', 'name': 'Отправить посылку или письмо', 'icon': 'mark_email_read'},
    {'id': 's3', 'name': 'Финансовые услуги (переводы, пенсии)', 'icon': 'account_balance_wallet'},
    {'id': 's4', 'name': 'Прочие услуги', 'icon': 'more_horiz'},
  ];

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'inventory': return Icons.inventory;
      case 'mark_email_read': return Icons.mark_email_read;
      case 'account_balance_wallet': return Icons.account_balance_wallet;
      default: return Icons.more_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0055A5),
        title: const Text('Выбор услуги', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Отделение: 101000, г. Москва, ул. Мясницкая, 26',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                const Text('Выберите услугу для записи:', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                ...services.map((service) => Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Icon(_getIcon(service['icon']!), color: const Color(0xFF0055A5), size: 32),
                    title: Text(service['name']!, style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Переходим на экран записи, передавая название услуги
                      context.push('/booking', extra: service['name']);
                    },
                  ),
                )),
                const Divider(height: 48),
                Center(
                  child: TextButton.icon(
                    onPressed: () => context.push('/qr-entry'),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Я уже в отделении (ввести код)'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0055A5),
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}