import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/features/sftp/domain/remote_entry.dart';

RemoteEntry entry({
  String name = 'file.txt',
  int? mode,
  int size = 0,
  DateTime? modifiedAt,
}) => RemoteEntry(
  name: name,
  path: '/dir/$name',
  type: RemoteEntry.typeOf(mode),
  size: size,
  modifiedAt: modifiedAt,
  modeValue: mode,
);

void main() {
  test('detects the entry type from POSIX mode bits', () {
    expect(RemoteEntry.typeOf(0x41ED), RemoteEntryType.directory); // 0755 dir
    expect(RemoteEntry.typeOf(0x81A4), RemoteEntryType.file); // 0644 file
    expect(RemoteEntry.typeOf(0xA1FF), RemoteEntryType.link); // 0777 symlink
    expect(RemoteEntry.typeOf(null), RemoteEntryType.other);
    expect(RemoteEntry.typeOf(0x0000), RemoteEntryType.other);
  });

  test('renders permissions like ls does', () {
    expect(entry(mode: 0x81A4).permissions, 'rw-r--r--');
    expect(entry(mode: 0x41ED).permissions, 'rwxr-xr-x');
    expect(entry(mode: 0x81E9).permissions, 'rwxr-x--x');
    expect(entry(mode: null).permissions, '---------');
  });

  test('summary flags match the entry type', () {
    final directory = entry(name: 'logs', mode: 0x41ED);
    final file = entry(mode: 0x81A4);

    expect(directory.isDirectory, isTrue);
    expect(directory.isFile, isFalse);
    expect(file.isFile, isTrue);
    expect(file.isDirectory, isFalse);
  });

  test('dot files are hidden', () {
    expect(entry(name: '.bashrc').isHidden, isTrue);
    expect(entry(name: 'bashrc').isHidden, isFalse);
  });
}
