import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/crypto.dart';
import '../core/vault_store.dart';
import '../theme/theme.dart';
import 'pin_pad.dart';
import 'widgets.dart';

/// First launch: create a new vault or restore a backup.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(children: [
            const Spacer(flex: 3),
            const VaultLogo(size: 96),
            const SizedBox(height: 22),
            Text('Vault', style: VT.title(context).copyWith(fontSize: 38)),
            const SizedBox(height: 8),
            Text('Your credentials, encrypted\nand kept on this phone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: kSans, fontSize: 14.5, height: 1.5, color: vc.muted)),
            const Spacer(flex: 4),
            VButton('Create new vault', onPressed: () => _create(context)),
            const SizedBox(height: 12),
            VButton('Restore from backup',
                icon: Icons.file_download_outlined,
                kind: VButtonKind.ghost,
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const RestoreScreen()))),
            const SizedBox(height: 14),
            Text('Nothing leaves this phone unless you turn on backup.',
                style: VT.sub(context).copyWith(fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  void _create(BuildContext context) {
    final app = context.read<AppState>();
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PinSetup(
            onDone: (pin) async {
              final recovery = await app.createVault(pin);
              if (!ctx.mounted) return;
              Navigator.pushReplacement(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) => FingerprintOffer(
                          onDone: (c) => Navigator.pushReplacement(
                              c,
                              MaterialPageRoute(
                                  builder: (_) => RecoveryKeyScreen(
                                      recoveryKey: recovery,
                                      onDone: (cc) async {
                                        await app.finishOnboarding();
                                        if (cc.mounted) {
                                          Navigator.of(cc).popUntil((r) => r.isFirst);
                                        }
                                      }))))));
            },
          ),
        ));
  }
}

class FingerprintOffer extends StatefulWidget {
  const FingerprintOffer({super.key, required this.onDone});
  final void Function(BuildContext) onDone;

  @override
  State<FingerprintOffer> createState() => _FingerprintOfferState();
}

class _FingerprintOfferState extends State<FingerprintOffer> {
  bool _busy = false;
  bool? _available;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().biometricsAvailable().then((v) {
      if (!mounted) return;
      if (!v) {
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone(context));
      } else {
        setState(() => _available = v);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final app = context.read<AppState>();
    if (_available != true) return const Scaffold();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(children: [
            const Spacer(flex: 2),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: vc.accent.withValues(alpha: 0.13)),
              child: Icon(Icons.fingerprint_rounded, size: 56, color: vc.accent),
            ),
            const SizedBox(height: 26),
            Text('Unlock with fingerprint', style: VT.title(context).copyWith(fontSize: 26)),
            const SizedBox(height: 10),
            Text('Open Vault with a touch. Your PIN still works any time.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: kSans, fontSize: 14.5, height: 1.5, color: vc.muted)),
            const Spacer(flex: 3),
            VButton('Turn on fingerprint', busy: _busy, onPressed: () async {
              setState(() => _busy = true);
              await app.setFingerprintEnabled(true);
              if (context.mounted) widget.onDone(context);
            }),
            const SizedBox(height: 6),
            TextAction('Not now', onTap: () => widget.onDone(context)),
          ]),
        ),
      ),
    );
  }
}

/// Shows the recovery key once. The user must confirm they saved it.
class RecoveryKeyScreen extends StatefulWidget {
  const RecoveryKeyScreen(
      {super.key, required this.recoveryKey, required this.onDone, this.doneLabel = 'Continue'});
  final String recoveryKey;
  final Future<void> Function(BuildContext) onDone;
  final String doneLabel;

  @override
  State<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends State<RecoveryKeyScreen> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final groups = widget.recoveryKey.split('-');
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: vc.accent.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.shield_outlined, color: vc.accent),
            ),
            const SizedBox(height: 18),
            Text('Your recovery key', style: VT.title(context).copyWith(fontSize: 26)),
            const SizedBox(height: 10),
            Text(
                'If you forget your PIN, this key is the only way back in. It also opens your backups. Write it down and keep it somewhere safe. It is shown only once.',
                style: TextStyle(fontFamily: kSans, fontSize: 14, height: 1.5, color: vc.muted)),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                  color: vc.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: vc.line)),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 22,
                runSpacing: 12,
                children: [
                  for (final g in groups)
                    Text(g,
                        style: TextStyle(
                            fontFamily: kMono,
                            fontSize: 20,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w500,
                            color: vc.accent)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextAction('Copy to clipboard', gold: true, onTap: () async {
                await Clipboard.setData(ClipboardData(text: widget.recoveryKey));
                if (context.mounted) {
                  showToast(context, 'Recovery key copied. Paste it somewhere safe, then clear it.');
                }
              }),
            ),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _saved = !_saved),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                        color: _saved ? vc.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _saved ? vc.accent : vc.faint, width: 1.5)),
                    child: _saved ? Icon(Icons.check_rounded, size: 16, color: vc.onAccent) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text("I've saved my recovery key",
                          style: TextStyle(
                              fontFamily: kSans,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: vc.text))),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            VButton(widget.doneLabel,
                onPressed: _saved ? () => widget.onDone(context) : null),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ restore

class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key, this.inApp = false});

  /// True when opened from Settings on a phone that already has a PIN. The
  /// existing PIN, fingerprint and recovery key are kept; only the data is replaced.
  final bool inApp;

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  Uint8List? _file;
  String? _fileName;
  bool _useRecovery = false;
  final _secret = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _secret.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final app = context.read<AppState>();
    app.suspendLock();
    try {
      final res = await FilePicker.pickFiles(dialogTitle: 'Choose your Vault backup');
      if (res.isEmpty || res.first.path == null) return;
      final f = File(res.first.path!);
      final bytes = await f.readAsBytes();
      setState(() {
        _file = bytes;
        _fileName = res.first.name;
        _error = null;
      });
    } finally {
      app.resumeLock();
    }
  }

  Future<void> _restore() async {
    final app = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.inApp) {
        final n = await app.restoreIntoCurrent(_file!,
            password: _useRecovery ? null : _secret.text,
            recoveryKey: _useRecovery ? _secret.text : null);
        if (!mounted) return;
        showToast(context, 'Restored $n ${n == 1 ? 'item' : 'items'}');
        Navigator.pop(context);
        return;
      }
      await app.restoreFromBackup(_file!,
          password: _useRecovery ? null : _secret.text,
          recoveryKey: _useRecovery ? _secret.text : null);
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (ctx) => PinSetup(
                  title: 'Set a PIN for this phone',
                  showBack: false,
                  onDone: (pin) async {
                    await app.finishRestore(pin);
                    if (!ctx.mounted) return;
                    Navigator.pushReplacement(
                        ctx,
                        MaterialPageRoute(
                            builder: (_) => FingerprintOffer(onDone: (c) {
                                  Navigator.of(c).popUntil((r) => r.isFirst);
                                })));
                  })));
    } on WrongKeyException {
      setState(() => _error = _useRecovery
          ? "That recovery key doesn't match this backup."
          : "That password doesn't match this backup.");
    } on BackupException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not read the backup. Is the file complete?');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Scaffold(
      body: SafeArea(
        child: ListView(children: [
          PageBar(
              title: 'Restore',
              leading: RoundIconButton(Icons.arrow_back_rounded, onTap: () => Navigator.pop(context))),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Choose the encrypted .vault file you exported or backed up.',
                style: TextStyle(fontFamily: kSans, fontSize: 14, height: 1.5, color: vc.muted)),
          ),
          const SizedBox(height: 16),
          Group(children: [
            SettingsRow(
              icon: Icons.insert_drive_file_outlined,
              title: _fileName ?? 'Choose backup file',
              subtitle: _file == null ? 'From this phone, Drive or any app' : 'Tap to choose another',
              onTap: _pick,
            ),
          ]),
          if (_file != null) ...[
            const SizedBox(height: 22),
            Container(
              margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: vc.bg2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: vc.line)),
              child: Row(children: [
                for (final (label, rec) in [('Backup password', false), ('Recovery key', true)])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _useRecovery = rec;
                        _secret.clear();
                        _error = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: _useRecovery == rec ? vc.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(7)),
                        child: Text(label,
                            style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _useRecovery == rec ? vc.text : vc.muted)),
                      ),
                    ),
                  ),
              ]),
            ),
            VField(
              label: _useRecovery ? 'Recovery key' : 'Backup password',
              controller: _secret,
              secret: !_useRecovery,
              mono: _useRecovery,
              upper: _useRecovery,
              error: _error,
              onChanged: (_) => setState(() => _error = null),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
              child: VButton('Restore vault',
                  busy: _busy,
                  onPressed: _secret.text.isEmpty ? null : _restore),
            ),
          ],
        ]),
      ),
    );
  }
}
