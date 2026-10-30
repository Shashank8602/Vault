import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';
import 'widgets.dart';

/// Six-digit PIN keypad. [onSubmit] gets the PIN once six digits are in and
/// returns an error message (shake + clear) or null on success.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onSubmit,
    this.onBiometric,
    this.disabled = false,
  });

  final Future<String?> Function(String pin) onSubmit;
  final VoidCallback? onBiometric;
  final bool disabled;

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _busy = false;
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void clear() => setState(() => _pin = '');

  Future<void> _press(String d) async {
    if (_busy || widget.disabled || _pin.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == 6) {
      setState(() => _busy = true);
      String? err;
      try {
        err = await widget.onSubmit(_pin);
      } catch (_) {
        err = 'error';
        if (mounted) {
          showToast(context, 'Something went wrong. Please try again.',
              icon: Icons.error_outline_rounded);
        }
      }
      _busy = false;
      if (!mounted) return;
      if (err != null) {
        HapticFeedback.heavyImpact();
        await _shake.forward(from: 0);
      }
      if (mounted) setState(() => _pin = '');
    }
  }

  void _back() {
    if (_busy || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: _shake,
        builder: (_, child) {
          final dx = _shake.isAnimating
              ? 10 * (1 - _shake.value) * (((_shake.value * 6).floor() % 2 == 0) ? 1 : -1)
              : 0.0;
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < 6; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _pin.length ? vc.accent : Colors.transparent,
                border: Border.all(
                    color: i < _pin.length ? vc.accent : vc.faint, width: 1.5),
              ),
            ),
        ]),
      ),
      SizedBox(
        height: 34,
        child: Center(
          child: _busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: vc.accent))
              : null,
        ),
      ),
      Opacity(
        opacity: widget.disabled ? 0.35 : 1,
        child: Column(children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final k in row) _Key(label: k, onTap: () => _press(k)),
              ]),
            ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            widget.onBiometric != null
                ? _Key(
                    icon: Icons.fingerprint_rounded,
                    ghost: true,
                    accent: true,
                    onTap: widget.onBiometric!)
                : const _Key(ghost: true),
            _Key(label: '0', onTap: () => _press('0')),
            _Key(icon: Icons.backspace_outlined, ghost: true, onTap: _back),
          ]),
        ]),
      ),
    ]);
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, this.onTap, this.ghost = false, this.accent = false});
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool ghost;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: SizedBox(
        width: 72,
        height: 72,
        child: onTap == null && label == null && icon == null
            ? null
            : Material(
                color: ghost ? Colors.transparent : vc.surface,
                shape: CircleBorder(side: BorderSide(color: ghost ? Colors.transparent : vc.line)),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: Center(
                    child: icon != null
                        ? Icon(icon, size: accent ? 30 : 24, color: accent ? vc.accent : vc.muted)
                        : Text(label!,
                            style: TextStyle(
                                fontFamily: kMono,
                                fontSize: 25,
                                fontWeight: FontWeight.w400,
                                color: vc.text)),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Two-step "enter new PIN" then "confirm PIN". Calls [onDone] with the PIN.
class PinSetup extends StatefulWidget {
  const PinSetup({super.key, required this.onDone, this.title = 'Create a PIN', this.showBack = true});
  final Future<void> Function(String pin) onDone;
  final String title;
  final bool showBack;

  @override
  State<PinSetup> createState() => _PinSetupState();
}

class _PinSetupState extends State<PinSetup> {
  String? _first;
  final _pad = GlobalKey<PinPadState>();
  String? _error;

  static bool _weak(String p) =>
      RegExp(r'^(\d)\1{5}$').hasMatch(p) || p == '123456' || p == '654321' || p == '012345';

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final confirming = _first != null;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          SizedBox(
            height: 56,
            child: Row(children: [
              if (widget.showBack || confirming)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: IconButton(
                    onPressed: () {
                      if (confirming) {
                        setState(() {
                          _first = null;
                          _error = null;
                        });
                      } else {
                        Navigator.maybePop(context);
                      }
                    },
                    icon: Icon(Icons.arrow_back_rounded, color: vc.text),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 18),
          Text(confirming ? 'Confirm your PIN' : widget.title, style: VT.title(context).copyWith(fontSize: 26)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _error ??
                  (confirming
                      ? 'Enter the same 6 digits again'
                      : 'Choose 6 digits you will remember'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 14,
                  color: _error != null ? vc.danger : vc.muted),
            ),
          ),
          const SizedBox(height: 40),
          PinPad(
            key: _pad,
            onSubmit: (pin) async {
              if (!confirming) {
                if (_weak(pin)) {
                  setState(() => _error = 'That PIN is too easy to guess. Try another.');
                  return 'weak';
                }
                setState(() {
                  _first = pin;
                  _error = null;
                });
                return null;
              }
              if (pin != _first) {
                setState(() {
                  _first = null;
                  _error = "PINs didn't match. Start again.";
                });
                return 'mismatch';
              }
              await widget.onDone(pin);
              return null;
            },
          ),
        ]),
      ),
    );
  }
}
