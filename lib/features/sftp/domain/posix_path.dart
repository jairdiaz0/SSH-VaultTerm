/// POSIX path rules for remote paths.
///
/// The local `path` package is deliberately not used: a remote server is always
/// POSIX, and mixing Windows separators with remote paths is a security and
/// compatibility bug (SPEC §10).
abstract final class PosixPath {
  static const root = '/';

  /// Collapses duplicate separators, `.` and `..` without ever going above
  /// the root. Always returns a path starting with `/` when [path] is absolute.
  static String normalize(String path) {
    if (path.isEmpty) return '.';
    final absolute = path.startsWith('/');
    final parts = <String>[];
    for (final segment in path.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (parts.isNotEmpty && parts.last != '..') {
          parts.removeLast();
        } else if (!absolute) {
          parts.add('..');
        }
        continue;
      }
      parts.add(segment);
    }
    final joined = parts.join('/');
    if (absolute) return joined.isEmpty ? '/' : '/$joined';
    return joined.isEmpty ? '.' : joined;
  }

  static bool isAbsolute(String path) => path.startsWith('/');

  static String join(String base, String name) {
    if (name.isEmpty) return normalize(base);
    if (name.startsWith('/')) return normalize(name);
    if (base == '/' || base.isEmpty) return normalize('/$name');
    return '${normalize(base)}/$name';
  }

  /// Parent directory of [path]; the parent of `/` is `/`.
  static String parent(String path) {
    final normalized = normalize(path);
    if (normalized == '/' || normalized == '.') return normalized;
    final index = normalized.lastIndexOf('/');
    if (index < 0) return '.';
    if (index == 0) return '/';
    return normalized.substring(0, index);
  }

  static String basename(String path) {
    final normalized = normalize(path);
    if (normalized == '/') return '/';
    final index = normalized.lastIndexOf('/');
    return index < 0 ? normalized : normalized.substring(index + 1);
  }

  /// Breadcrumb parts of an absolute path; `/` yields an empty list.
  static List<String> segments(String path) =>
      normalize(path)
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList();

  /// True when [child] is [parent] itself or lives below it. Used to refuse
  /// operations that escape the current directory when that matters.
  static bool isWithin(String parent, String child) {
    final base = normalize(parent);
    final target = normalize(child);
    if (!target.startsWith(base)) return false;
    return target.length == base.length || target[base.length] == '/';
  }
}
