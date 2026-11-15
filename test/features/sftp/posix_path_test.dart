import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/features/sftp/domain/posix_path.dart';

void main() {
  group('PosixPath.normalize', () {
    test('collapses separators, dots and parent references', () {
      expect(PosixPath.normalize('/a//b/./c/../d'), '/a/b/d');
      expect(PosixPath.normalize('/a/b/../../..'), '/');
      expect(PosixPath.normalize('a/b/../c'), 'a/c');
      expect(PosixPath.normalize('.'), '.');
      expect(PosixPath.normalize('/'), '/');
    });

    test('keeps leading parent references on relative paths', () {
      expect(PosixPath.normalize('a/../../b'), '../b');
      expect(PosixPath.normalize('../a'), '../a');
    });

    test('never escapes the root', () {
      expect(PosixPath.normalize('/../../etc'), '/etc');
      expect(PosixPath.normalize('/..'), '/');
    });
  });

  group('PosixPath.join', () {
    test('joins relative names onto absolute directories', () {
      expect(PosixPath.join('/', 'etc'), '/etc');
      expect(PosixPath.join('/home/user', 'file.txt'), '/home/user/file.txt');
      expect(PosixPath.join('/home/user/', 'file.txt'), '/home/user/file.txt');
    });

    test('an absolute name wins over the base', () {
      expect(PosixPath.join('/home/user', '/etc/passwd'), '/etc/passwd');
    });
  });

  group('PosixPath navigation', () {
    test('parent of the root is the root', () {
      expect(PosixPath.parent('/'), '/');
      expect(PosixPath.parent('/a'), '/');
      expect(PosixPath.parent('/a/b'), '/a');
      expect(PosixPath.parent('a'), '.');
    });

    test('basename handles the root and trailing separators', () {
      expect(PosixPath.basename('/'), '/');
      expect(PosixPath.basename('/a/b/'), 'b');
      expect(PosixPath.basename('file'), 'file');
    });

    test('segments feed the breadcrumbs', () {
      expect(PosixPath.segments('/'), isEmpty);
      expect(PosixPath.segments('/home/user'), ['home', 'user']);
    });
  });

  group('PosixPath.isWithin', () {
    test('accepts the directory itself and its children', () {
      expect(PosixPath.isWithin('/a', '/a'), isTrue);
      expect(PosixPath.isWithin('/a', '/a/b'), isTrue);
    });

    test('rejects siblings and prefixes that only look similar', () {
      expect(PosixPath.isWithin('/a', '/ab'), isFalse);
      expect(PosixPath.isWithin('/a', '/b'), isFalse);
      expect(PosixPath.isWithin('/a/b', '/a'), isFalse);
    });
  });
}
