import 'dart:io';

/// The dedicated test server, read from `.env.test` or the process environment.
class TestServerConfig {
  const TestServerConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  final String host;
  final int port;
  final String username;
  final String password;

  static TestServerConfig? load() {
    final values = <String, String>{};
    final file = File('.env.test');
    if (file.existsSync()) {
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final index = trimmed.indexOf('=');
        if (index <= 0) continue;
        values[trimmed.substring(0, index)] = trimmed.substring(index + 1);
      }
    }
    String? read(String key) {
      final fromEnv = Platform.environment[key];
      if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
      final value = values[key];
      return (value == null || value.isEmpty) ? null : value;
    }

    final host = read('SSH_TEST_HOST');
    final username = read('SSH_TEST_USER');
    final password = read('SSH_TEST_PASSWORD');
    if (host == null || username == null || password == null) return null;
    return TestServerConfig(
      host: host,
      port: int.tryParse(read('SSH_TEST_PORT') ?? '') ?? 22,
      username: username,
      password: password,
    );
  }
}
