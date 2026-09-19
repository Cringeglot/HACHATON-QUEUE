import 'package:flutter/material.dart';
import '../../models/ticket.dart';

/// Рабочее место оператора одного окна.
///
/// Сейчас используется mock-очередь.
/// Когда backend будет готов, mock-методы можно будет заменить
/// на реальные вызовы API, не переделывая интерфейс.
class OperatorDashboard extends StatefulWidget {
  const OperatorDashboard({super.key});

  @override
  State<OperatorDashboard> createState() => _OperatorDashboardState();
}

class _OperatorDashboardState extends State<OperatorDashboard> {
  bool isWindowOpen = true;

  final int windowNumber = 3;

  // Полный список услуг отделения.
  final List<String> allServices = const [
    'Паспорт РФ',
    'Справки',
    'Посылки',
    'Финансовые услуги',
  ];

  // Услуги, которые обслуживает это окно.
  Set<String> windowServices = {
    'Паспорт РФ',
    'Справки',
    'Посылки',
  };

  // ---------------------------------------------------------------------------
  // MOCK-ОЧЕРЕДЬ
  // ---------------------------------------------------------------------------

  final List<Ticket> _queue = [
    Ticket(
      id: '1',
      number: 'A-042',
      sourceType: 'BOOKING',
      status: 'WAITING',
      serviceId: 'service_1',
      windowNumber: null,
      clientToken: 'token_123',
      createdAt: '2026-09-18T10:00:00Z',
      estimatedWaitMin: 5,
    ),
    Ticket(
      id: '2',
      number: 'B-018',
      sourceType: 'QR',
      status: 'WAITING',
      serviceId: 'service_2',
      windowNumber: null,
      clientToken: 'token_456',
      createdAt: '2026-09-18T10:02:00Z',
      estimatedWaitMin: 8,
    ),
    Ticket(
      id: '3',
      number: 'C-031',
      sourceType: 'WALK_IN',
      status: 'WAITING',
      serviceId: 'service_3',
      windowNumber: null,
      clientToken: 'token_789',
      createdAt: '2026-09-18T10:04:00Z',
      estimatedWaitMin: 12,
    ),
    Ticket(
      id: '4',
      number: 'A-043',
      sourceType: 'BOOKING',
      status: 'WAITING',
      serviceId: 'service_1',
      windowNumber: null,
      clientToken: 'token_111',
      createdAt: '2026-09-18T10:06:00Z',
      estimatedWaitMin: 15,
    ),
    Ticket(
      id: '5',
      number: 'B-019',
      sourceType: 'QR',
      status: 'WAITING',
      serviceId: 'service_2',
      windowNumber: null,
      clientToken: 'token_222',
      createdAt: '2026-09-18T10:08:00Z',
      estimatedWaitMin: 18,
    ),
  ];

  // Талон, который сейчас обслуживает оператор.
  Ticket? currentTicket;

  // Счётчик для новых талонов.
  int _walkInCounter = 50;

  // ---------------------------------------------------------------------------
  // ВЫЗОВ СЛЕДУЮЩЕГО КЛИЕНТА
  // ---------------------------------------------------------------------------

  void _callNext() {
    if (!isWindowOpen) return;

    // Если клиент уже находится в работе, второй раз ничего не делаем.
    if (currentTicket != null) {
      if (currentTicket!.status == 'IN_SERVICE') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сначала завершите обслуживание текущего клиента'),
          ),
        );
        return;
      }
    }

    if (_queue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Очередь пуста'),
        ),
      );
      return;
    }

    // Берём первого талона из очереди.
    final nextTicket = _queue.removeAt(0);

  setState(() {
      currentTicket = nextTicket.copyWith(
        status: 'IN_SERVICE',
        windowNumber: windowNumber.toString(), // Добавлено .toString()
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Клиент ${nextTicket.number}, пожалуйста, пройдите в окно №$windowNumber',
        ),
      ),
    );

    // TODO:
    // POST /api/windows/{windowNumber}/call
  }

  // ---------------------------------------------------------------------------
  // ЗАВЕРШЕНИЕ ОБСЛУЖИВАНИЯ
  // ---------------------------------------------------------------------------

  void _complete() {
    if (currentTicket == null) return;

    final ticketNumber = currentTicket!.number;

    setState(() {
      currentTicket = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Обслуживание талона $ticketNumber завершено'),
      ),
    );

    // TODO:
    // POST /api/tickets/{id}/complete
  }

  // ---------------------------------------------------------------------------
  // ВЕРНУТЬ В ОЧЕРЕДЬ
  // ---------------------------------------------------------------------------

  void _returnToQueue() {
    if (currentTicket == null) return;

    final ticket = currentTicket!;

    // Возвращаем талон в начало mock-очереди.
    final returnedTicket = ticket.copyWith(
      status: 'WAITING',
      windowNumber: null,
    );

    setState(() {
      _queue.insert(0, returnedTicket);
      currentTicket = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Талон ${ticket.number} возвращён в очередь',
        ),
      ),
    );

    // TODO:
    // POST /api/tickets/{id}/return
    //
    // В реальном backend createdAt должен сохраниться,
    // чтобы клиент не потерял накопленное время ожидания.
  }

  // ---------------------------------------------------------------------------
  // ПЕРЕНАПРАВЛЕНИЕ
  // ---------------------------------------------------------------------------

  Future<void> _redirect() async {
    if (currentTicket == null) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        String targetType = 'window';

        int targetWindow = windowNumber == 1 ? 2 : 1;

        String targetService = allServices.first;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Перенаправить клиента'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioListTile<String>(
                    title: const Text('В другое окно'),
                    value: 'window',
                    groupValue: targetType,
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        targetType = value;
                      });
                    },
                  ),
                  if (targetType == 'window')
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 32,
                        bottom: 8,
                      ),
                      child: DropdownButton<int>(
                        value: targetWindow,
                        isExpanded: true,
                        items: [1, 2, 3, 4, 5]
                            .where((number) => number != windowNumber)
                            .map(
                              (number) => DropdownMenuItem<int>(
                                value: number,
                                child: Text('Окно № $number'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            targetWindow = value;
                          });
                        },
                      ),
                    ),
                  RadioListTile<String>(
                    title: const Text('На другую услугу'),
                    value: 'service',
                    groupValue: targetType,
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        targetType = value;
                      });
                    },
                  ),
                  if (targetType == 'service')
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: DropdownButton<String>(
                        value: targetService,
                        isExpanded: true,
                        items: allServices
                            .map(
                              (service) => DropdownMenuItem<String>(
                                value: service,
                                child: Text(service),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            targetService = value;
                          });
                        },
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      {
                        'type': targetType,
                        'value': targetType == 'window'
                            ? '$targetWindow'
                            : targetService,
                      },
                    );
                  },
                  child: const Text('Перенаправить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || currentTicket == null) return;

    final ticketNumber = currentTicket!.number;

    setState(() {
      currentTicket = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['type'] == 'window'
              ? 'Талон $ticketNumber перенаправлен в окно № ${result['value']}'
              : 'Талон $ticketNumber перенаправлен на услугу «${result['value']}»',
        ),
      ),
    );

    // TODO:
    // POST /api/tickets/{id}/redirect
    //
    // body:
    // {
    //   targetWindow: ...,
    //   targetService: ...
    // }
  }

  // ---------------------------------------------------------------------------
  // ДОБАВИТЬ КЛИЕНТА ИЗ ЖИВОЙ ОЧЕРЕДИ
  // ---------------------------------------------------------------------------

  Future<void> _addWalkIn() async {
    final service = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Добавить клиента из живой очереди'),
          children: allServices
              .map(
                (service) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context, service);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(service),
                  ),
                ),
              )
              .toList(),
        );
      },
    );

    if (service == null || !mounted) return;

    _walkInCounter++;

    final newTicket = Ticket(
      id: 'walk_in_$_walkInCounter',
      number: 'C-$_walkInCounter',
      sourceType: 'WALK_IN',
      status: 'WAITING',
      serviceId: service,
      windowNumber: null,
      clientToken: 'walk_in_token_$_walkInCounter',
      createdAt: DateTime.now().toIso8601String(),
      estimatedWaitMin: _queue.length * 5 + 5,
    );

    setState(() {
      _queue.add(newTicket);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Талон ${newTicket.number} добавлен в живую очередь',
        ),
      ),
    );

    // TODO:
    // POST /api/tickets
    //
    // body:
    // {
    //   source: 'WALK_IN',
    //   serviceId: service,
    //   officeId: ...
    // }
  }

  // ---------------------------------------------------------------------------
  // СООБЩИТЬ О ПРОБЛЕМЕ
  // ---------------------------------------------------------------------------

  Future<void> _reportIssue() async {
    String issueType = 'technical';

    final controller = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Сообщить о проблеме'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<String>(
                    value: issueType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'technical',
                        child: Text('Техническая'),
                      ),
                      DropdownMenuItem(
                        value: 'operational',
                        child: Text('Операционная'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        issueType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Опишите проблему',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Отправить'),
                ),
              ],
            );
          },
        );
      },
    );

    final description = controller.text.trim();
    controller.dispose();

    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Проблема зафиксирована'),
        ),
      );

      // TODO:
      // POST /api/incidents
      //
      // body:
      // {
      //   windowNumber: windowNumber,
      //   type: issueType,
      //   description: description
      // }
    }
  }

  // ---------------------------------------------------------------------------
  // РЕДАКТИРОВАНИЕ УСЛУГ ОКНА
  // ---------------------------------------------------------------------------

  Future<void> _editServices() async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        final selection = {...windowServices};

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Обслуживаемые услуги'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: allServices
                      .map(
                        (service) => CheckboxListTile(
                          title: Text(service),
                          value: selection.contains(service),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selection.add(service);
                              } else {
                                selection.remove(service);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, selection);
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        windowServices = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Услуги окна обновлены'),
        ),
      );

      // TODO:
      // PUT /api/windows/{windowNumber}/services
    }
  }

  // ---------------------------------------------------------------------------
  // ОТКРЫТИЕ / ЗАКРЫТИЕ ОКНА
  // ---------------------------------------------------------------------------

  Future<void> _handleWindowToggle(bool open) async {
    if (!open && currentTicket != null) {
      final ticketNumber = currentTicket!.number;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Закрыть окно?'),
            content: Text(
              'У окна есть активный клиент $ticketNumber. '
              'При закрытии его талон будет возвращён в очередь.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Закрыть окно'),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;

      final returnedTicket = currentTicket!.copyWith(
        status: 'WAITING',
        windowNumber: null,
      );

      setState(() {
        _queue.insert(0, returnedTicket);
        currentTicket = null;
        isWindowOpen = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Окно закрыто. Талон $ticketNumber возвращён в очередь.',
          ),
        ),
      );

      // TODO:
      // POST /api/windows/{windowNumber}/close

      return;
    }

    setState(() {
      isWindowOpen = open;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          open ? 'Окно №$windowNumber открыто' : 'Окно №$windowNumber закрыто',
        ),
      ),
    );

    // TODO:
    // POST /api/windows/{windowNumber}/open
    // POST /api/windows/{windowNumber}/close
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // -------------------------------------------------------------------
          // ЛЕВАЯ ПАНЕЛЬ
          // -------------------------------------------------------------------
          Container(
            width: 310,
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.store,
                      size: 32,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Окно № $windowNumber',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                const Text(
                  'Статус окна',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 8),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isWindowOpen ? 'Открыто' : 'Закрыто',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isWindowOpen ? Colors.green : Colors.red,
                    ),
                  ),
                  value: isWindowOpen,
                  activeThumbColor: Colors.green,
                  onChanged: _handleWindowToggle,
                ),

                const Divider(height: 35),

                // ----------------------------------------------------------------
                // ОЧЕРЕДЬ
                // ----------------------------------------------------------------

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue[100]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people,
                        color: Colors.blue,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'В очереди',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${_queue.length}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ----------------------------------------------------------------
                // УСЛУГИ
                // ----------------------------------------------------------------

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Обслуживаемые услуги:',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _editServices,
                      child: const Text('Изменить'),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: windowServices
                      .map(_buildServiceChip)
                      .toList(),
                ),

                const Spacer(),

                // ----------------------------------------------------------------
                // ДОБАВИТЬ КЛИЕНТА
                // ----------------------------------------------------------------

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isWindowOpen ? _addWalkIn : null,
                    icon: const Icon(Icons.person_add),
                    label: const Text(
                      'Добавить из живой очереди',
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ----------------------------------------------------------------
                // ПРОБЛЕМА
                // ----------------------------------------------------------------

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _reportIssue,
                    icon: const Icon(
                      Icons.report_problem_outlined,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Сообщить о проблеме',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // -------------------------------------------------------------------
          // ЦЕНТРАЛЬНАЯ ЧАСТЬ
          // -------------------------------------------------------------------

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  // Верхняя панель.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Рабочее место оператора',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isWindowOpen
                              ? Colors.green[50]
                              : Colors.red[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isWindowOpen ? 'Окно открыто' : 'Окно закрыто',
                          style: TextStyle(
                            color: isWindowOpen
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Center(
                        child: currentTicket == null
                            ? _buildEmptyState()
                            : _buildCurrentTicket(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ПУСТОЕ СОСТОЯНИЕ
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 650), // Плавающая ширина[cite: 13]
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _queue.isEmpty
                ? Icons.hourglass_empty
                : Icons.notifications_none,
            size: 80,
            color: Colors.grey[400],
          ),

          const SizedBox(height: 20),

          Text(
            _queue.isEmpty
                ? 'Очередь пуста'
                : 'Готовы вызвать следующего клиента',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 10),

          Text(
            _queue.isEmpty
                ? 'В данный момент ожидающих клиентов нет'
                : 'В очереди ожидают ${_queue.length} клиентов',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 30),

          ElevatedButton.icon(
            onPressed: isWindowOpen && _queue.isNotEmpty
                ? _callNext
                : null,
            icon: const Icon(Icons.call),
            label: const Text(
              'Вызвать следующего',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 18,
              ),
            ),
          ),

          if (_queue.isNotEmpty) ...[
            const SizedBox(height: 25),
            _buildQueuePreview(),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ТЕКУЩИЙ КЛИЕНТ
  // ---------------------------------------------------------------------------

  Widget _buildCurrentTicket() {
    final ticket = currentTicket!;

    return SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650), // Плавающая ширина[cite: 13]
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 50,
          vertical: 40,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Текущий клиент',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              ticket.number,
              style: const TextStyle(
                fontSize: 96,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),

            const SizedBox(height: 10),

            _buildSourceBadge(ticket.sourceType),

            const SizedBox(height: 16),

            Text(
              'Услуга: ${ticket.serviceId}',
              style: const TextStyle(
                fontSize: 17,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Ожидаемое время: ~${ticket.estimatedWaitMin} мин',
              style: const TextStyle(
                fontSize: 17,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Клиент обслуживается',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 35),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _buildActionButton(
                  Icons.check_circle,
                  'Завершить',
                  Colors.green,
                  _complete,
                ),
                _buildActionButton(
                  Icons.undo,
                  'Вернуть в очередь',
                  Colors.orange,
                  _returnToQueue,
                ),
                _buildActionButton(
                  Icons.swap_horiz,
                  'Перенаправить',
                  Colors.purple,
                  _redirect,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ПРЕДПРОСМОТР ОЧЕРЕДИ
  // ---------------------------------------------------------------------------

Widget _buildQueuePreview() {
  return Container(
    width: 500,
    constraints: const BoxConstraints(
      maxHeight: 300,
    ),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.grey[200]!,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Следующие в очереди',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: ListView.builder(
            itemCount: _queue.length,
            itemBuilder: (context, index) {
              final ticket = _queue[index];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        ticket.number,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildSmallSourceBadge(
                        ticket.sourceType,
                      ),
                    ),
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

  // ---------------------------------------------------------------------------
  // CHIP УСЛУГИ
  // ---------------------------------------------------------------------------

  Widget _buildServiceChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.blue[50],
      labelStyle: const TextStyle(
        color: Colors.blue,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BADGE ИСТОЧНИКА
  // ---------------------------------------------------------------------------

Widget _buildSourceBadge(String? sourceType) {
    Color color;
    String text;

    // Приводим к нижнему регистру для безопасности
    switch (sourceType?.toLowerCase()) {
      case 'appointment': // Заменили BOOKING на appointment
        color = Colors.green;
        text = 'Предварительная запись';
        break;

      case 'qr': // Заменили QR на qr
        color = Colors.blue;
        text = 'QR-код';
        break;

      case 'live': // Заменили WALK_IN на live
        color = Colors.orange;
        text = 'Живая очередь';
        break;

      default:
        color = Colors.grey;
        text = sourceType ?? 'Неизвестно';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Маленький badge для списка очереди.
Widget _buildSmallSourceBadge(String? sourceType) {
    String text;

    switch (sourceType?.toLowerCase()) {
      case 'appointment':
        text = 'Запись';
        break;
      case 'qr':
        text = 'QR';
        break;
      case 'live':
        text = 'Живая очередь';
        break;
      default:
        text = sourceType ?? '';
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: Colors.grey[700],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // КНОПКА ДЕЙСТВИЯ
  // ---------------------------------------------------------------------------

  Widget _buildActionButton(
    IconData icon,
    String text,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: isWindowOpen ? onPressed : null,
      icon: Icon(icon),
      label: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        minimumSize: const Size(180, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// COPY WITH ДЛЯ TICKET
// -----------------------------------------------------------------------------

extension TicketCopy on Ticket {
  Ticket copyWith({
    String? id,
    String? number,
    String? sourceType,
    String? status,
    String? serviceId,
    String? windowNumber, // Исправлено: int? заменено на String?
    String? clientToken,
    String? createdAt,
    int? estimatedWaitMin,
  }) {
    return Ticket(
      id: id ?? this.id,
      number: number ?? this.number,
      sourceType: sourceType ?? this.sourceType,
      status: status ?? this.status,
      serviceId: serviceId ?? this.serviceId,
      windowNumber: windowNumber ?? this.windowNumber,
      clientToken: clientToken ?? this.clientToken,
      createdAt: createdAt ?? this.createdAt,
      estimatedWaitMin: estimatedWaitMin ?? this.estimatedWaitMin,
    );
  }
}