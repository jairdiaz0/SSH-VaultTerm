import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_client/app/localizations.dart';
import 'package:ssh_client/app/theme/app_theme.dart';
import 'package:ssh_client/core/errors/app_exception.dart';
import 'package:ssh_client/shared/widgets/confirm_password_dialog.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  locale: const Locale('es'),
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: const [Locale('es')],
  home: child,
);

void main() {
  testWidgets('shows the error, clears the field and keeps the dialog open', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showConfirmPasswordDialog(
                context,
                title: 'Confirma tu contraseña',
                onConfirm: (password) async {
                  if (password != 'good') {
                    throw const AppException(AppErrorCode.invalidCredentials);
                  }
                },
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('confirm-password-field')),
      'bad',
    );
    await tester.tap(find.byKey(const Key('confirm-password-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('confirm-password-error')), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('confirm-password-field')),
    );
    expect(field.controller?.text, isEmpty);
    expect(result, isNull);

    await tester.enterText(
      find.byKey(const Key('confirm-password-field')),
      'good',
    );
    await tester.tap(find.byKey(const Key('confirm-password-submit')));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byKey(const Key('confirm-password-field')), findsNothing);
  });

  testWidgets('cancelling returns false and runs no confirmation', (
    tester,
  ) async {
    var calls = 0;
    bool? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showConfirmPasswordDialog(
                context,
                title: 'Confirma',
                onConfirm: (password) async {
                  calls++;
                },
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-password-cancel')));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(calls, 0);
  });
}
