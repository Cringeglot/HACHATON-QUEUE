
import 'package:flutter/material.dart';


class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {


  // Пока backend не предоставил отдельные admin endpoints,
  // здесь нет выдуманных значений статистики.
  bool _loading = false;
  String? _error;

  final TextEditingController bookingDueController =
      TextEditingController();

  final TextEditingController bookingEarlyController =
      TextEditingController();

  final TextEditingController qrController =
      TextEditingController();

  final TextEditingController liveQueueController =
      TextEditingController();

  final TextEditingController waitBonusController =
      TextEditingController();

  final TextEditingController maxWaitController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  @override
  void dispose() {
    bookingDueController.dispose();
    bookingEarlyController.dispose();
    qrController.dispose();
    liveQueueController.dispose();
    waitBonusController.dispose();
    maxWaitController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Здесь намеренно нет фиктивного API-вызова.
      //
      // Сейчас ApiClient не содержит admin endpoints.
      // Когда появится api_router.dart, сюда подключим:
      // - статистику;
      // - окна;
      // - очередь;
      // - аномалии;
      // - настройки приоритета.
      //
      // Не придумываем endpoint заранее.

      await Future<void>.delayed(Duration.zero);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Не удалось загрузить данные: $e';
      });
    } finally {
  if (mounted) {
    setState(() {
      _loading = false;
    });
  }
}
  }

  void _savePriorityConfig() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'API для сохранения настроек приоритета пока не подключён',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Панель руководителя отделения'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loading ? null : _loadAdminData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAdminData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),

              if (_error != null)
                Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadAdminData,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                ),

              // ---------------------------------------------------------------
              // СТАТИСТИКА
              // ---------------------------------------------------------------

              Row(
                children: [
                  _buildStatCard(
                    'В очереди',
                    '—',
                    Colors.blue,
                    Icons.people,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Среднее ожидание',
                    '—',
                    Colors.green,
                    Icons.timer,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Активные окна',
                    '—',
                    Colors.orange,
                    Icons.store,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ---------------------------------------------------------------
              // ОСНОВНАЯ ЧАСТЬ
              // ---------------------------------------------------------------

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildWindowsCard(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: _buildAnomaliesCard(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ---------------------------------------------------------------
              // НАСТРОЙКИ ПРИОРИТЕТА
              // ---------------------------------------------------------------

              _buildPriorityConfigCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWindowsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.store,
                  color: Colors.indigo,
                ),
                SizedBox(width: 8),
                Text(
                  'Статус окон',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Данные об окнах пока не загружены',
              subtitle:
                  'После подключения admin API здесь появятся '
                  'статусы окон и текущие талоны.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnomaliesCard() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  'Аномалии',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildEmptyState(
              icon: Icons.check_circle_outline,
              title: 'Нет данных',
              subtitle:
                  'После подключения API здесь появятся '
                  'отклонения и незавершённые талоны.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 40,
            color: Colors.grey,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityConfigCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.tune,
                  color: Colors.indigo,
                ),
                SizedBox(width: 10),
                Text(
                  'Настройки приоритета очереди',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              'Значения будут загружаться и сохраняться через backend.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 20),

            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                _buildPriorityField(
                  'Предзапись — время наступило',
                  bookingDueController,
                ),
                _buildPriorityField(
                  'Предзапись — заранее',
                  bookingEarlyController,
                ),
                _buildPriorityField(
                  'QR-код',
                  qrController,
                ),
                _buildPriorityField(
                  'Живая очередь',
                  liveQueueController,
                ),
                _buildPriorityField(
                  'Бонус за минуту ожидания',
                  waitBonusController,
                ),
                _buildPriorityField(
                  'Максимальное ожидание живой очереди',
                  maxWaitController,
                ),
              ],
            ),

            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _savePriorityConfig,
                icon: const Icon(Icons.save),
                label: const Text('Сохранить настройки'),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildPriorityField(
    String label,
    TextEditingController controller,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 350), // Заменили SizedBox(width: 300)[cite: 11]
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
