import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../theme/theme.dart';
import 'pin_pad.dart';
import 'widgets.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  Timer? _tick;
  String? _message;
  bool? _bioAvailable; // null while still checking
  bool _showPin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final app = context.read<AppState>();
    _syncTimer(app);
    if (app.fingerprintEnabled) {
      final ok = await app.biometricsAvailable();
      if (!mounted) return;
      setState(() => _bioAvailable = ok);
      if (ok) await app.tryBiometricUnlock();
    }
  }

  void _syncTimer(AppState app) {
    _tick?.cancel();
    if (app.lockoutRemaining > Duration.zero) {
      _tick = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        if (app.lockoutRemaining <= Duration.zero) {
          t.cancel();
          setState(() => _message = null);
        } else {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _fmt(Duration d) {
    final s = d.inSeconds + 1;
    if (s >= 60) return '${s ~/ 60}m ${(s % 60).toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  Future<String?> _submit(String pin) async {
    final app = context.read<AppState>();
    final r = await app.unlockWithPin(pin);
    if (!mounted) return null;
    switch (r) {
      case PinResult.ok:
        return null;
      case PinResult.wrong:
        setState(() => _message = app.triesLeftBeforeDelay > 0
            ? 'Wrong PIN. ${app.triesLeftBeforeDelay} ${app.triesLeftBeforeDelay == 1 ? 'try' : 'tries'} left before a wait.'
            : 'Wrong PIN.');
        return 'wrong';
      case PinResult.lockedOut:
        _syncTimer(app);
        setState(() {});
        return 'locked';
    }
  }

  Future<void> _forgot() async {
    final app = context.read<AppState>();
    final key = await showVaultSheet<String>(
      context,
      scroll: true,
      builder: (ctx) => const _RecoverySheet(),
    );
    if (key == null || !mounted) return;
    final ok = await app.unlockWithRecovery(key);
    if (!mounted) return;
    if (!ok) {
      showToast(context, "That recovery key didn't work", icon: Icons.error_outline_rounded);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PinSetup(
        title: 'Set a new PIN',
        showBack: false,
        onDone: (pin) async {
          await app.finishRestore(pin);
          if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
        },
      ),
    ));
  }

  /// Default view: fingerprint first, with "Use PIN" as the fallback.
  Widget _fingerprintView(AppState app) {
    final vc = context.vc;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const Spacer(flex: 3),
          const VaultLogo(size: 64),
          const SizedBox(height: 18),
          Text('Vault is locked', style: VT.title(context).copyWith(fontSize: 26)),
          const SizedBox(height: 8),
          Text('Use your fingerprint to unlock',
              style: TextStyle(fontFamily: kSans, fontSize: 14, color: vc.muted)),
          const Spacer(flex: 2),
          Material(
            color: vc.accent.withValues(alpha: 0.13),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => app.tryBiometricUnlock(),
              child: SizedBox(
                  width: 92, height: 92, child: Icon(Icons.fingerprint_rounded, size: 52, color: vc.accent)),
            ),
          ),
          const SizedBox(height: 14),
          Text('Tap to scan', style: VT.sub(context)),
          const Spacer(flex: 3),
          VButton('Use PIN instead',
              kind: VButtonKind.ghost,
              onPressed: () => setState(() => _showPin = true)).withPadding(),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final vc = context.vc;
    final remaining = app.lockoutRemaining;
    final locked = remaining > Duration.zero;
    final bioMode = app.fingerprintEnabled && _bioAvailable != false && !_showPin;
    if (bioMode) return _fingerprintView(app);
    final canBio = app.fingerprintEnabled && _bioAvailable == true;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(height: 24),
                const VaultLogo(size: 56),
                const SizedBox(height: 18),
                Text('Enter PIN', style: VT.title(context).copyWith(fontSize: 26)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    locked
                        ? 'Too many wrong tries. Try again in ${_fmt(remaining)}.'
                        : (_message ?? 'Enter your 6-digit PIN'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 14,
                        color: (locked || _message != null) ? vc.danger : vc.muted),
                  ),
                ),
                const SizedBox(height: 34),
                PinPad(
                  disabled: locked,
                  onSubmit: _submit,
                  onBiometric: canBio
                      ? () {
                          setState(() => _showPin = false);
                          app.tryBiometricUnlock();
                        }
                      : null,
                ),
                const SizedBox(height: 18),
                TextAction('Forgot PIN?', onTap: _forgot),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecoverySheet extends StatefulWidget {
  const _RecoverySheet();

  @override
  State<_RecoverySheet> createState() => _RecoverySheetState();
}

class _RecoverySheetState extends State<_RecoverySheet> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Use recovery key', style: VT.h2(context)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
          child: Text(
              'Enter the 32-character key you saved when you created the vault. You will then set a new PIN.',
              style: VT.sub(context).copyWith(height: 1.5, fontSize: 13)),
        ),
        VField(
          label: 'Recovery key',
          controller: _c,
          mono: true,
          upper: true,
          hint: 'XXXX-XXXX-XXXX-XXXX-…',
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: VButton('Unlock', onPressed: _c.text.trim().length < 8 ? null : () => Navigator.pop(context, _c.text)),
        ),
      ]),
    );
  }
}

extension on Widget {
  Widget withPadding() =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: this);
}
