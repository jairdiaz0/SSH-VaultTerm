import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import '../../ssh/data/ssh_connection.dart';

/// A terminal emulator bound to one remote shell (pty) on an open connection.
///
/// Output is written only into the in-memory [Terminal] buffer: nothing is
/// persisted and commands are never logged. Closing the terminal closes its
/// channel, never the SSH connection, which may still serve SFTP.
class RemoteTerminal {
  RemoteTerminal._({
    required this.terminal,
    required this.session,
    required this.connection,
  });

  final Terminal terminal;
  final SSHSession session;
  final SshConnection connection;

  final ValueNotifier<int?> exitCode = ValueNotifier(null);
  bool _closed = false;

  /// Opens a pty and wires the bidirectional flow:
  /// remote stdout/stderr → [terminal]; terminal input/resize → pty.
  static Future<RemoteTerminal> open(
    SshConnection connection, {
    int columns = 80,
    int rows = 24,
    int scrollbackLines = 10000,
    String termType = 'xterm-256color',
  }) async {
    final session = await connection.openShell(
      pty: SSHPtyConfig(width: columns, height: rows, type: termType),
    );
    final terminal = Terminal(
      maxLines: scrollbackLines,
      platform: _targetPlatform(),
    );
    final remote = RemoteTerminal._(
      terminal: terminal,
      session: session,
      connection: connection,
    );

    // A streaming decoder keeps multi-byte characters split across SSH
    // packets intact, and never throws on binary output (`allowMalformed`).
    const decoder = Utf8Decoder(allowMalformed: true);
    // `map<List<int>>` widens the runtime type too: `Stream.transform` casts
    // the transformer to `StreamTransformer<Uint8List, String>` otherwise.
    Stream<String> decoded(Stream<Uint8List> source) =>
        source.map<List<int>>((chunk) => chunk).transform(decoder);
    decoded(session.stdout).listen(terminal.write);
    decoded(session.stderr).listen(terminal.write);
    unawaited(session.done.then((_) => remote._onSessionDone()));

    terminal.onOutput = (data) {
      if (remote._closed) return;
      session.stdin.add(utf8.encode(data));
    };
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      if (remote._closed) return;
      session.resizeTerminal(width, height, pixelWidth, pixelHeight);
    };
    return remote;
  }

  bool get isClosed => _closed;

  /// Resizes the emulator, which forwards the new size to the server.
  void resize(int width, int height) => terminal.resize(width, height, 0, 0);

  /// Closes the channel. The SSH connection stays usable.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    session.close();
    try {
      await session.done.timeout(const Duration(seconds: 5));
    } catch (_) {
      // The channel may already be gone; nothing left to release.
    }
  }

  void dispose() => exitCode.dispose();

  void _onSessionDone() {
    _closed = true;
    exitCode.value = session.exitCode;
  }

  static TerminalTargetPlatform _targetPlatform() {
    if (Platform.isWindows) return TerminalTargetPlatform.windows;
    if (Platform.isMacOS) return TerminalTargetPlatform.macos;
    if (Platform.isLinux) return TerminalTargetPlatform.linux;
    if (Platform.isAndroid) return TerminalTargetPlatform.android;
    if (Platform.isIOS) return TerminalTargetPlatform.ios;
    return TerminalTargetPlatform.unknown;
  }
}
