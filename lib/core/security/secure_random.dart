import 'dart:math';
import 'dart:typed_data';

/// CSPRNG-backed helpers for keys and salts.
///
/// `Random.secure()` is documented by the Dart SDK as cryptographically secure
/// and backed by the operating system entropy source, so no extra dependency is
/// introduced for this.
class CryptoRandom {
  CryptoRandom({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  Uint8List bytes(int length) {
    if (length <= 0) {
      throw ArgumentError.value(length, 'length', 'must be positive');
    }
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }

  String hex(int lengthInBytes) => toHex(bytes(lengthInBytes));
}

/// Lowercase hex encoding, the form SQLCipher raw keys are written in.
String toHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

Uint8List fromHex(String hex) {
  if (hex.length.isOdd) {
    throw ArgumentError.value(hex, 'hex', 'odd length');
  }
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// Compares two byte sequences in time independent of where they differ.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
