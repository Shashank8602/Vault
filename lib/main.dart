import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_state.dart';
import 'theme/theme.dart';
import 'ui/lock_screen.dart';
import 'ui/onboarding.dart';
import 'ui/shell.dart';
import 'ui/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  final app = AppState(prefs);
  runApp(ChangeNotifierProvider.value(value: app, child: const VaultApp()));
  await app.init();
}

class VaultApp extends StatelessWidget {
  const VaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<AppState, ThemeMode>((a) => a.themeMode);
    return MaterialApp(
      title: 'Vault',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: mode,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          ),
          child: child!,
        );
      },
      home: const RootGate(),
    );
  }
}

/// Splash for ~1 s on every cold start, then whichever screen the vault state needs.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _splashDone = false;
  late final AppState _app = context.read<AppState>();
  AppStatus _lastStatus = AppStatus.loading;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _splashDone = true);
    });
    _app.addListener(_onAppChange);
  }

  /// When the vault locks, close any open detail page, sheet or dialog so no
  /// decrypted content stays on screen behind the lock screen.
  void _onAppChange() {
    final s = _app.status;
    if (s == AppStatus.locked && _lastStatus == AppStatus.unlocked && mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
    _lastStatus = s;
  }

  @override
  void dispose() {
    _app.removeListener(_onAppChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.select<AppState, AppStatus>((a) => a.status);
    final Widget child;
    if (!_splashDone || status == AppStatus.loading) {
      child = const SplashScreen();
    } else {
      child = switch (status) {
        AppStatus.welcome => const WelcomeScreen(),
        AppStatus.locked => const LockScreen(),
        _ => const Shell(),
      };
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(key: ValueKey('${child.runtimeType}'), child: child),
    );
  }
}
