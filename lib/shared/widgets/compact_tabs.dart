import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Two tabs for narrow layouts that keep both children alive.
///
/// An `IndexedStack` means switching between terminal and files never rebuilds
/// the SSH channels: the session survives the tab change, which is what the
/// Android layout needs.
class CompactTabs extends StatefulWidget {
  const CompactTabs({
    super.key,
    required this.firstLabel,
    required this.secondLabel,
    required this.first,
    required this.second,
  });

  final String firstLabel;
  final String secondLabel;
  final Widget first;
  final Widget second;

  @override
  State<CompactTabs> createState() => _CompactTabsState();
}

class _CompactTabsState extends State<CompactTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              _tab(widget.firstLabel, 0, const Key('compact-tab-terminal')),
              _tab(widget.secondLabel, 1, const Key('compact-tab-files')),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: [widget.first, widget.second],
          ),
        ),
      ],
    );
  }

  Widget _tab(String label, int index, Key key) {
    final selected = _index == index;
    return Expanded(
      child: TextButton(
        key: key,
        onPressed: () => setState(() => _index = index),
        style: TextButton.styleFrom(
          backgroundColor: selected
              ? AppColors.elevated
              : AppColors.surfaceSecondary,
          shape: const RoundedRectangleBorder(),
          minimumSize: const Size(0, 36),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
