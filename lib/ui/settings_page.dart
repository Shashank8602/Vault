import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_state.dart';
import '../theme/theme.dart';
import 'onboarding.dart';
import 'pin_pad.dart';
import 'shell.dart' show kNavClearance;
import 'widgets.dart';

/// Asks for the PIN (or fingerprint) before a sensitive action.
Future<bool> authorize(BuildContext context) async {
  final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _PinVerifyPage()));
  return ok ?? false;
}

class _PinVerifyPage extends StatefulWidget {
  const _PinVerifyPage();

  @override
  State<_PinVerifyPage> createState() => _PinVerifyPageState();
}

class _PinVerifyPageState extends State<_PinVerifyPage> {
  String? _error;

  Future<void> _bio() async {
    final app = context.read<AppState>();
    if (await app.promptBiometric('Confirm it is you') && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final vc = context.vc;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          PageBar(
              leading: RoundIconButton(Icons.close_rounded, onTap: () => Navigator.pop(context, false))),
          const SizedBox(height: 20),
          Text('Enter your PIN', style: VT.title(context).copyWith(fontSize: 26)),
          const SizedBox(height: 8),
          Text(_error ?? 'Enter your 6-digit PIN to continue',
              style: TextStyle(
                  fontFamily: kSans, fontSize: 14, color: _error != null ? vc.danger : vc.muted)),
          const SizedBox(height: 40),
          PinPad(
            onBiometric: app.fingerprintEnabled ? _bio : null,
            onSubmit: (pin) async {
              if (await app.verifyPin(pin)) {
                if (context.mounted) Navigator.pop(context, true);
                return null;
              }
              setState(() => _error = 'Wrong PIN');
              return 'wrong';
            },
          ),
        ]),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static String _secs(int s) => switch (s) {
        0 => 'Immediately',
        < 60 => '$s sec',
        < 3600 => '${s ~/ 60} min',
        _ => '${s ~/ 3600} hr',
      };

  Future<void> _toggleFingerprint(BuildContext context, AppState app, bool on) async {
    if (on && !await app.biometricsAvailable()) {
      if (context.mounted) {
        showToast(context, 'No fingerprint is set up on this phone', icon: Icons.error_outline_rounded);
      }
      return;
    }
    await app.setFingerprintEnabled(on);
  }

  Future<void> _changePin(BuildContext context, AppState app) async {
    if (!await authorize(context) || !context.mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (ctx) => PinSetup(
                  title: 'Choose a new PIN',
                  onDone: (pin) async {
                    await app.changePin(pin);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) showToast(context, 'PIN changed');
                  },
                )));
  }

  Future<void> _autoLock(BuildContext context, AppState app) async {
    final v = await pickOption<int>(context,
        title: 'Auto-lock',
        current: app.autoLockSeconds,
        options: [for (final s in const [0, 30, 60, 300]) (s, _secs(s))]);
    if (v != null) await app.setAutoLockSeconds(v);
  }

  Future<void> _clipboard(BuildContext context, AppState app) async {
    final v = await pickOption<int>(context,
        title: 'Clear clipboard after',
        current: app.clipboardSeconds,
        options: [for (final s in const [15, 30, 60, 120]) (s, _secs(s))]);
    if (v != null) await app.setClipboardSeconds(v);
  }

  Future<void> _theme(BuildContext context, AppState app) async {
    final v = await pickOption<ThemeMode>(context,
        title: 'Theme',
        current: app.themeMode,
        options: const [
          (ThemeMode.system, 'System'),
          (ThemeMode.dark, 'Dark'),
          (ThemeMode.light, 'Light'),
        ]);
    if (v != null) await app.setThemeMode(v);
  }

  Future<bool> _ensureBackupPassword(BuildContext context, AppState app) async {
    if (await app.hasBackupPassword()) return true;
    if (!context.mounted) return false;
    final pw = await showVaultSheet<String>(context,
        scroll: true, builder: (_) => const _BackupPasswordSheet(firstTime: true));
    if (pw == null) return false;
    await app.setBackupPassword(pw);
    return true;
  }

  Future<void> _backupPassword(BuildContext context, AppState app) async {
    if (!await authorize(context) || !context.mounted) return;
    final pw = await showVaultSheet<String>(context,
        scroll: true,
        builder: (_) => _BackupPasswordSheet(firstTime: false, hasExisting: true));
    if (pw == null) return;
    await app.setBackupPassword(pw);
    if (context.mounted) showToast(context, 'Backup password saved');
  }

  Future<void> _showRecovery(BuildContext context, AppState app) async {
    if (!await authorize(context) || !context.mounted) return;
    final key = app.data.recoveryKey;
    if (key == null) {
      showToast(context, 'No recovery key is stored for this vault', icon: Icons.error_outline_rounded);
      return;
    }
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => RecoveryKeyScreen(
                recoveryKey: key,
                doneLabel: 'Done',
                onDone: (c) async => Navigator.pop(c))));
  }

  Future<void> _export(BuildContext context, AppState app) async {
    if (!await _ensureBackupPassword(context, app) || !context.mounted) return;
    final bytes = await app.buildBackup();
    final dir = await getTemporaryDirectory();
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name = 'vault-backup-${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}.vault';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    app.suspendLock();
    try {
      final res = await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path, mimeType: 'application/octet-stream')], subject: name));
      if (res.status == ShareResultStatus.success) await app.recordBackup('Exported file');
    } finally {
      app.resumeLock();
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _restore(BuildContext context, AppState app) async {
    final ok = await confirmDialog(context,
        title: 'Replace this vault?',
        message: 'Restoring a backup replaces everything in this vault with the contents of the backup.',
        confirmLabel: 'Continue',
        icon: Icons.file_download_outlined,
        danger: false);
    if (!ok || !context.mounted) return;
    if (!await authorize(context) || !context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RestoreScreen(inApp: true)));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final vc = context.vc;
    final themeLabel = switch (app.themeMode) {
      ThemeMode.dark => 'Dark',
      ThemeMode.light => 'Light',
      _ => 'System',
    };
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.only(bottom: kNavClearance), children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: Text('Settings', style: VT.title(context))),
        const SectionLabel('Security'),
        Group(children: [
          SettingsRow(
            icon: Icons.fingerprint_rounded,
            title: 'Fingerprint unlock',
            trailing: VaultSwitch(
                value: app.fingerprintEnabled,
                onChanged: (v) => _toggleFingerprint(context, app, v)),
          ),
          SettingsRow(
              icon: Icons.lock_outline_rounded,
              title: 'Change PIN',
              onTap: () => _changePin(context, app)),
          SettingsRow(
              icon: Icons.timer_outlined,
              title: 'Auto-lock',
              value: _secs(app.autoLockSeconds),
              onTap: () => _autoLock(context, app)),
          SettingsRow(
              icon: Icons.content_paste_off_outlined,
              title: 'Clear clipboard',
              value: _secs(app.clipboardSeconds),
              onTap: () => _clipboard(context, app)),
          SettingsRow(
              icon: Icons.key_outlined,
              title: 'Backup password',
              onTap: () => _backupPassword(context, app)),
          SettingsRow(
              icon: Icons.shield_outlined,
              title: 'Recovery key',
              subtitle: 'Needs your PIN or fingerprint to view',
              onTap: () => _showRecovery(context, app)),
        ]),
        const SectionLabel('Backup & restore'),
        Group(children: [
          SettingsRow(
              icon: Icons.ios_share_rounded,
              title: 'Export backup file',
              subtitle: 'Encrypted .vault file you can keep anywhere',
              onTap: () => _export(context, app)),
          SettingsRow(
              icon: Icons.file_download_outlined,
              title: 'Restore from backup',
              onTap: () => _restore(context, app)),
        ]),
        const SectionLabel('Appearance'),
        Group(children: [
          SettingsRow(
              icon: Icons.dark_mode_outlined,
              title: 'Theme',
              value: themeLabel,
              onTap: () => _theme(context, app)),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Center(child: Text('Vault 1.0.0', style: VT.sub(context).copyWith(color: vc.faint))),
        ),
      ]),
    );
  }
}

class _BackupPasswordSheet extends StatefulWidget {
  const _BackupPasswordSheet({required this.firstTime, this.hasExisting = false});
  final bool firstTime;
  final bool hasExisting;

  @override
  State<_BackupPasswordSheet> createState() => _BackupPasswordSheetState();
}

class _BackupPasswordSheetState extends State<_BackupPasswordSheet> {
  final _a = TextEditingController();
  final _b = TextEditingController();

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  String? get _error {
    if (_a.text.isNotEmpty && _a.text.length < 8) return 'Use at least 8 characters';
    if (_b.text.isNotEmpty && _a.text != _b.text) return "Passwords don't match";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ready = _a.text.length >= 8 && _a.text == _b.text;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(widget.firstTime ? 'Set a backup password' : 'Backup password',
                style: VT.h2(context))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
          child: Text(
              widget.firstTime
                  ? 'This password locks your backup files. You will type it when restoring on a new phone. Use at least 8 characters; letters, numbers and symbols are all fine. If you forget it, your recovery key opens any backup.'
                  : 'Backups you make from now on use this new password. Backup files you made earlier keep the password they had, but your recovery key opens every backup, old or new. Make a fresh backup after changing it.',
              style: VT.sub(context).copyWith(height: 1.5, fontSize: 13)),
        ),
        VField(
            label: 'Backup password (8+ characters)',
            controller: _a,
            secret: true,
            autofocus: true,
            onChanged: (_) => setState(() {})),
        VField(
            label: 'Confirm password',
            controller: _b,
            secret: true,
            error: _error,
            onChanged: (_) => setState(() {})),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: VButton('Save password',
              onPressed: ready ? () => Navigator.pop(context, _a.text) : null),
        ),
      ]),
    );
  }
}
