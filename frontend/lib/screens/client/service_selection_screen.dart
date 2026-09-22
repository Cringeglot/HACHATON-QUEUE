import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';

class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({super.key});

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  int? _selectedBranchId;
  List<Map<String, dynamic>> _branches = [];
  bool _isLoadingBranches = true;

  final List<Map<String, String>> services = const [
    {'id': '1', 'name': 'Получить посылку или письмо', 'icon': 'inventory'},
    {'id': '2', 'name': 'Отправить посылку или письмо', 'icon': 'mark_email_read'},
    {'id': '3', 'name': 'Финансовые услуги', 'icon': 'account_balance_wallet'},
    {'id': '4', 'name': 'Прочие услуги', 'icon': 'more_horiz'},
  ];

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final branches = await ApiClient().getBranches();
    if (mounted) {
      setState(() {
        _branches = branches;
        _isLoadingBranches = false;
        if (_branches.isNotEmpty) {
          _selectedBranchId = _branches.first['id'] as int;
        }
      });
    }
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'inventory': return Icons.inventory;
      case 'mark_email_read': return Icons.mark_email_read;
      case 'account_balance_wallet': return Icons.account_balance_wallet;
      default: return Icons.more_horiz;
    }
  }

  // Диалог выбора формата записи для конкретной услуги
  void _showServiceActionSheet(Map<String, String> service) {
    if (_selectedBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите отделение')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['name']!,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_month, color: Color(0xFF0055A5)),
                  title: const Text('Записаться на время'),
                  subtitle: const Text('Предварительная запись на выбранную дату'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push(
                      '/booking',
                      extra: {
                        'serviceName': service['name']!,
                        'serviceId': service['id']!,
                        'branchId': _selectedBranchId.toString(),
                      },
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.qr_code_2, color: Color(0xFF0055A5)),
                  title: const Text('Я в отделении (взять QR-талон)'),
                  subtitle: const Text('Получить талон в живую очередь сейчас'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push(
                      '/qr-entry',
                      extra: {
                        'branchId': _selectedBranchId.toString(),
                        'serviceId': service['id']!, // Передается ID именно выбранной услуги!
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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
                const Text('Выберите отделение:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _isLoadingBranches
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        hint: const Text('Выберите отделение'),
                        value: _selectedBranchId,
                        isExpanded: true,
                        items: _branches.map((branch) {
                          return DropdownMenuItem<int>(
                            value: branch['id'] as int,
                            child: Text(branch['name'].toString()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedBranchId = value);
                        },
                      ),
                const SizedBox(height: 32),
                
                if (_selectedBranchId != null) ...[
                  const Text('Выберите услугу:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...services.map((service) => Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Icon(_getIcon(service['icon']!), color: const Color(0xFF0055A5), size: 32),
                      title: Text(service['name']!, style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showServiceActionSheet(service),
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}