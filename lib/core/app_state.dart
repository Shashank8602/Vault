import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crypto.dart';
import 'models.dart';
import 'vault_store.dart';

enum AppStatus { loading, welcome, locked, unlocked }

enum PinResult { ok, wrong, lockedOut }

/// Single source of truth for lock state, vault contents and preferences.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState(this._prefs);

  final SharedPreferences _prefs;
  final VaultStore _store = VaultStore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  AppStatus status = AppStatus.loading;
  VaultData? _data;
  Uint8List? _dek;

  VaultData get data => _data!;
  Uint8List get dek => _dek!;

  // ---------- preferences ----------

  ThemeMode get themeMode => switch (_prefs.getString('theme')) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
  Future<void> setThemeMode(ThemeMode m) async {
    await _prefs.setString('theme', m.name);
    notifyListeners();
  }

  /// Seconds the app may stay in the background before locking. 0 = at once.
  int get autoLockSeconds => _prefs.getInt('autoLock') ?? 30;
  Future<void> setAutoLockSeconds(int v) async {
    await _prefs.setInt('autoLock', v);
    notifyListeners();
  }

  int get clipboardSeconds => _prefs.getInt('clipboard') ?? 30;
  Future<void> setClipboardSeconds(int v) async {
    await _prefs.setInt('clipboard', v);
    notifyListeners();
  }

  bool get fingerprintEnabled => _prefs.getBool('fingerprint') ?? false;

  DateTime? get lastBackup {
    final s = _prefs.getString('lastBackup');
    return s == null ? null : DateTime.tryParse(s)?.toLocal();
  }

  String? get lastBackupWhere => _prefs.getString('lastBackupWhere');

  Future<void> recordBackup(String where) async {
    await _prefs.setString('lastBackup', DateTime.now().toIso8601String());
    await _prefs.setString('lastBackupWhere', where);
    notifyListeners();
  }

  /// Test hook: opens the app on in-memory data without touching disk.
  @visibleForTesting
  void debugOpen(VaultData d) {
    _data = d;
    _dek = Uint8List(32);
    status = AppStatus.unlocked;
    notifyListeners();
  }

  // ---------- start-up ----------

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    status = await _store.exists() ? AppStatus.locked : AppStatus.welcome;
    notifyListeners();
  }

  // ---------- biometrics ----------

  Future<bool> biometricsAvailable() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return false;
      final types = await _localAuth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Shows the system fingerprint prompt. True when the user passed it.
  Future<bool> promptBiometric(String reason) async {
    suspendLock();
    try {
      return await _localAuth.authenticate(
          localizedReason: reason, biometricOnly: true);
    } catch (_) {
      return false;
    } finally {
      resumeLock();
    }
  }

  Future<bool> tryBiometricUnlock() async {
    if (!fingerprintEnabled || status != AppStatus.locked) return false;
    if (!await promptBiometric('Unlock Vault')) return false;
    final key = await _store.readBiometricKey();
    if (key == null) return false;
    try {
      _data = await _store.loadData(key);
      _dek = key;
    } catch (_) {
      return false;
    }
    await _resetAttempts();
    status = AppStatus.unlocked;
    notifyListeners();
    return true;
  }

  Future<void> setFingerprintEnabled(bool on) async {
    if (on) {
      if (!await promptBiometric('Turn on fingerprint unlock')) return;
      await _store.storeBiometricKey(dek);
    } else {
      await _store.clearBiometricKey();
    }
    await _prefs.setBool('fingerprint', on);
    notifyListeners();
  }

  // ---------- PIN and lockout ----------

  int get _failed => _prefs.getInt('failed') ?? 0;
  int get _lockUntilMs => _prefs.getInt('lockUntil') ?? 0;

  Duration get lockoutRemaining {
    final left = _lockUntilMs - DateTime.now().millisecondsSinceEpoch;
    return left > 0 ? Duration(milliseconds: left) : Duration.zero;
  }

  Future<void> _resetAttempts() async {
    await _prefs.setInt('failed', 0);
    await _prefs.setInt('lockUntil', 0);
  }

  /// 5th wrong try waits 30 s, then 1 min, 5 min, and 15 min from there on.
  static Duration delayForFailures(int failures) {
    if (failures < 5) return Duration.zero;
    return switch (failures) {
      5 => const Duration(seconds: 30),
      6 => const Duration(minutes: 1),
      7 => const Duration(minutes: 5),
      _ => const Duration(minutes: 15),
    };
  }

  Future<PinResult> unlockWithPin(String pin) async {
    if (lockoutRemaining > Duration.zero) return PinResult.lockedOut;
    try {
      final key = await _store.unlockWithPin(pin);
      _data = await _store.loadData(key);
      _dek = key;
      await _resetAttempts();
      status = AppStatus.unlocked;
      notifyListeners();
      return PinResult.ok;
    } on WrongKeyException {
      final n = _failed + 1;
      await _prefs.setInt('failed', n);
      final wait = delayForFailures(n);
      if (wait > Duration.zero) {
        await _prefs.setInt('lockUntil',
            DateTime.now().add(wait).millisecondsSinceEpoch);
      }
      notifyListeners();
      return wait > Duration.zero ? PinResult.lockedOut : PinResult.wrong;
    }
  }

  int get triesLeftBeforeDelay => (5 - _failed).clamp(0, 5);

  /// Verifies the PIN without changing lock state (used before sensitive actions).
  Future<bool> verifyPin(String pin) async {
    try {
      await _store.unlockWithPin(pin);
      return true;
    } on WrongKeyException {
      return false;
    }
  }

  Future<void> changePin(String newPin) => _store.changePin(dek, newPin);

  /// Forgot-PIN path. Stays on the lock screen until the caller sets a new PIN
  /// with [finishRestore].
  Future<bool> unlockWithRecovery(String recoveryKey) async {
    try {
      final key = await _store.unlockWithRecovery(recoveryKey);
      _data = await _store.loadData(key);
      _dek = key;
      await _resetAttempts();
      return true;
    } on WrongKeyException {
      return false;
    }
  }

  // ---------- onboarding ----------

  /// Creates the vault and returns the recovery key to display. The app stays
  /// on the welcome flow until [finishOnboarding] is called.
  Future<String> createVault(String pin) async {
    final fresh = VaultData.empty();
    final created = await _store.createNew(pin, fresh);
    // Kept inside the encrypted vault so Settings can show it again later.
    fresh.recoveryKey = created.recoveryKey;
    await _store.saveData(created.dek, fresh);
    _dek = created.dek;
    _data = fresh;
    return created.recoveryKey;
  }

  Future<void> finishOnboarding() async {
    status = AppStatus.unlocked;
    notifyListeners();
  }

  OpenedBackup? _pendingRestore;

  /// Decrypts a backup and keeps it in memory. Nothing is installed until
  /// [finishRestore] is called with the new PIN.
  Future<void> restoreFromBackup(Uint8List file,
      {String? password, String? recoveryKey}) async {
    final opened = await _store.openBackup(file,
        password: password, recoveryKey: recoveryKey);
    final restored = await _store.openData(opened.dek, opened.cipher);
    _pendingRestore = opened;
    _dek = opened.dek;
    _data = restored;
  }

  /// Restore from Settings: swaps the vault contents for the backup's but keeps
  /// this phone's PIN, fingerprint and recovery key. Returns the item count.
  Future<int> restoreIntoCurrent(Uint8List file,
      {String? password, String? recoveryKey}) async {
    final opened = await _store.openBackup(file,
        password: password, recoveryKey: recoveryKey);
    final restored = await _store.openData(opened.dek, opened.cipher);
    restored.recoveryKey = _data!.recoveryKey;
    _data = restored;
    notifyListeners();
    await _persist();
    return restored.items.length;
  }

  /// Completes a restore or a forgot-PIN reset by setting the PIN, then opens
  /// the vault.
  Future<void> finishRestore(String pin) async {
    final pending = _pendingRestore;
    if (pending != null) {
      await _store.installBackup(pending, pin);
      _pendingRestore = null;
    } else {
      await _store.changePin(dek, pin);
    }
    if (fingerprintEnabled) await _store.storeBiometricKey(dek);
    status = AppStatus.unlocked;
    notifyListeners();
  }

  // ---------- locking ----------

  int _suspend = 0;
  DateTime? _pausedAt;

  /// Wrap any flow that leaves the app (file picker, share sheet, system
  /// prompts) so it doesn't trigger auto-lock when the user returns.
  void suspendLock() => _suspend++;
  void resumeLock() {
    if (_suspend > 0) _suspend--;
  }

  void lock() {
    if (status != AppStatus.unlocked) return;
    _dek = null;
    _data = null;
    status = AppStatus.locked;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final s = state;
    if (status != AppStatus.unlocked || _suspend > 0) return;
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
      if (autoLockSeconds == 0) lock();
    } else if (s == AppLifecycleState.resumed) {
      final at = _pausedAt;
      _pausedAt = null;
      if (at != null &&
          DateTime.now().difference(at).inSeconds >= autoLockSeconds) {
        lock();
      }
    }
  }

  // ---------- vault mutations ----------

  Future<void> _chain = Future.value();

  Future<void> _persist() {
    final d = _data!;
    final k = _dek!;
    _chain = _chain.then((_) => _store.saveData(k, d));
    return _chain;
  }

  Category categoryOf(String id) => data.categories.firstWhere(
      (c) => c.id == id,
      orElse: () => kUncategorised);

  Future<void> saveItem(Item item) async {
    final i = data.items.indexWhere((e) => e.id == item.id);
    item.updatedAt = DateTime.now();
    if (i >= 0) {
      data.items[i] = item;
    } else {
      data.items.add(item);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> deleteItem(String id) async {
    data.items.removeWhere((e) => e.id == id);
    notifyListeners();
    await _persist();
  }

  Future<Category> addCategory(String name, int color) async {
    final c = Category(id: newId(), name: name.trim(), color: color);
    data.categories.add(c);
    notifyListeners();
    await _persist();
    return c;
  }

  Future<void> updateCategory(Category c, {String? name, int? color}) async {
    if (name != null) c.name = name.trim();
    if (color != null) c.color = color;
    notifyListeners();
    await _persist();
  }

  /// Items in a deleted category move to "Uncategorised".
  Future<void> deleteCategory(String id) async {
    for (final it in data.items) {
      if (it.categoryId == id) it.categoryId = kUncategorisedId;
    }
    data.categories.removeWhere((c) => c.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> updateProfile({String? name, String? avatarB64, bool clearAvatar = false}) async {
    if (name != null) data.profile.name = name.trim();
    if (avatarB64 != null) data.profile.avatarB64 = avatarB64;
    if (clearAvatar) data.profile.avatarB64 = null;
    notifyListeners();
    await _persist();
  }

  // ---------- backup plumbing ----------

  Future<bool> hasBackupPassword() => _store.hasBackupPassword();
  Future<void> setBackupPassword(String pw) => _store.setBackupPassword(dek, pw);
  Future<Uint8List> buildBackup() async {
    await _chain;
    return _store.buildBackup();
  }
}
