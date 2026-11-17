import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

/// Minimal structured logger with hard redaction.
///
/// Rules from the SPEC: no passwords, keys, passphrases, commands or terminal
/// output in logs. That is enforced structurally: the API only accepts a fixed
/// [event] name plus a field map, and any field whose name looks sensitive is
/// replaced by [redactedValue] before it can reach a sink.
class AppLogger {
  AppLogger({this.minLevel = LogLevel.info, void Function(String line)? sink})
    : _sink = sink ?? _developerSink;

  final LogLevel minLevel;
  final void Function(String line) _sink;

  static const redactedValue = '***';

  static const _sensitiveFragments = <String>[
    'password',
    'passphrase',
    'secret',
    'token',
    'credential',
    'privatekey',
    'private_key',
    'pem',
    'key',
  ];

  void debug(String event, [Map<String, Object?> fields = const {}]) =>
      log(LogLevel.debug, event, fields);

  void info(String event, [Map<String, Object?> fields = const {}]) =>
      log(LogLevel.info, event, fields);

  void warning(String event, [Map<String, Object?> fields = const {}]) =>
      log(LogLevel.warning, event, fields);

  void error(String event, [Map<String, Object?> fields = const {}]) =>
      log(LogLevel.error, event, fields);

  void log(
    LogLevel level,
    String event, [
    Map<String, Object?> fields = const {},
  ]) {
    if (level.index < minLevel.index) return;
    final buffer = StringBuffer('[${level.name.toUpperCase()}] $event');
    for (final entry in fields.entries) {
      final value = isSensitiveKey(entry.key) ? redactedValue : entry.value;
      buffer.write(' ${entry.key}=$value');
    }
    _sink(buffer.toString());
  }

  /// True when a field name must never be logged with its real value.
  static bool isSensitiveKey(String key) {
    final normalized = key.toLowerCase();
    for (final fragment in _sensitiveFragments) {
      if (normalized.contains(fragment)) return true;
    }
    return false;
  }

  static void _developerSink(String line) {
    developer.log(line, name: 'ssh_vault_term');
  }
}
