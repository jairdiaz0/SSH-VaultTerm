import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart';

void main() {
  test('the emulator keeps text and ANSI colors', () {
    final terminal = Terminal(maxLines: 100);

    terminal.write('\x1b[31mred\x1b[0m plain');

    expect(terminal.buffer.getText(), contains('red'));
    expect(terminal.buffer.getText(), contains('plain'));
    final line = terminal.buffer.lines[0];
    expect(
      line.getForeground(0),
      isNot(line.getForeground(5)),
      reason: 'the red cell must keep its own color',
    );
  });

  test('scrollback is bounded by the configured line count', () {
    // maxLines must stay above the view height (24 by default): xterm 4.0.0
    // mis-indexes its circular buffer when the scrollback is shorter than the
    // visible area. The app uses 10000 lines, far above that bound.
    final terminal = Terminal(maxLines: 100);

    for (var i = 0; i < 150; i++) {
      terminal.write('line $i\r\n');
    }

    expect(terminal.buffer.lines.length, lessThanOrEqualTo(100));
    expect(terminal.buffer.getText(), contains('line 149'));
  });

  test('user input is forwarded through onOutput', () {
    final terminal = Terminal();
    final output = <String>[];
    terminal.onOutput = output.add;

    terminal.textInput('ls');
    terminal.paste('echo hola');

    expect(output.join(), contains('ls'));
    expect(output.join(), contains('echo hola'));
  });

  testWidgets('TerminalView renders and reports its size to the emulator', (
    tester,
  ) async {
    final terminal = Terminal();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TerminalView(terminal))),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    terminal.write('hola mundo');
    await tester.pump();

    expect(terminal.buffer.getText(), contains('hola mundo'));
    expect(terminal.viewWidth, greaterThan(0));
    expect(terminal.viewHeight, greaterThan(0));
  });
}
