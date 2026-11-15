import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_icons.dart';
import '../../app/theme/app_tokens.dart';

/// Shared empty state: icon, title, optional message and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppIconSize.hero,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.texts.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: context.texts.bodySmall,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    ),
  );
}
