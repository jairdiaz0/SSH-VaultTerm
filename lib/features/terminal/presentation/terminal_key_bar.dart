import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';

/// Modifier and shortcut bar for touch terminals.
///
/// Ctrl/Alt are latches applied to the next key pressed **in this bar**. Applying
/// them to the soft keyboard needs a real device (the IME path is not
/// verifiable here), so that half is reported as unverified, not simulated.
class TerminalKeyBar extends StatefulWidget {
  const TerminalKeyBar({super.key, required this.onInput});

  final void Function(String data) onInput;

  @override
  State<TerminalKeyBar> createState() => _TerminalKeyBarState();
}

class _TerminalKeyBarState extends State<TerminalKeyBar> {
  bool _ctrl = false;
  bool _alt = false;

  void _send(String data) {
    var output = data;
    if (_ctrl && data.length == 1) {
      final code = data.toUpperCase().codeUnitAt(0);
      if (code >= 0x40 && code <= 0x5F) {
        output = String.fromCharCode(code - 0x40);
      }
    }
    if (_alt) output = '\x1b$output';
    setState(() {
      _ctrl = false;
      _alt = false;
    });
    widget.onInput(output);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.surfaceSecondary,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        children: [
          _toggle('Ctrl', _ctrl, () => setState(() => _ctrl = !_ctrl)),
          _toggle('Alt', _alt, () => setState(() => _alt = !_alt)),
          _key('Esc', 'esc-key', () => _send('\x1b')),
          _key('Tab', 'tab-key', () => _send('\t')),
          _key('↑', 'arrow-up', () => _send('\x1b[A')),
          _key('↓', 'arrow-down', () => _send('\x1b[B')),
          _key('→', 'arrow-right', () => _send('\x1b[C')),
          _key('←', 'arrow-left', () => _send('\x1b[D')),
          _key('C', 'ctrl-c', () => _send('\x03')),
          _key('D', 'ctrl-d', () => _send('\x04')),
          _key('L', 'ctrl-l', () => _send('\x0c')),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool active, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
    child: TextButton(
      key: Key('keybar-${label.toLowerCase()}'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: active
            ? AppColors.accent.withValues(alpha: 0.25)
            : Colors.transparent,
        minimumSize: const Size(40, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: Text(label),
    ),
  );

  Widget _key(String label, String keyName, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
    child: OutlinedButton(
      key: Key('keybar-$keyName'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(40, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: Text(label),
    ),
  );
}
