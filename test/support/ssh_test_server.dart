import 'dart:io';

/// Connection data for the dedicated test server, read from `.env.test` (never
/// committed) or from the process environment.
///
/// The password is never printed: [toString] omits it on purpose.
class SshTestServer {
  const SshTestServer({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  final String host;
  final int port;
  final String username;
  final String password;

  /// Returns null when the environment has no test server configured; callers
  /// skip their integration tests in that case.
  static SshTestServer? load({String root = '.'}) {
    final values = _readEnvFile('$root/.env.test');
    String? read(String key) {
      final fromEnvironment = Platform.environment[key];
      if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
        return fromEnvironment;
      }
      final fromFile = values[key];
      return (fromFile == null || fromFile.isEmpty) ? null : fromFile;
    }

    final host = read('SSH_TEST_HOST');
    final username = read('SSH_TEST_USER');
    final password = read('SSH_TEST_PASSWORD');
    if (host == null || username == null || password == null) return null;

    return SshTestServer(
      host: host,
      port: int.tryParse(read('SSH_TEST_PORT') ?? '') ?? 22,
      username: username,
      password: password,
    );
  }

  static Map<String, String> _readEnvFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return const {};
    final values = <String, String>{};
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final separator = trimmed.indexOf('=');
      if (separator <= 0) continue;
      values[trimmed.substring(0, separator)] = trimmed.substring(
        separator + 1,
      );
    }
    return values;
  }

  @override
  String toString() => 'SshTestServer($host:$port, user: $username)';
}
