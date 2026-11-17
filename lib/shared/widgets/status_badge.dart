import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_tokens.dart';

enum StatusTone { neutral, success, warning, danger }

/// Dot plus label. The label always accompanies the colour, so the state is
/// never communicated by colour alone.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.semanticLabel,
  });

  final String label;
  final StatusTone tone;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      StatusTone.success => context.tokens.success,
      StatusTone.warning => context.tokens.warning,
      StatusTone.danger => context.colors.error,
      StatusTone.neutral => context.colors.onSurfaceVariant,
    };
    return Semantics(
      label: semanticLabel ?? label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSpacing.sm,
            height: AppSpacing.sm,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
