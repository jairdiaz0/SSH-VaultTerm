import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../app/error_messages.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/connection.dart';
import '../../connections/data/credential_service.dart';
import '../../shell/presentation/shell_controller.dart';
import '../../ssh/domain/private_key_inspector.dart';

/// Creates or edits a connection and its credential.
///
/// Secrets go straight to the platform secret store: this dialog never writes a
/// password or a private key to the profile database, and never logs one.
class ConnectionFormDialog extends StatefulWidget {
  const ConnectionFormDialog({
    super.key,
    required this.controller,
    this.existing,
  });

  final ShellController controller;
  final Connection? existing;

  static Future<bool> show(
    BuildContext context, {
    required ShellController controller,
    Connection? existing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          ConnectionFormDialog(controller: controller, existing: existing),
    );
    return saved ?? false;
  }

  @override
  State<ConnectionFormDialog> createState() => _ConnectionFormDialogState();
}

class _ConnectionFormDialogState extends State<ConnectionFormDialog> {
  late final Connection? _existing = widget.existing;
  late final TextEditingController _name = TextEditingController(
    text: _existing?.name ?? '',
  );
  late final TextEditingController _host = TextEditingController(
    text: _existing?.hostname ?? '',
  );
  late final TextEditingController _port = TextEditingController(
    text: '${_existing?.port ?? 22}',
  );
  late final TextEditingController _user = TextEditingController(
    text: _existing?.username ?? '',
  );
  late final TextEditingController _password = TextEditingController();
  late final TextEditingController _passphrase = TextEditingController();
  late final TextEditingController _description = TextEditingController(
    text: _existing?.description ?? '',
  );

  late AuthenticationType _authType =
      _existing?.authType ?? AuthenticationType.password;
  late ConnectionType _connectionType =
      _existing?.connectionType ?? ConnectionType.ssh;
  late String? _collectionId = _existing?.collectionId;
  late bool _favorite = _existing?.favorite ?? false;
  String? _privateKeyPem;
  String? _keyStatus;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _host,
      _port,
      _user,
      _password,
      _passphrase,
      _description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _importKey() async {
    final l10n = AppLocalizations.of(context);
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;

    final bytes = await files.first.readAsBytes();
    if (bytes.isEmpty) {
      setState(() => _error = l10n.errorPrivateKeyInvalid);
      return;
    }
    final pem = utf8.decode(bytes, allowMalformed: true);
    setState(() {
      _privateKeyPem = pem;
      _error = null;
      _keyStatus = _describeKey(l10n, pem);
    });
  }

  String _describeKey(AppLocalizations l10n, String pem) {
    if (PrivateKeyInspector.requiresPassphrase(pem)) {
      return l10n.privateKeyLoadedEncrypted('OpenSSH');
    }
    try {
      return l10n.privateKeyLoaded(
        PrivateKeyInspector.inspect(pem).displayType,
      );
    } on AppException catch (error) {
      _error = describeAppError(l10n, error);
      return '';
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    final host = _host.text.trim();
    final user = _user.text.trim();
    final port = int.tryParse(_port.text.trim());

    if (name.isEmpty || host.isEmpty || user.isEmpty) {
      setState(() => _error = l10n.fieldRequired);
      return;
    }
    if (host.contains(RegExp(r'[\s/@]')) || host.contains('://')) {
      setState(() => _error = l10n.invalidHost);
      return;
    }
    if (port == null || port < 1 || port > 65535) {
      setState(() => _error = l10n.invalidPort);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    if (widget.controller.requireReauthOnEdit) {
      final password = await showDialog<String>(
        context: context,
        builder: (_) => const _ReauthDialog(),
      );
      if (!mounted) return;
      if (password == null) {
        setState(() => _saving = false);
        return;
      }
      final confirmed = await widget.controller.confirmPassword(password);
      if (!mounted) return;
      if (!confirmed) {
        setState(() {
          _saving = false;
          _error = l10n.errorInvalidCredentials;
        });
        return;
      }
    }

    final credentials = widget.controller.services.credentials;
    final profileId = widget.controller.session.profile.id;
    final credentialId = _existing?.credentialId ?? const Uuid().v4();

    try {
      if (_authType == AuthenticationType.password) {
        final password = _password.text;
        if (password.isEmpty) {
          final keep =
              _existing != null &&
              _existing.authType == AuthenticationType.password;
          if (!keep) {
            setState(() {
              _saving = false;
              _error = l10n.credentialRequired;
            });
            return;
          }
        } else {
          await credentials.save(
            profileId: profileId,
            credentialId: credentialId,
            secret: CredentialSecret(password: password),
          );
        }
      } else {
        final pem = _privateKeyPem;
        if (pem == null) {
          final keep =
              _existing != null &&
              _existing.authType == AuthenticationType.privateKey;
          if (!keep) {
            setState(() {
              _saving = false;
              _error = l10n.credentialRequired;
            });
            return;
          }
        } else {
          final passphrase = _passphrase.text;
          final info = PrivateKeyInspector.inspect(pem, passphrase: passphrase);
          setState(() => _keyStatus = info.displayType);
          await credentials.save(
            profileId: profileId,
            credentialId: credentialId,
            secret: CredentialSecret(
              privateKeyPem: pem,
              passphrase: passphrase.isEmpty ? null : passphrase,
            ),
          );
        }
      }

      final now = DateTime.now();
      final connections = widget.controller.session.connections;
      final description = _description.text.trim();
      final connection = Connection(
        id: _existing?.id ?? const Uuid().v4(),
        collectionId: _collectionId,
        name: name,
        hostname: host,
        port: port,
        username: user,
        authType: _authType,
        connectionType: _connectionType,
        credentialId: credentialId,
        description: description.isEmpty ? null : description,
        tags: _existing?.tags ?? const [],
        favorite: _favorite,
        position: _existing?.position ?? connections.nextPosition(),
        createdAt: _existing?.createdAt ?? now,
        updatedAt: now,
      );
      if (_existing == null) {
        connections.insert(connection);
      } else {
        connections.update(connection);
      }
      widget.controller.reload();
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (error) {
      setState(() {
        _saving = false;
        _error = describeAppError(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final collections = widget.controller.collections;
    return AlertDialog(
      title: Text(
        _existing == null
            ? l10n.connectionFormNewTitle
            : l10n.connectionFormEditTitle,
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(
                key: 'connection-name-field',
                controller: _name,
                label: l10n.connectionNameLabel,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _field(
                      key: 'connection-host-field',
                      controller: _host,
                      label: l10n.connectionHostLabel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: _field(
                      key: 'connection-port-field',
                      controller: _port,
                      label: l10n.connectionPortLabel,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(
                key: 'connection-user-field',
                controller: _user,
                label: l10n.connectionUserLabel,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.connectionTypeLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    key: const Key('type-ssh-chip'),
                    label: Text(l10n.connectionTypeSsh),
                    selected: _connectionType == ConnectionType.ssh,
                    onSelected: (_) => setState(() {
                      _connectionType = ConnectionType.ssh;
                    }),
                  ),
                  ChoiceChip(
                    key: const Key('type-sftp-chip'),
                    label: Text(l10n.connectionTypeSftp),
                    selected: _connectionType == ConnectionType.sftp,
                    onSelected: (_) => setState(() {
                      _connectionType = ConnectionType.sftp;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.authMethodLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    key: const Key('auth-password-chip'),
                    label: Text(l10n.authPasswordLabel),
                    selected: _authType == AuthenticationType.password,
                    onSelected: (_) => setState(() {
                      _authType = AuthenticationType.password;
                    }),
                  ),
                  ChoiceChip(
                    key: const Key('auth-key-chip'),
                    label: Text(l10n.authPrivateKeyLabel),
                    selected: _authType == AuthenticationType.privateKey,
                    onSelected: (_) => setState(() {
                      _authType = AuthenticationType.privateKey;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_authType == AuthenticationType.password)
                _field(
                  key: 'connection-password-field',
                  controller: _password,
                  label: l10n.passwordLabel,
                  obscureText: true,
                  helper: _existing == null ? null : l10n.passwordKeepHint,
                )
              else ...[
                Row(
                  children: [
                    OutlinedButton.icon(
                      key: const Key('connection-import-key'),
                      onPressed: _saving ? null : _importKey,
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: Text(l10n.privateKeyImportAction),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _keyStatus ?? '',
                        key: const Key('connection-key-status'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(
                  key: 'connection-passphrase-field',
                  controller: _passphrase,
                  label: l10n.passphraseLabel,
                  obscureText: true,
                  helper: l10n.passphraseOptionalHint,
                ),
              ],
              const SizedBox(height: 12),
              _field(
                key: 'connection-description-field',
                controller: _description,
                label: l10n.descriptionLabel,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: const Key('connection-collection-field'),
                initialValue: _collectionId,
                decoration: InputDecoration(labelText: l10n.collectionLabel),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.noCollectionOption),
                  ),
                  for (final collection in collections)
                    DropdownMenuItem<String?>(
                      value: collection.id,
                      child: Text(collection.name),
                    ),
                ],
                onChanged: (value) => setState(() => _collectionId = value),
              ),
              SwitchListTile(
                key: const Key('connection-favorite-switch'),
                value: _favorite,
                onChanged: (value) => setState(() => _favorite = value),
                title: Text(l10n.favoriteLabel),
                contentPadding: EdgeInsets.zero,
              ),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('connection-form-error'),
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('connection-save-button'),
          onPressed: _saving ? null : _save,
          child: Text(l10n.saveAction),
        ),
      ],
    );
  }

  Widget _field({
    required String key,
    required TextEditingController controller,
    required String label,
    bool autofocus = false,
    bool obscureText = false,
    String? helper,
    TextInputType? keyboardType,
  }) => TextField(
    key: Key(key),
    controller: controller,
    autofocus: autofocus,
    obscureText: obscureText,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label, helperText: helper),
  );
}

/// Asks for the profile password when the profile requires reauthentication on
/// sensitive edits. Returns null when the user cancels.
class _ReauthDialog extends StatefulWidget {
  const _ReauthDialog();

  @override
  State<_ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends State<_ReauthDialog> {
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.reauthPromptTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.reauthPromptBody),
            const SizedBox(height: 12),
            TextField(
              key: const Key('reauth-password-field'),
              controller: _password,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.passwordLabel),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('reauth-confirm'),
          onPressed: () => Navigator.of(context).pop(_password.text),
          child: Text(l10n.unlockAction),
        ),
      ],
    );
  }
}
