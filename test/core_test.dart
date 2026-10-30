import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/app_state.dart';
import 'package:vault/core/crypto.dart';
import 'package:vault/core/models.dart';

void main() {
  group('VaultCrypto', () {
    test('seal/open round trip', () async {
      final key = VaultCrypto.randomBytes(32);
      final sealed = await VaultCrypto.seal(key, utf8.encode('hello vault'));
      expect(utf8.decode(await VaultCrypto.open(key, sealed)), 'hello vault');
    });

    test('wrong key is rejected', () async {
      final sealed = await VaultCrypto.seal(VaultCrypto.randomBytes(32), [1, 2, 3]);
      expect(VaultCrypto.open(VaultCrypto.randomBytes(32), sealed),
          throwsA(isA<WrongKeyException>()));
    });

    test('tampered data is rejected', () async {
      final key = VaultCrypto.randomBytes(32);
      final sealed = await VaultCrypto.seal(key, utf8.encode('secret'));
      sealed[sealed.length ~/ 2] ^= 0xFF;
      expect(VaultCrypto.open(key, sealed), throwsA(isA<WrongKeyException>()));
    });

    test('pbkdf2 is deterministic per salt and differs across secrets', () async {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final a = await VaultCrypto.pbkdf2('123456', salt, iterations: 1000);
      final b = await VaultCrypto.pbkdf2('123456', salt, iterations: 1000);
      final c = await VaultCrypto.pbkdf2('123457', salt, iterations: 1000);
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('RecoveryKey', () {
    test('format is 8 groups of 4 and parses back', () {
      final raw = RecoveryKey.generate();
      final text = RecoveryKey.format(raw);
      expect(RegExp(r'^([0-9A-Z]{4}-){7}[0-9A-Z]{4}$').hasMatch(text), isTrue);
      expect(RecoveryKey.parse(text), raw);
    });

    test('parse tolerates case, spaces and look-alike letters', () {
      final raw = RecoveryKey.generate();
      final text = RecoveryKey.format(raw).toLowerCase().replaceAll('-', ' ');
      expect(RecoveryKey.parse(text), raw);
    });

    test('rejects wrong length and bad characters', () {
      expect(RecoveryKey.parse('ABCD-EFGH'), isNull);
      expect(RecoveryKey.parse('U' * 32), isNull);
    });
  });

  group('lockout schedule', () {
    test('free tries then escalating waits', () {
      expect(AppState.delayForFailures(4), Duration.zero);
      expect(AppState.delayForFailures(5), const Duration(seconds: 30));
      expect(AppState.delayForFailures(6), const Duration(minutes: 1));
      expect(AppState.delayForFailures(7), const Duration(minutes: 5));
      expect(AppState.delayForFailures(8), const Duration(minutes: 15));
      expect(AppState.delayForFailures(50), const Duration(minutes: 15));
    });
  });

  group('models', () {
    test('card network detection', () {
      expect(CardNetwork.detect('4111 1111 1111 1111'), CardNetwork.visa);
      expect(CardNetwork.detect('5241880012345678'), CardNetwork.mastercard);
      expect(CardNetwork.detect('2221000000000009'), CardNetwork.mastercard);
      expect(CardNetwork.detect('378282246310005'), CardNetwork.amex);
      expect(CardNetwork.detect('6521000000000000'), CardNetwork.rupay);
      expect(CardNetwork.detect(''), CardNetwork.other);
    });

    test('vault data JSON round trip keeps items and recovery key', () {
      final data = VaultData.empty()..recoveryKey = 'AAAA-BBBB';
      data.items.add(Item(
        id: 'x',
        kind: ItemKind.card,
        title: 'HDFC',
        categoryId: 'banking',
        fields: {'number': '5241880012344821', 'cvv': '317'},
        createdAt: DateTime(2026, 10, 30),
        updatedAt: DateTime(2026, 10, 30),
      ));
      final back = VaultData.fromJson(
          jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>);
      expect(back.recoveryKey, 'AAAA-BBBB');
      expect(back.items.single.field('cvv'), '317');
      expect(back.items.single.subtitle, 'Mastercard •••• 4821');
      expect(back.categories.length, data.categories.length);
    });

    test('empty fields are not part of the subtitle', () {
      final pass = Item(
        id: 'p',
        kind: ItemKind.passport,
        title: 'Passport',
        categoryId: 'ids',
        fields: {'number': 'Z123', 'expires': '14 Mar 2031'},
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(pass.subtitle, 'Expires 14 Mar 2031');
      expect(pass.field('place'), '');
    });
  });
}
