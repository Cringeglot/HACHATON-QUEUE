import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/client/ticket_screen.dart';

void main() {
  runApp(const EQueueApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/ticket',
  routes: [
    GoRoute(
      path: '/ticket',
      builder: (context, state) => const TicketScreen(),
    ),
  ],
);

class EQueueApp extends StatelessWidget {
  const EQueueApp({super.key});

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
      routerConfig: _router,
    );
  }
}