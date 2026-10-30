import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'crypto.dart';
import 'models.dart';

/// Result of [VaultStore.createNew].
class NewVault {
  NewVault(this.dek, this.recoveryKey);
  final Uint8List dek;
  final String recoveryKey;
}

/// A decrypted-but-not-yet-installed backup.
class OpenedBackup {
  OpenedBackup(this.dek, this.cipher, this.rec, this.pw);
  final Uint8List dek;
  final Uint8List cipher;
  final String rec;
  final Map<String, dynamic>? pw;
}

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Owns everything on disk.
///
/// * `vault.enc`  – the vault JSON sealed with a random 256-bit data key (DEK).
/// * `keys.json`  – the DEK wrapped separately by the PIN, the recovery key
///   and (optionally) the backup password. The DEK itself is never written
///   here.
/// * Android Keystore (via secure storage) – a copy of the DEK so fingerprint
///   can unlock without typing the PIN.
class VaultStore {
  VaultStore._();
  static final VaultStore instance = VaultStore._();

  static const _secure = FlutterSecureStorage();
  static const _dekKey = 'vault_dek_v1';

  Directory? _dir;
  Future<Directory> get _root async =>
      _dir ??= await getApplicationSupportDirectory();

  Future<File> get _vaultFile async => File('${(await _root).path}/vault.enc');
  Future<File> get _keysFile async => File('${(await _root).path}/keys.json');

  /// True once a vault is fully set up (including a PIN). A half-finished
  /// restore does not count, so the user is taken back to the welcome screen.
  Future<bool> exists() async {
    if (!(await _vaultFile).existsSync() || !(await _keysFile).existsSync()) {
      return false;
    }
    return (await _readKeys()).containsKey('pin');
  }

  // ---------- key file ----------

  Future<Map<String, dynamic>> _readKeys() async =>
      jsonDecode(await (await _keysFile).readAsString()) as Map<String, dynamic>;

  Future<void> _writeAtomic(File f, List<int> bytes) async {
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
  }

  Future<void> _writeKeys(Map<String, dynamic> k) async =>
      _writeAtomic(await _keysFile, utf8.encode(jsonEncode(k)));

  Future<Map<String, String>> _wrapWithSecret(String secret, Uint8List dek,
      {int? iterations}) async {
    final iter = iterations ?? VaultCrypto.pbkdf2Iterations;
    final salt = VaultCrypto.randomBytes(16);
    final key = await VaultCrypto.pbkdf2(secret, salt, iterations: iter);
    final wrap = await VaultCrypto.seal(key, dek);
    return {'salt': VaultCrypto.b64(salt), 'iter': '$iter', 'wrap': VaultCrypto.b64(wrap)};
  }

  Future<Uint8List> _unwrapWithSecret(
      Map<String, dynamic> block, String secret) async {
    final key = await VaultCrypto.pbkdf2(secret, VaultCrypto.unb64(block['salt'] as String),
        iterations: int.parse('${block['iter']}'));
    return VaultCrypto.open(key, VaultCrypto.unb64(block['wrap'] as String));
  }

  Future<String> _wrapWithRecovery(Uint8List recBytes, Uint8List dek) async {
    final key = await VaultCrypto.hkdf(recBytes, 'vault-recovery-v1');
    return VaultCrypto.b64(await VaultCrypto.seal(key, dek));
  }

  Future<Uint8List> _unwrapWithRecovery(String wrap, Uint8List recBytes) async {
    final key = await VaultCrypto.hkdf(recBytes, 'vault-recovery-v1');
    return VaultCrypto.open(key, VaultCrypto.unb64(wrap));
  }

  // ---------- lifecycle ----------

  /// Creates a brand-new vault protected by [pin]. The caller must show
  /// [NewVault.recoveryKey] to the user exactly once.
  Future<NewVault> createNew(String pin, VaultData data) async {
    final dek = VaultCrypto.randomBytes(32);
    final rec = RecoveryKey.generate();
    await _writeKeys({
      'v': 1,
      'pin': await _wrapWithSecret(pin, dek),
      'rec': await _wrapWithRecovery(rec, dek),
    });
    await saveData(dek, data);
    return NewVault(dek, RecoveryKey.format(rec));
  }

  Future<Uint8List> unlockWithPin(String pin) async {
    final keys = await _readKeys();
    return _unwrapWithSecret(keys['pin'] as Map<String, dynamic>, pin);
  }

  Future<Uint8List> unlockWithRecovery(String recoveryKeyText) async {
    final rec = RecoveryKey.parse(recoveryKeyText);
    if (rec == null) throw WrongKeyException();
    final keys = await _readKeys();
    return _unwrapWithRecovery(keys['rec'] as String, rec);
  }

  Future<VaultData> loadData(Uint8List dek) async {
    final bytes = await (await _vaultFile).readAsBytes();
    final plain = await VaultCrypto.open(dek, bytes);
    return VaultData.fromJson(jsonDecode(utf8.decode(plain)) as Map<String, dynamic>);
  }

  Future<VaultData> openData(Uint8List dek, Uint8List cipher) async {
    final plain = await VaultCrypto.open(dek, cipher);
    return VaultData.fromJson(jsonDecode(utf8.decode(plain)) as Map<String, dynamic>);
  }

  Future<void> saveData(Uint8List dek, VaultData data) async {
    final sealed = await VaultCrypto.seal(dek, utf8.encode(jsonEncode(data.toJson())));
    await _writeAtomic(await _vaultFile, sealed);
  }

  Future<void> changePin(Uint8List dek, String newPin) async {
    final keys = await _readKeys();
    keys['pin'] = await _wrapWithSecret(newPin, dek);
    await _writeKeys(keys);
  }

  Future<bool> hasBackupPassword() async =>
      (await _readKeys()).containsKey('pw');

  Future<void> setBackupPassword(Uint8List dek, String password) async {
    final keys = await _readKeys();
    keys['pw'] = await _wrapWithSecret(password, dek);
    await _writeKeys(keys);
  }

  // ---------- fingerprint copy of the key ----------

  Future<void> storeBiometricKey(Uint8List dek) =>
      _secure.write(key: _dekKey, value: VaultCrypto.b64(dek));

  Future<Uint8List?> readBiometricKey() async {
    final v = await _secure.read(key: _dekKey);
    return v == null ? null : VaultCrypto.unb64(v);
  }

  Future<void> clearBiometricKey() => _secure.delete(key: _dekKey);

  // ---------- backup / restore ----------

  /// Builds the `.vault` backup file. It holds the vault ciphertext plus the
  /// password and recovery wraps of the data key, but never the PIN wrap.
  Future<Uint8List> buildBackup() async {
    final keys = await _readKeys();
    final data = await (await _vaultFile).readAsBytes();
    final doc = {
      'format': 'vault-backup',
      'v': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'rec': keys['rec'],
      if (keys['pw'] != null) 'pw': keys['pw'],
      'data': VaultCrypto.b64(data),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(doc)));
  }

  /// Opens a backup with either the backup password or the recovery key.
  /// Nothing is written to disk until [installBackup] is called, so an
  /// abandoned restore never damages the current vault.
  Future<OpenedBackup> openBackup(Uint8List file,
      {String? password, String? recoveryKey}) async {
    Map<String, dynamic> doc;
    try {
      doc = jsonDecode(utf8.decode(file)) as Map<String, dynamic>;
      if (doc['format'] != 'vault-backup') throw const FormatException();
    } catch (_) {
      throw BackupException('This is not a Vault backup file.');
    }
    Uint8List dek;
    if (password != null) {
      if (doc['pw'] == null) {
        throw BackupException(
            'This backup has no backup password. Use your recovery key instead.');
      }
      dek = await _unwrapWithSecret(doc['pw'] as Map<String, dynamic>, password);
    } else {
      final rec = RecoveryKey.parse(recoveryKey ?? '');
      if (rec == null) throw WrongKeyException();
      dek = await _unwrapWithRecovery(doc['rec'] as String, rec);
    }
    final cipher = VaultCrypto.unb64(doc['data'] as String);
    await VaultCrypto.open(dek, cipher); // validates integrity
    return OpenedBackup(dek, cipher, doc['rec'] as String,
        doc['pw'] as Map<String, dynamic>?);
  }

  /// Replaces the vault on disk with an opened backup, protected by [pin].
  Future<void> installBackup(OpenedBackup b, String pin) async {
    await _writeAtomic(await _vaultFile, b.cipher);
    await _writeKeys({
      'v': 1,
      'pin': await _wrapWithSecret(pin, b.dek),
      'rec': b.rec,
      if (b.pw != null) 'pw': b.pw,
    });
  }

}
