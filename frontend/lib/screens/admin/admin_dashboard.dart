import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/app_config.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final Dio _dio = Dio(BaseOptions(baseUrl: AppConfig.httpBaseUrl));
  final _storage = const FlutterSecureStorage();

  bool _loading = false;

  int totalTickets = 0;
  int waitingTickets = 0;
  int calledTickets = 0;
  int completedTickets = 0;
  List<dynamic> _logs = [];

  // ИСПРАВЛЕНО: Текстовые контроллеры для ввода динамических параметров (Убран хардкод)
  final _targetWindowController = TextEditingController(text: '1');
  final _targetBranchController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  @override
  void dispose() {
    _targetWindowController.dispose();
    _targetBranchController.dispose();
    super.dispose();
  }

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _loading = true;
    });

    try {
      final options = await _getAuthOptions();
      
      final response = await _dio.get('/api/analytics', options: options);
      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          totalTickets = data['total'] ?? 0;
          waitingTickets = data['waiting'] ?? 0;
          calledTickets = data['called'] ?? 0;
          completedTickets = data['completed'] ?? 0;
        });
      }

      final logsResponse = await _dio.get('/api/logs', options: options);
      if (logsResponse.statusCode == 200) {
        setState(() {
          _logs = logsResponse.data;
        });
      }
    } catch (e) {
      print('Ошибка загрузки данных аналитики: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // 1. АДМИНИСТРАТИВНАЯ ФУНКЦИЯ: Открыть новое окно (Убран хардкод филиала)
  Future<void> _handleOpenWindow() async {
    try {
      final options = await _getAuthOptions();
      final branchId = int.tryParse(_targetBranchController.text.trim()) ?? 1;
      
      final response = await _dio.post(
        '/api/windows', 
        data: {'branch_id': branchId, 'number': '${totalTickets + 1}'}, 
        options: options
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('В ОПС №$branchId успешно добавлено Окно №${response.data['number']}!'), backgroundColor: Colors.green),
        );
        _loadAdminData();
      }
    } catch (e) {
      print('Ошибка открытия окна: $e');
    }
  }

  // 2. АДМИНИСТРАТИВНАЯ ФУНКЦИЯ: Принудительное закрытие окна (Убран хардкод ID окна)
  Future<void> _handleCloseWindow() async {
    try {
      final options = await _getAuthOptions();
      final windowNum = _targetWindowController.text.trim();
      
      final response = await _dio.post('/api/windows/$windowNum/close', options: options);
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Окно №$windowNum принудительно закрыто! Активный талон сброшен в очередь.'), backgroundColor: Colors.orange),
        );
        _loadAdminData();
      }
    } catch (e) {
      print('Ошибка принудительного закрытия окна: $e');
    }
  }

  // 3. АДМИНИСТРАТИВНАЯ ФУНКЦИЯ: Создать новое отделение
  Future<void> _handleCreateBranch() async {
    try {
      final options = await _getAuthOptions();
      final branchId = _targetBranchController.text.trim();
      final response = await _dio.post(
        '/api/branches', 
        data: {'name': 'Новый филиал Почты (ОПС №$branchId)'}, 
        options: options
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('В систему занесено отделение: ${response.data['name']}'), backgroundColor: Colors.green),
        );
        _loadAdminData();
      }
    } catch (e) {
      print('Ошибка создания отделения: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Панель руководителя отделения — Живая аналитика СУБД'),
        backgroundColor: const Color(0xFF0055A5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _loadAdminData),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => context.go('/login'))
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAdminData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading) const LinearProgressIndicator(color: Color(0xFF0055A5)),
              const SizedBox(height: 16),
              
              // Адаптивный ряд карточек статистики
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildStatCard('Всего талонов в базе', '$totalTickets', const Color(0xFF0055A5), Icons.assessment),
                  _buildStatCard('Ожидают вызова', '$waitingTickets', Colors.orange, Icons.people),
                  _buildStatCard('У операторов окон', '$calledTickets', Colors.green, Icons.play_arrow),
                  _buildStatCard('Обслуживание завершено', '$completedTickets', Colors.purple, Icons.check_circle),
                ],
              ),
              const SizedBox(height: 32),
              
              // ИСПРАВЛЕНО: Интерактивный интерактивный пульт управления без хардкода
              const Text('Пульт административного управления ОПС', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0055A5))),
              const SizedBox(height: 16),
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _targetBranchController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Целевой ID филиала (ОПС)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.map)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _targetWindowController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Целевой номер Окна оператора', border: OutlineInputBorder(), prefixIcon: Icon(Icons.desktop_windows)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _handleOpenWindow,
                            icon: const Icon(Icons.add_box),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0055A5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
                            label: const Text('Открыть новое Окно оператора', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                          ElevatedButton.icon(
                            onPressed: _handleCloseWindow,
                            icon: const Icon(Icons.disabled_by_default),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
                            label: const Text('Принудительно закрыть Окно', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                          ElevatedButton.icon(
                            onPressed: _handleCreateBranch,
                            icon: const Icon(Icons.domain_add),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
                            label: const Text('Зарегистрировать ОПС', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              _buildLogsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      width: 260,
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
                  ],
                ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogsCard() {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history, color: Color(0xFF0055A5)),
                SizedBox(width: 12),
                Text('Журнал действий системы (Реальное время)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0055A5))),
              ],
            ),
            const SizedBox(height: 16),
            _logs.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('Событий в журнале пока нет', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      
                      String operationName = log['event_type'] ?? '';
                      if (operationName == 'created') operationName = 'Зарегистрирован новый талон в СУБД';
                      if (operationName == 'call') operationName = 'Вызван к окну оператора';
                      if (operationName == 'complete') operationName = 'Обслуживание успешно завершено';
                      if (operationName == 'cancel') operationName = 'Талон отменён посетителем';
                      if (operationName == 'return_to_queue') operationName = 'Возвращён оператором обратно в очередь';

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Идентификатор талона ID-${log['ticket_id']}: $operationName',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
