import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Low-level helpers: AES-256-GCM, PBKDF2 and HKDF. Everything is bytes in,
/// bytes out so the rest of the app never touches algorithm details.
class VaultCrypto {
  VaultCrypto._();

  static final _aes = AesGcm.with256bits();
  static final _rng = Random.secure();
  static const int pbkdf2Iterations = 200000;

  static Uint8List randomBytes(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _rng.nextInt(256)));

  static Future<Uint8List> pbkdf2(String secret, Uint8List salt,
      {int iterations = pbkdf2Iterations}) async {
    // Runs on a background isolate: 200k iterations would freeze the UI.
    return Isolate.run(() async {
      final algo = Pbkdf2(
          macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);
      final key = await algo.deriveKey(
          secretKey: SecretKey(utf8.encode(secret)), nonce: salt);
      return Uint8List.fromList(await key.extractBytes());
    });
  }

  static Future<Uint8List> hkdf(Uint8List input, String info) async {
    final algo = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final key = await algo.deriveKey(
        secretKey: SecretKey(input),
        nonce: const <int>[],
        info: utf8.encode(info));
    return Uint8List.fromList(await key.extractBytes());
  }

  /// Returns nonce(12) | ciphertext | mac(16).
  static Future<Uint8List> seal(Uint8List key, List<int> plain) async {
    final box = await _aes.encrypt(plain, secretKey: SecretKey(key));
    return Uint8List.fromList(box.concatenation());
  }

  /// Throws [WrongKeyException] if the key is wrong or the data was altered.
  static Future<Uint8List> open(Uint8List key, List<int> sealed) async {
    try {
      final box = SecretBox.fromConcatenation(sealed,
          nonceLength: 12, macLength: 16);
      final out = await _aes.decrypt(box, secretKey: SecretKey(key));
      return Uint8List.fromList(out);
    } on SecretBoxAuthenticationError {
      throw WrongKeyException();
    }
  }

  static String b64(List<int> b) => base64Encode(b);
  static Uint8List unb64(String s) => base64Decode(s);
}

class WrongKeyException implements Exception {
  @override
  String toString() => 'Wrong key or corrupted data';
}

/// The recovery key is 160 random bits shown as 8 groups of 4 characters
/// (Crockford base32, no I/L/O/U), e.g. 7K2M-9XQD-....
class RecoveryKey {
  RecoveryKey._();
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  static Uint8List generate() => VaultCrypto.randomBytes(20);

  static String format(Uint8List bytes) {
    final sb = StringBuffer();
    var buffer = 0, bits = 0;
    for (final b in bytes) {
      buffer = (buffer << 8) | b;
      bits += 8;
      while (bits >= 5) {
        sb.write(_alphabet[(buffer >> (bits - 5)) & 31]);
        bits -= 5;
      }
      buffer &= (1 << bits) - 1;
    }
    final s = sb.toString();
    return [for (var i = 0; i < s.length; i += 4) s.substring(i, i + 4)]
        .join('-');
  }

  /// Returns null if the text is not a valid recovery key.
  static Uint8List? parse(String input) {
    final s = input
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '')
        .replaceAll('O', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1');
    if (s.length != 32) return null;
    final out = <int>[];
    var buffer = 0, bits = 0;
    for (final ch in s.split('')) {
      final v = _alphabet.indexOf(ch);
      if (v < 0) return null;
      buffer = (buffer << 5) | v;
      bits += 5;
      if (bits >= 8) {
        out.add((buffer >> (bits - 8)) & 255);
        bits -= 8;
        buffer &= (1 << bits) - 1;
      }
    }
    return Uint8List.fromList(out);
  }
}
