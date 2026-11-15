import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_client/app/localizations.dart';
import 'package:ssh_client/app/theme/app_theme.dart';
import 'package:ssh_client/features/terminal/presentation/terminal_key_bar.dart';
import 'package:ssh_client/l10n/generated/app_localizations.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  locale: const Locale('es'),
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('sends escape, tab and arrow sequences', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(host(TerminalKeyBar(onInput: sent.add)));

    await tester.tap(find.byKey(const Key('keybar-esc-key')));
    await tester.tap(find.byKey(const Key('keybar-tab-key')));
    await tester.tap(find.byKey(const Key('keybar-arrow-up')));
    await tester.tap(find.byKey(const Key('keybar-arrow-left')));
    await tester.pump();

    expect(sent, ['\x1b', '\t', '\x1b[A', '\x1b[D']);
  });

  testWidgets('sends control characters and releases the latches', (
    tester,
  ) async {
    final sent = <String>[];
    await tester.pumpWidget(host(TerminalKeyBar(onInput: sent.add)));

    await tester.tap(find.byKey(const Key('keybar-ctrl-c')));
    await tester.tap(find.byKey(const Key('keybar-ctrl-d')));
    await tester.pump();
    expect(sent, ['\x03', '\x04']);
  });

  testWidgets('Alt prefixes the next bar key once', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(host(TerminalKeyBar(onInput: sent.add)));

    await tester.tap(find.byKey(const Key('keybar-alt')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('keybar-arrow-right')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('keybar-tab-key')));
    await tester.pump();

    expect(sent, ['\x1b\x1b[C', '\t']);
  });

  testWidgets('a control character forwarded by the soft keyboard path is not '
      'doubled', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(host(TerminalKeyBar(onInput: sent.add)));

    await tester.tap(find.byKey(const Key('keybar-ctrl-l')));
    await tester.pump();

    expect(sent.single, '\x0c');
  });
}
