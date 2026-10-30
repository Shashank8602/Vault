import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

// ---------------------------------------------------------------- logo

class VaultLogo extends StatelessWidget {
  const VaultLogo({super.key, this.size = 96, this.dialTurns = 0});
  final double size;

  /// Turns applied to the dotted dial (used by the splash animation).
  final double dialTurns;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(dialTurns)));
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.turns);
  final double turns;
  static const gold = Color(0xFFD4B47A);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;
    canvas.save();
    canvas.scale(s);
    final bg = RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 5, 110, 110), const Radius.circular(26));
    canvas.drawRRect(bg, Paint()..color = const Color(0xFF141417));
    canvas.drawRRect(
        bg.deflate(0.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF2E2D33));

    // dial ticks
    canvas.save();
    canvas.translate(60, 60);
    canvas.rotate(turns * 2 * math.pi);
    final tick = Paint()
      ..color = gold.withValues(alpha: 0.6)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.drawLine(Offset(math.cos(a) * 37, math.sin(a) * 37),
          Offset(math.cos(a) * 41, math.sin(a) * 41), tick);
    }
    canvas.restore();

    canvas.drawCircle(
        const Offset(60, 60),
        30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = gold);
    final fill = Paint()..color = gold;
    canvas.drawCircle(const Offset(60, 55), 6.5, fill);
    canvas.drawPath(
        Path()
          ..moveTo(56.8, 58)
          ..lineTo(54.6, 71)
          ..lineTo(65.4, 71)
          ..lineTo(63.2, 58)
          ..close(),
        fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.turns != turns;
}

// ---------------------------------------------------------------- tiles

class LetterTile extends StatelessWidget {
  const LetterTile(
      {super.key, required this.letter, required this.color, this.size = 40, this.icon});
  final String letter;
  final Color color;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? color : Color.lerp(color, Colors.black, 0.3)!;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(size * 0.25)),
      child: icon != null
          ? Icon(icon, color: fg, size: size * 0.46)
          : Text(letter.isEmpty ? '?' : letter.characters.first.toUpperCase(),
              style: TextStyle(
                  fontFamily: kSans,
                  fontWeight: FontWeight.w600,
                  fontSize: size * 0.42,
                  color: fg)),
    );
  }
}

// ---------------------------------------------------------------- groups & rows

class Group extends StatelessWidget {
  const Group({super.key, required this.children, this.margin = const EdgeInsets.symmetric(horizontal: 14)});
  final List<Widget> children;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
          color: vc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: vc.line)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: vc.line, indent: 58),
            children[i],
          ]
        ]),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(30, 20, 30, 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(text.toUpperCase(), style: VT.label(context)),
          if (trailing != null) Text(trailing!.toUpperCase(), style: VT.label(context)),
        ]),
      );
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.accent = false,
    this.danger = false,
    this.chevron = true,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool accent;
  final bool danger;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final col = danger ? vc.danger : (accent ? vc.accent : vc.text);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: (danger ? vc.danger : vc.accent).withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 17, color: danger ? vc.danger : vc.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontFamily: kSans, fontSize: 14, fontWeight: FontWeight.w500, color: col)),
              if (subtitle != null) Text(subtitle!, style: VT.sub(context)),
            ]),
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(value!,
                  style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: vc.muted)),
            ),
          ?trailing,
          if (trailing == null && chevron && onTap != null)
            Icon(Icons.chevron_right_rounded, size: 20, color: vc.faint),
        ]),
      ),
    );
  }
}

class VaultSwitch extends StatelessWidget {
  const VaultSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: value ? vc.accent : vc.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: value ? Colors.transparent : vc.line)),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
                color: value ? Colors.white : vc.faint, shape: BoxShape.circle)),
      ),
    );
  }
}

// ---------------------------------------------------------------- buttons

class VButton extends StatelessWidget {
  const VButton(this.label,
      {super.key, this.onPressed, this.icon, this.kind = VButtonKind.primary, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final VButtonKind kind;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final (bg, fg, border) = switch (kind) {
      VButtonKind.primary => (vc.accent, vc.onAccent, Colors.transparent),
      VButtonKind.ghost => (vc.surface, vc.text, vc.line),
      VButtonKind.danger => (vc.danger, Colors.white, Colors.transparent),
      VButtonKind.dangerGhost => (vc.surface, vc.danger, vc.line),
    };
    final disabled = onPressed == null || busy;
    return Opacity(
      opacity: onPressed == null && !busy ? 0.45 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: disabled ? null : onPressed,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
            child: busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
                    Text(label,
                        style: TextStyle(
                            fontFamily: kSans,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: fg)),
                  ]),
          ),
        ),
      ),
    );
  }
}

enum VButtonKind { primary, ghost, danger, dangerGhost }

// ---------------------------------------------------------------- inputs

class VField extends StatefulWidget {
  const VField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.mono = false,
    this.secret = false,
    this.keyboard,
    this.upper = false,
    this.autofocus = false,
    this.onChanged,
    this.formatters,
    this.error,
    this.textInputAction,
    this.onSubmitted,
    this.maxLength,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool mono;
  final bool secret;
  final TextInputType? keyboard;
  final bool upper;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? formatters;
  final String? error;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;

  @override
  State<VField> createState() => _VFieldState();
}

class _VFieldState extends State<VField> {
  bool _hidden = true;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final focused = _focus.hasFocus;
    final style = TextStyle(
        fontFamily: widget.mono ? kMono : kSans,
        fontSize: widget.mono ? 15 : 14.5,
        fontWeight: FontWeight.w500,
        color: vc.text);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(widget.label,
              style: TextStyle(
                  fontFamily: kSans, fontSize: 12, fontWeight: FontWeight.w600, color: vc.muted)),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 48,
          padding: const EdgeInsets.only(left: 14, right: 6),
          decoration: BoxDecoration(
            color: vc.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: widget.error != null
                    ? vc.danger
                    : (focused ? vc.accent : vc.line),
                width: focused || widget.error != null ? 1.4 : 1),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                obscureText: widget.secret && _hidden,
                obscuringCharacter: '•',
                keyboardType: widget.keyboard,
                textCapitalization:
                    widget.upper ? TextCapitalization.characters : TextCapitalization.none,
                textInputAction: widget.textInputAction,
                onSubmitted: widget.onSubmitted,
                onChanged: widget.onChanged,
                inputFormatters: widget.formatters,
                maxLength: widget.maxLength,
                autocorrect: false,
                enableSuggestions: !widget.secret,
                style: style,
                cursorColor: vc.accent,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  counterText: '',
                  hintText: widget.hint,
                  hintStyle: style.copyWith(color: vc.faint),
                ),
              ),
            ),
            if (widget.secret)
              IconButton(
                splashRadius: 20,
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(
                    _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                    color: vc.muted),
              ),
          ]),
        ),
        if (widget.error != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(widget.error!,
                style: TextStyle(fontFamily: kSans, fontSize: 12, color: vc.danger)),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- page chrome

/// Top bar used on pushed pages: [leading] [title] [trailing].
class PageBar extends StatelessWidget {
  const PageBar({super.key, this.title, this.leading, this.trailing});
  final String? title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            SizedBox(width: 90, child: Align(alignment: Alignment.centerLeft, child: leading)),
            Expanded(
                child: Center(
                    child: Text(title ?? '',
                        style: TextStyle(
                            fontFamily: kSans,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: context.vc.text)))),
            SizedBox(width: 90, child: Align(alignment: Alignment.centerRight, child: trailing)),
          ]),
        ),
      );
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton(this.icon, {super.key, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: vc.surface,
        shape: CircleBorder(side: BorderSide(color: vc.line)),
        child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: vc.text))),
      ),
    );
  }
}

class TextAction extends StatelessWidget {
  const TextAction(this.label, {super.key, this.onTap, this.gold = false});
  final String label;
  final VoidCallback? onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Text(label,
            style: TextStyle(
                fontFamily: kSans,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: onTap == null ? vc.faint : (gold ? vc.accent : vc.muted))),
      ),
    );
  }
}

// ---------------------------------------------------------------- feedback

void showToast(BuildContext context, String message, {IconData icon = Icons.check_rounded}) {
  final vc = context.vc;
  final m = ScaffoldMessenger.of(context);
  m.clearSnackBars();
  m.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: vc.text,
    elevation: 0,
    margin: const EdgeInsets.fromLTRB(24, 0, 24, 110),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    duration: const Duration(seconds: 3),
    content: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: vc.accent),
      const SizedBox(width: 8),
      Flexible(
          child: Text(message,
              style: TextStyle(
                  fontFamily: kSans, fontSize: 13, fontWeight: FontWeight.w600, color: vc.bg))),
    ]),
  ));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  IconData icon = Icons.delete_outline_rounded,
  bool danger = true,
}) async {
  final vc = context.vc;
  final res = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => Dialog(
      backgroundColor: vc.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18), side: BorderSide(color: vc.line)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (danger ? vc.danger : vc.accent).withValues(alpha: 0.14)),
            child: Icon(icon, color: danger ? vc.danger : vc.accent),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: VT.h2(ctx).copyWith(fontSize: 20)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: VT.sub(ctx).copyWith(height: 1.5, fontSize: 13)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
                child: SizedBox(
                    height: 46,
                    child: _DialogBtn('Cancel', false, () => Navigator.pop(ctx, false)))),
            const SizedBox(width: 10),
            Expanded(
                child: SizedBox(
                    height: 46,
                    child: _DialogBtn(confirmLabel, true, () => Navigator.pop(ctx, true),
                        danger: danger))),
          ]),
        ]),
      ),
    ),
  );
  return res ?? false;
}

class _DialogBtn extends StatelessWidget {
  const _DialogBtn(this.label, this.primary, this.onTap, {this.danger = false});
  final String label;
  final bool primary;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final bg = primary ? (danger ? vc.danger : vc.accent) : vc.surface;
    final fg = primary ? (danger ? Colors.white : vc.onAccent) : vc.text;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary ? Colors.transparent : vc.line)),
          child: Text(label,
              style: TextStyle(
                  fontFamily: kSans, fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
        ),
      ),
    );
  }
}

/// Bottom sheet scaffold with the grab handle from the mockups.
Future<T?> showVaultSheet<T>(BuildContext context,
    {required Widget Function(BuildContext) builder, bool scroll = false}) {
  final vc = context.vc;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scroll,
    backgroundColor: vc.surface,
    barrierColor: Colors.black.withValues(alpha: 0.58),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: vc.faint.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        builder(ctx),
      ]),
    ),
  );
}

/// Radio-style picker sheet. Returns the chosen value.
Future<T?> pickOption<T>(BuildContext context,
    {required String title, required List<(T, String)> options, required T current}) {
  return showVaultSheet<T>(
    context,
    builder: (ctx) {
      final vc = ctx.vc;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Align(
            alignment: Alignment.centerLeft,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(title, style: VT.h2(ctx)))),
        for (final o in options)
          InkWell(
            onTap: () => Navigator.pop(ctx, o.$1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Expanded(child: Text(o.$2, style: VT.body(ctx))),
                if (o.$1 == current) Icon(Icons.check_rounded, color: vc.accent, size: 20),
              ]),
            ),
          ),
        const SizedBox(height: 8),
      ]);
    },
  );
}
