import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/l10n/generated/app_localizations.dart';
import 'package:ssh_client/shared/widgets/resizable_split.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('es'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

const _first = SizedBox(key: Key('first'), child: Text('terminal'));
const _second = SizedBox(key: Key('second'), child: Text('files'));

void main() {
  testWidgets('shows both panels with a draggable divider', (tester) async {
    await tester.pumpWidget(
      _host(const ResizableSplit(first: _first, second: _second)),
    );

    expect(find.byKey(const Key('first')), findsOneWidget);
    expect(find.byKey(const Key('second')), findsOneWidget);

    final before = tester.getSize(find.byKey(const Key('first'))).width;
    await tester.drag(
      find.byKey(const Key('split-handle')),
      const Offset(120, 0),
    );
    await tester.pump();

    final after = tester.getSize(find.byKey(const Key('first'))).width;
    expect(after, greaterThan(before));
    final total = after + tester.getSize(find.byKey(const Key('second'))).width;
    expect(
      total,
      closeTo(792, 0.5),
      reason: 'the handle keeps 8 logical pixels',
    );
  });

  testWidgets('maximizes one panel and restores the split', (tester) async {
    await tester.pumpWidget(
      _host(const ResizableSplit(first: _first, second: _second)),
    );

    await tester.tap(find.byKey(const Key('maximize-first')));
    await tester.pump();
    expect(find.byKey(const Key('first')), findsOneWidget);
    expect(find.byKey(const Key('second')), findsNothing);
    expect(tester.getSize(find.byKey(const Key('first'))).width, 800);

    await tester.tap(find.byKey(const Key('restore-split')));
    await tester.pump();
    expect(find.byKey(const Key('second')), findsOneWidget);

    await tester.tap(find.byKey(const Key('maximize-second')));
    await tester.pump();
    expect(find.byKey(const Key('first')), findsNothing);
    expect(find.byKey(const Key('second')), findsOneWidget);
  });
}
