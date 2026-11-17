import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  test('256-colour and true-colour SGR keep the text and change the cell', () {
    final terminal = Terminal();
    terminal.write('\x1b[38;5;196mR\x1b[0m');
    terminal.write('\x1b[38;2;1;2;3mT\x1b[0m');

    expect(terminal.buffer.getText(), contains('RT'));
    final line = terminal.buffer.lines[0];
    expect(line.getForeground(0), isNot(line.getForeground(1)));
  });

  test('ANSI colours of the 16-colour palette are rendered', () {
    final terminal = Terminal();
    terminal.write(
      '\x1b[31mr\x1b[32mg\x1b[33my\x1b[34mb\x1b[35mm\x1b[36mc\x1b[0m',
    );
    final line = terminal.buffer.lines[0];
    final colors = <int>{for (var i = 0; i < 6; i++) line.getForeground(i)};

    expect(terminal.buffer.getText(), contains('rgybmc'));
    expect(colors.length, 6, reason: 'each ANSI slot has its own colour');
  });
}
