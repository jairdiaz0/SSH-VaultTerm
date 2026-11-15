import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_tokens.dart';

enum MessageTone { error, warning, info, success }

/// Compact inline feedback block. Used instead of dialogs for recoverable
/// errors so the user keeps the form in place.
class InlineMessage extends StatelessWidget {
  const InlineMessage({
    super.key,
    required this.message,
    this.tone = MessageTone.error,
  });

  final String message;
  final MessageTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      MessageTone.error => context.colors.error,
      MessageTone.warning => context.tokens.warning,
      MessageTone.success => context.tokens.success,
      MessageTone.info => context.colors.onSurfaceVariant,
    };
    final icon = switch (tone) {
      MessageTone.error => Icons.error_outline,
      MessageTone.warning => Icons.warning_amber_outlined,
      MessageTone.success => Icons.check_circle_outline,
      MessageTone.info => Icons.info_outline,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(context.tokens.fieldRadius),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: context.texts.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
