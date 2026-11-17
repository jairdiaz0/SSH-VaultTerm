import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_vault_term/core/utils/app_logger.dart';

void main() {
  test('sensitive field names are never written', () {
    final lines = <String>[];
    final logger = AppLogger(minLevel: LogLevel.debug, sink: lines.add);

    logger.info('connect', {
      'host': 'example.com',
      'password': 'hunter2',
      'privateKey': '-----BEGIN OPENSSH PRIVATE KEY-----',
      'passphrase': 'x',
      'apiToken': 'abc',
      'port': 22,
    });

    final line = lines.single;
    expect(line, contains('host=example.com'));
    expect(line, contains('port=22'));
    expect(line, isNot(contains('hunter2')));
    expect(line, isNot(contains('BEGIN OPENSSH')));
    expect(line, isNot(contains('abc')));
    expect(line, contains(AppLogger.redactedValue));
  });

  test('min level filters lower severities', () {
    final lines = <String>[];
    final logger = AppLogger(minLevel: LogLevel.warning, sink: lines.add);

    logger.debug('debug-event');
    logger.info('info-event');
    logger.error('error-event');

    expect(lines.length, 1);
    expect(lines.single, contains('error-event'));
  });

  test('sensitive key detection covers common secret names', () {
    for (final key in [
      'password',
      'passphrase',
      'dbKey',
      'private_key',
      'pem',
      'token',
    ]) {
      expect(AppLogger.isSensitiveKey(key), isTrue, reason: key);
    }
    for (final key in ['host', 'port', 'username', 'elapsedMs']) {
      expect(AppLogger.isSensitiveKey(key), isFalse, reason: key);
    }
  });
}
