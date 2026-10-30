import 'package:flutter/material.dart';

/// Design tokens from the approved mockups (flat colours, IBM Plex).
@immutable
class VaultColors extends ThemeExtension<VaultColors> {
  const VaultColors({
    required this.bg,
    required this.bg2,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.success,
    required this.nav,
  });

  final Color bg, bg2, surface, surface2, line;
  final Color text, muted, faint;
  final Color accent, onAccent, danger, success, nav;

  static const dark = VaultColors(
    bg: Color(0xFF0A0A0C),
    bg2: Color(0xFF101013),
    surface: Color(0xFF16161A),
    surface2: Color(0xFF1E1E23),
    line: Color(0x12FFFFFF),
    text: Color(0xFFF3EFE7),
    muted: Color(0xFF8E897F),
    faint: Color(0xFF5C5951),
    accent: Color(0xFFD4B47A),
    onAccent: Color(0xFF1A140A),
    danger: Color(0xFFE5786E),
    success: Color(0xFF7FBF8E),
    nav: Color(0xF01A1A1E),
  );

  static const light = VaultColors(
    bg: Color(0xFFF6F3ED),
    bg2: Color(0xFFECE7DE),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1ECE3),
    line: Color(0x17281E0F),
    text: Color(0xFF1B1915),
    muted: Color(0xFF756F64),
    faint: Color(0xFFA69F92),
    accent: Color(0xFF9C7A43),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFC2463C),
    success: Color(0xFF2F7A45),
    nav: Color(0xF2FFFFFF),
  );

  @override
  VaultColors copyWith() => this;

  @override
  VaultColors lerp(ThemeExtension<VaultColors>? other, double t) {
    if (other is! VaultColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return VaultColors(
      bg: l(bg, other.bg),
      bg2: l(bg2, other.bg2),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      line: l(line, other.line),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      faint: l(faint, other.faint),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      danger: l(danger, other.danger),
      success: l(success, other.success),
      nav: l(nav, other.nav),
    );
  }
}

extension VaultTheme on BuildContext {
  VaultColors get vc => Theme.of(this).extension<VaultColors>()!;
}

const String kSans = 'IBMPlexSans';
const String kMono = 'IBMPlexMono';

class VT {
  static TextStyle title(BuildContext c) => TextStyle(
      fontFamily: kSans,
      fontSize: 30,
      height: 1.1,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.8,
      color: c.vc.text);
  static TextStyle h2(BuildContext c) => TextStyle(
      fontFamily: kSans,
      fontSize: 22,
      height: 1.15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      color: c.vc.text);
  static TextStyle body(BuildContext c) => TextStyle(
      fontFamily: kSans, fontSize: 14.5, fontWeight: FontWeight.w500, color: c.vc.text);
  static TextStyle sub(BuildContext c) => TextStyle(
      fontFamily: kSans, fontSize: 12.5, fontWeight: FontWeight.w400, color: c.vc.muted);
  static TextStyle label(BuildContext c) => TextStyle(
      fontFamily: kMono,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.1,
      color: c.vc.faint);
  static TextStyle mono(BuildContext c, {double size = 15.5, Color? color}) => TextStyle(
      fontFamily: kMono,
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color ?? c.vc.text);
}

ThemeData buildTheme(Brightness b) {
  final vc = b == Brightness.dark ? VaultColors.dark : VaultColors.light;
  final scheme = ColorScheme(
    brightness: b,
    primary: vc.accent,
    onPrimary: vc.onAccent,
    secondary: vc.accent,
    onSecondary: vc.onAccent,
    error: vc.danger,
    onError: Colors.white,
    surface: vc.surface,
    onSurface: vc.text,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: vc.bg,
    canvasColor: vc.bg,
    fontFamily: kSans,
    extensions: [vc],
    splashFactory: InkRipple.splashFactory,
    splashColor: vc.accent.withValues(alpha: 0.10),
    highlightColor: Colors.transparent,
    dividerColor: vc.line,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: vc.accent,
      selectionColor: vc.accent.withValues(alpha: 0.30),
      selectionHandleColor: vc.accent,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}
