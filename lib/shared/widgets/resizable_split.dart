import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

enum SplitMode { both, first, second }

/// Two panels with a draggable divider and the ability to maximize one of them.
///
/// The session behind each panel is owned by the caller: changing [SplitMode]
/// only changes layout, never state, so switching views keeps the terminal and
/// its SFTP channel alive.
class ResizableSplit extends StatefulWidget {
  const ResizableSplit({
    super.key,
    required this.first,
    required this.second,
    this.initialFraction = 0.6,
    this.minFraction = 0.2,
    this.maxFraction = 0.8,
  });

  final Widget first;
  final Widget second;
  final double initialFraction;
  final double minFraction;
  final double maxFraction;

  @override
  State<ResizableSplit> createState() => ResizableSplitState();
}

class ResizableSplitState extends State<ResizableSplit> {
  late double _fraction = widget.initialFraction;
  SplitMode _mode = SplitMode.both;

  SplitMode get mode => _mode;

  /// Test seam: changes the layout mode without tapping the toolbar.
  void setMode(SplitMode mode) => setState(() => _mode = mode);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Row(
                children: [
                  if (_mode != SplitMode.second)
                    SizedBox(
                      width: _mode == SplitMode.first
                          ? width
                          : width * _fraction,
                      child: widget.first,
                    ),
                  if (_mode == SplitMode.both)
                    _Handle(
                      onDrag: (delta) => setState(() {
                        _fraction = (_fraction + delta / width).clamp(
                          widget.minFraction,
                          widget.maxFraction,
                        );
                      }),
                    ),
                  if (_mode != SplitMode.first) Expanded(child: widget.second),
                ],
              );
            },
          ),
        ),
        Container(
          height: 36,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                key: const Key('maximize-first'),
                tooltip: l10n.maximizePanelAction,
                icon: const Icon(Icons.first_page, size: 16),
                onPressed: () => setMode(SplitMode.first),
              ),
              IconButton(
                key: const Key('maximize-second'),
                tooltip: l10n.maximizePanelAction,
                icon: const Icon(Icons.last_page, size: 16),
                onPressed: () => setMode(SplitMode.second),
              ),
              if (_mode != SplitMode.both)
                IconButton(
                  key: const Key('restore-split'),
                  tooltip: l10n.restoreSplitAction,
                  icon: const Icon(Icons.vertical_split_outlined, size: 16),
                  onPressed: () => setMode(SplitMode.both),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.onDrag});

  final void Function(double delta) onDrag;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeColumn,
    child: GestureDetector(
      key: const Key('split-handle'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
      child: Container(width: 8, color: AppColors.border),
    ),
  );
}
