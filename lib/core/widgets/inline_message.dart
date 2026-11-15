import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

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
      MessageTone.error => AppColors.danger,
      MessageTone.warning => AppColors.warning,
      MessageTone.success => AppColors.accentSecondary,
      MessageTone.info => AppColors.textSecondary,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(Radius.circular(AppShape.radius)),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            tone == MessageTone.error
                ? Icons.error_outline
                : Icons.info_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
