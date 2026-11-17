import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_vault_term/app/localizations.dart';
import 'package:ssh_vault_term/app/theme/app_theme.dart';
import 'package:ssh_vault_term/features/backup/data/backup_importer.dart';
import 'package:ssh_vault_term/features/backup/domain/backup_document.dart';
import 'package:ssh_vault_term/features/backup/presentation/backup_dialogs.dart';
import 'package:ssh_vault_term/l10n/generated/app_localizations.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  locale: const Locale('es'),
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

BackupDocument emptyDocument() => BackupDocument(
  formatVersion: 1,
  exportedAt: DateTime.utc(2026, 1, 1),
  profiles: const [],
  profileData: const [],
  credentials: const [],
);

const summary = BackupImportSummary(
  profiles: 2,
  collections: 3,
  connections: 4,
  knownHosts: 1,
  credentials: 5,
  conflicts: 1,
);

void main() {
  testWidgets('the export warning requires an explicit confirmation', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showExportWarning(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('export-warning-body')), findsOneWidget);
    expect(find.textContaining('ADVERTENCIA DE SEGURIDAD'), findsOneWidget);
    expect(find.textContaining('NO estará cifrado'), findsOneWidget);
    expect(find.textContaining('fuerza bruta'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-confirm')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('the import summary shows counts and returns the chosen mode', (
    tester,
  ) async {
    ImportChoice? choice;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              choice = await showImportSummary(
                context,
                document: emptyDocument(),
                summary: summary,
                localProfiles: const [],
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import-summary')), findsOneWidget);
    expect(
      find.text('2 perfiles · 4 conexiones · 5 credenciales'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('import-mode-replace-all')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Se borrarán los perfiles'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-confirm')));
    await tester.pumpAndSettle();

    expect(choice, isNotNull);
    expect(choice!.mode, BackupImportMode.replaceAll);
  });

  testWidgets(
    'replace-profile mode is unavailable without a matching profile',
    (tester) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showImportSummary(
                context,
                document: emptyDocument(),
                summary: summary,
                localProfiles: const [],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final tile = tester.widget<RadioListTile<BackupImportMode>>(
        find.byKey(const Key('import-mode-replace-profile')),
      );
      expect(tile.enabled, isFalse);
    },
  );
}
