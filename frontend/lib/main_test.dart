import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/session_storage.dart';
import 'screens/client/ticket_screen.dart';
import 'screens/client/service_selection_screen.dart';
import 'screens/client/booking_screen.dart';
import 'screens/client/qr_entry_screen.dart';
import 'screens/auth/login_screen.dart'; // Ваша авторизация
import 'screens/operators/operator_dashboard.dart'; // Ваш оператор
import 'screens/admin/admin_dashboard.dart'; // Ваш админ

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Принудительно открываем экран логина сотрудников как стартовую страницу в тестах
  final String initialRoute = '/login';

  final GoRouter router = GoRouter(
    initialLocation: initialRoute,
    routes: [
      GoRoute(
        path: '/client-services',
        builder: (context, state) => const ServiceSelectionScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/operator-dashboard',
        builder: (context, state) => const OperatorDashboard(),
      ),
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: '/booking',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final serviceName = extra?['serviceName']?.toString() ?? 'Неизвестная услуга';
          final serviceId = extra?['serviceId']?.toString() ?? 's1';
          final branchId = extra?['branchId']?.toString() ?? '101000';

          return BookingScreen(
            serviceName: serviceName,
            serviceId: serviceId,
            branchId: branchId,
          );
        },
      ),
      GoRoute(
        path: '/qr-entry',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return QrEntryScreen(
            branchId: extra?['branchId']?.toString() ?? '1',
            serviceId: extra?['serviceId']?.toString() ?? '1',
          );
        },
      ),
      GoRoute(
        path: '/ticket',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final ticketId = state.uri.queryParameters['ticketId'] ?? extra?['ticketId'] ?? '';
          final clientToken = state.uri.queryParameters['clientToken'] ?? extra?['clientToken'] ?? '';
          
          return TicketScreen(
            ticketId: ticketId,
            clientToken: clientToken,
          );
        },
      ),
    ],
  );

  runApp(EQueueApp(router: router));
}

class EQueueApp extends StatelessWidget {
  final GoRouter router;

  const EQueueApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Е-СУО ПочтаТеч (Тестовая сборка)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF0055A5),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0055A5),
          primary: const Color(0xFF0055A5),
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
