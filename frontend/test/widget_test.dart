import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/client/ticket_screen.dart';

void main() {
  testWidgets('Проверка отображения экрана талона', (WidgetTester tester) async {
    final testRouter = GoRouter(
      initialLocation: '/ticket',
      routes: [
        GoRoute(
          path: '/ticket',
          builder: (context, state) => const TicketScreen(
            ticketId: 'test-id',
            clientToken: 'test-token',
          ),
        ),
      ],
    );

    await tester.pumpWidget(EQueueApp(router: testRouter));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Электронный талон'), findsOneWidget);
  });
}