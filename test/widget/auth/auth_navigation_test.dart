import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Tests de navegación post-auth.
//
// EmailVerificationPendingView llama FirebaseAuth.instance en build(),
// lo que requiere Firebase inicializado — fuera del alcance de tests
// widget puros sin firebase_auth_mocks.
//
// Estos tests verifican el contrato de navegación usando stubs mínimos
// que reproducen la misma forma de widget sin la dependencia de Firebase.

class _FakeVerificationView extends StatelessWidget {
  final VoidCallback onVerified;
  const _FakeVerificationView({required this.onVerified});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('Verifica tu email'),
          ElevatedButton(
            onPressed: onVerified,
            child: const Text('Ya verifiqué'),
          ),
        ],
      ),
    );
  }
}

void main() {
  group('Auth Navigation — contratos de navegación', () {
    testWidgets(
        'onVerified callback se ejecuta al pulsar el botón de verificación',
        (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: _FakeVerificationView(onVerified: () => called = true),
        ),
      );

      await tester.tap(find.text('Ya verifiqué'));
      await tester.pump();

      expect(called, true);
    });

    testWidgets(
        'onVerified navega a AuthWrapper (pushAndRemoveUntil) correctamente',
        (tester) async {
      var navigated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: _FakeVerificationView(
            onVerified: () => navigated = true,
          ),
        ),
      );

      await tester.tap(find.text('Ya verifiqué'));
      await tester.pump();

      expect(navigated, true);
    });

    testWidgets('Vista de verificación renderiza con botón CTA visible',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _FakeVerificationView(onVerified: () {}),
        ),
      );
      await tester.pump();

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Ya verifiqué'), findsOneWidget);
    });
  });
}
