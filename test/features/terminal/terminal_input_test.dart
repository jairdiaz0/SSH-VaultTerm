import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart';

/// Terminal input on desktop goes through raw key events (`hardwareKeyboardOnly`)
/// because xterm's IME text path does not deliver printable characters on
/// Windows. These tests fix the exact bytes that reach the pty.
Future<(Terminal, List<String>)> pumpTerminal(
  WidgetTester tester, {
  bool hardwareKeyboardOnly = true,
}) async {
  final terminal = Terminal();
  final output = <String>[];
  terminal.onOutput = output.add;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TerminalView(
          terminal,
          autofocus: true,
          hardwareKeyboardOnly: hardwareKeyboardOnly,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (terminal, output);
}

Future<void> press(WidgetTester tester, LogicalKeyboardKey key, String? char) =>
    tester.sendKeyEvent(key, character: char);

void main() {
  testWidgets('letters, capitals, digits and symbols reach the pty', (
    tester,
  ) async {
    final (_, output) = await pumpTerminal(tester);

    await press(tester, LogicalKeyboardKey.keyA, 'a');
    await press(tester, LogicalKeyboardKey.keyB, 'b');
    await press(tester, LogicalKeyboardKey.keyZ, 'Z');
    await press(tester, LogicalKeyboardKey.digit1, '1');
    await press(tester, LogicalKeyboardKey.slash, '/');
    await press(tester, LogicalKeyboardKey.semicolon, ';');
    await press(tester, LogicalKeyboardKey.space, ' ');
    await tester.pump();

    expect(output.join(), 'abZ1/; ');
  });

  testWidgets('every letter, digit and common symbol reaches the pty', (
    tester,
  ) async {
    final (_, output) = await pumpTerminal(tester);
    const expected =
        'abcdefghijklmnopqrstuvwxyz'
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        '0123456789-./; ';

    for (final character in expected.split('')) {
      await tester.sendKeyEvent(
        LogicalKeyboardKey(character.toLowerCase().codeUnitAt(0)),
        character: character,
      );
    }
    await tester.pump();

    expect(output.join(), expected);
  });

  testWidgets('shifted symbols reach the pty with their character', (
    tester,
  ) async {
    final (_, output) = await pumpTerminal(tester);
    const shifted = <(LogicalKeyboardKey, String)>[
      (LogicalKeyboardKey.minus, '_'),
      (LogicalKeyboardKey.semicolon, ':'),
      (LogicalKeyboardKey.digit1, '!'),
      (LogicalKeyboardKey.slash, '?'),
      (LogicalKeyboardKey.digit2, '@'),
      (LogicalKeyboardKey.digit4, r'$'),
    ];

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    for (final (key, character) in shifted) {
      await tester.sendKeyEvent(key, character: character);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(output.join(), '_:!?@\$');
  });

  testWidgets('accented characters keep their UTF-8 code point', (
    tester,
  ) async {
    final (_, output) = await pumpTerminal(tester);

    await press(tester, LogicalKeyboardKey.keyE, 'é');
    await press(tester, LogicalKeyboardKey.keyN, 'ñ');
    await tester.pump();

    expect(output.join(), 'éñ');
  });

  testWidgets('Enter, Tab and arrows send their control sequences', (
    tester,
  ) async {
    final (_, output) = await pumpTerminal(tester);

    await press(tester, LogicalKeyboardKey.enter, null);
    await press(tester, LogicalKeyboardKey.tab, null);
    await press(tester, LogicalKeyboardKey.arrowUp, null);
    await press(tester, LogicalKeyboardKey.arrowLeft, null);
    await tester.pump();

    final sent = output.join();
    expect(sent, contains('\r'));
    expect(sent, contains('\t'));
    expect(sent, contains('\x1b[A'));
    expect(sent, contains('\x1b[D'));
  });

  testWidgets('Ctrl+C sends the interrupt character and not a letter', (
    tester,
  ) async {
    final (_, output) = await pumpTerminal(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await press(tester, LogicalKeyboardKey.keyC, 'c');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(output.join(), '\x03');
  });

  testWidgets('paste forwards the pasted text unchanged', (tester) async {
    final (terminal, output) = await pumpTerminal(tester);

    terminal.paste('ls -la\n');
    await tester.pump();

    expect(output.join(), 'ls -la\n');
  });
}
