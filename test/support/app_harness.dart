import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/app/app_services.dart';
import 'package:ssh_client/app/session_controller.dart';
import 'package:ssh_client/app/theme/app_theme.dart';
import 'package:ssh_client/core/security/password_hasher.dart';
import 'package:ssh_client/core/storage/app_paths.dart';
import 'package:ssh_client/l10n/generated/app_localizations.dart';

import 'in_memory_secret_store.dart';
import 'test_context.dart';

/// Test-only stand-in for the Argon2id derivation.
///
/// `package:cryptography`'s Argon2 yields to the event loop with real timers,
/// which the fake-async zone of `testWidgets` never advances, so a widget test
/// driving the real KDF would hang. This fake is fast, deterministic and still
/// distinguishes passwords. Real Argon2 (including the RFC 9106 vector) is
/// covered by `test/core/security/password_hasher_test.dart`.
Future<Uint8List> testKeyDerivation(Argon2Request request) async {
  final input = <int>[...utf8.encode(request.password), 0, ...request.salt];
  var state = 0x811C9DC5;
  for (final byte in input) {
    state = (state ^ byte) * 16777619 & 0xFFFFFFFF;
  }
  final out = Uint8List(request.params.hashLength);
  for (var i = 0; i < out.length; i++) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
    out[i] = state & 0xFF;
  }
  return out;
}

/// Wires the real services (catalog + profile databases) against a temporary
/// directory, with the in-memory secret store, and mounts widgets the way the
/// app does: same theme, same delegates.
class AppHarness {
  AppHarness._({
    required this.root,
    required this.services,
    required this.controller,
  });

  final Directory root;
  final AppServices services;
  final SessionController controller;

  static Future<AppHarness> create() async {
    final root = Directory.systemTemp.createTempSync('ssh_client_app_test_');
    final services = await AppServices.fromStorage(
      secrets: InMemorySecretStore(),
      paths: AppPaths(root.path),
      hasher: PasswordHasher(derive: testKeyDerivation),
    );
    return AppHarness._(
      root: root,
      services: services,
      controller: SessionController(
        services: services,
        createParams: testArgon2Params,
      ),
    );
  }

  /// A locked-state controller sharing the same encrypted catalog, as after an
  /// app restart.
  SessionController restartedController() =>
      SessionController(services: services, createParams: testArgon2Params);

  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.dark(),
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );

  Future<void> dispose() async {
    controller.dispose();
    services.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}
