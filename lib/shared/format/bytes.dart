import 'package:intl/intl.dart';

/// Human-readable file size. Units are universal, so no l10n is involved.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final decimals = value >= 100 ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${units[unit]}';
}

String formatSpeed(double bytesPerSecond) =>
    '${formatBytes(bytesPerSecond.round())}/s';

final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

String formatRemoteDate(DateTime? date) =>
    date == null ? '—' : _dateFormat.format(date.toLocal());
