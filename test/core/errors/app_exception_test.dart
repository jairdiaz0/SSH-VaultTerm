import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/core/errors/app_exception.dart';

void main() {
  test('description exposes the code and the cause type only', () {
    final error = AppException(
      AppErrorCode.databaseKeyInvalid,
      cause: StateError('PRAGMA key = "x\'deadbeef" failed: secret detail'),
    );

    expect(error.description, 'databaseKeyInvalid (StateError)');
    expect(error.description, isNot(contains('deadbeef')));
    expect(error.description, isNot(contains('secret detail')));
    expect(error.toString(), isNot(contains('deadbeef')));
  });

  test('description without a cause is just the code', () {
    const error = AppException(AppErrorCode.notFound);

    expect(error.description, 'notFound');
  });

  test('fail throws a typed AppException', () {
    expect(
      () => failWith(AppErrorCode.conflict, cause: 'duplicate'),
      throwsA(
        isA<AppException>()
            .having((e) => e.code, 'code', AppErrorCode.conflict)
            .having((e) => e.description, 'description', 'conflict (String)'),
      ),
    );
  });
}
