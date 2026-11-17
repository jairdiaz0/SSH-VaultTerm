/// What a remote directory entry is.
enum RemoteEntryType { file, directory, link, other }

/// One entry of a remote directory, already detached from the SFTP packet.
class RemoteEntry {
  const RemoteEntry({
    required this.name,
    required this.path,
    required this.type,
    this.size = 0,
    this.modifiedAt,
    this.modeValue,
  });

  final String name;

  /// Absolute remote path of the entry.
  final String path;
  final RemoteEntryType type;
  final int size;
  final DateTime? modifiedAt;

  /// Raw POSIX mode bits, when the server sent them.
  final int? modeValue;

  bool get isDirectory => type == RemoteEntryType.directory;
  bool get isFile => type == RemoteEntryType.file;

  /// Hidden files start with a dot, same convention as OpenSSH clients.
  bool get isHidden => name.startsWith('.');

  /// `rwxr-x---` style permissions, or `---------` when unknown.
  String get permissions {
    final mode = modeValue;
    if (mode == null) return '---------';
    const letters = ['r', 'w', 'x', 'r', 'w', 'x', 'r', 'w', 'x'];
    final buffer = StringBuffer();
    for (var index = 0; index < 9; index++) {
      final mask = 1 << (8 - index);
      buffer.write((mode & mask) != 0 ? letters[index] : '-');
    }
    return buffer.toString();
  }

  /// File type from the POSIX `S_IFMT` bits.
  static RemoteEntryType typeOf(int? mode) {
    if (mode == null) return RemoteEntryType.other;
    return switch (mode & 0xF000) {
      0x4000 => RemoteEntryType.directory,
      0x8000 => RemoteEntryType.file,
      0xA000 => RemoteEntryType.link,
      _ => RemoteEntryType.other,
    };
  }
}
