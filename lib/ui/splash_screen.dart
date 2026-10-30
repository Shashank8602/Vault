import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'widgets.dart';

/// About one second: logo fades in while the dial turns a quarter turn.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = VaultColors.dark;
    return Scaffold(
      backgroundColor: dark.bg,
      body: Stack(children: [
        Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) {
              final t = Curves.easeOutCubic.transform(_c.value);
              return Opacity(
                opacity: Curves.easeOut.transform((_c.value * 1.6).clamp(0.0, 1.0)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  VaultLogo(size: 104, dialTurns: t * 0.25),
                  const SizedBox(height: 24),
                  Text('VAULT',
                      style: TextStyle(
                          fontFamily: kMono,
                          fontSize: 20,
                          letterSpacing: 9,
                          fontWeight: FontWeight.w500,
                          color: dark.text)),
                ]),
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: Text('AES-256 · OFFLINE',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: kMono, fontSize: 10, letterSpacing: 2, color: dark.faint)),
        ),
      ]),
    );
  }
}
