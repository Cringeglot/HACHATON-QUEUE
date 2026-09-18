import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/session_storage.dart';
import 'screens/client/ticket_screen.dart';
import 'screens/client/service_selection_screen.dart';
import 'screens/client/booking_screen.dart';
import 'screens/client/qr_entry_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final savedSession = await SessionStorage.getSession();
  
  final String initialRoute = (savedSession != null)
      ? '/ticket?ticketId=${savedSession['ticketId']}&clientToken=${savedSession['clientToken']}'
      : '/';

  final GoRouter router = GoRouter(
    initialLocation: initialRoute,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ServiceSelectionScreen(),
      ),
      GoRoute(
        path: '/booking',
        builder: (context, state) {
          final serviceName = state.extra as String? ?? 'Неизвестная услуга';
          return BookingScreen(serviceName: serviceName);
        },
      ),
      GoRoute(
        path: '/qr-entry',
        builder: (context, state) => const QrEntryScreen(),
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
      title: 'Е-СУО ПочтаТеч',
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