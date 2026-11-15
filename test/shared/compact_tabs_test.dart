import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/shared/widgets/compact_tabs.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 400, height: 600, child: child)),
);

void main() {
  testWidgets('keeps both tabs mounted and switches between them', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const CompactTabs(
          firstLabel: 'Terminal',
          secondLabel: 'Archivos',
          first: Text('terminal-content'),
          second: Text('files-content'),
        ),
      ),
    );

    // The offstage tab stays mounted (IndexedStack): its state and channels
    // survive a tab switch instead of being rebuilt.
    expect(find.text('terminal-content'), findsOneWidget);
    expect(find.text('files-content', skipOffstage: false), findsOneWidget);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);

    await tester.tap(find.byKey(const Key('compact-tab-files')));
    await tester.pump();
    expect(find.text('files-content'), findsOneWidget);
    expect(find.text('terminal-content', skipOffstage: false), findsOneWidget);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);

    await tester.tap(find.byKey(const Key('compact-tab-terminal')));
    await tester.pump();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
  });
}
