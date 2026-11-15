import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/server_collection.dart';
import '../../shell/presentation/shell_controller.dart';

/// Creates or renames a collection. Returns true when it was saved.
class CollectionDialog extends StatefulWidget {
  const CollectionDialog({super.key, required this.controller, this.existing});

  final ShellController controller;
  final ServerCollection? existing;

  static Future<bool> show(
    BuildContext context, {
    required ShellController controller,
    ServerCollection? existing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          CollectionDialog(controller: controller, existing: existing),
    );
    return saved ?? false;
  }

  @override
  State<CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<CollectionDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.fieldRequired);
      return;
    }

    final existing = widget.existing;
    final collections = widget.controller.session.collections;
    final now = DateTime.now();
    if (existing == null) {
      collections.insert(
        ServerCollection(
          id: const Uuid().v4(),
          name: name,
          position: collections.nextPosition(),
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      collections.update(existing.copyWith(name: name, updatedAt: now));
    }
    widget.controller.reload();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(
        editing ? l10n.collectionFormEditTitle : l10n.collectionFormNewTitle,
      ),
      content: SizedBox(
        width: 380,
        child: TextField(
          key: const Key('collection-name-field'),
          controller: _name,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.collectionNameLabel,
            errorText: _error,
          ),
          onSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('collection-save-button'),
          onPressed: _save,
          child: Text(l10n.saveAction),
        ),
      ],
    );
  }
}
