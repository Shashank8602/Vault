import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../theme/theme.dart';
import 'home_page.dart';
import 'item_form.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'widgets.dart';

/// Height reserved at the bottom of scroll views so content clears the nav.
const double kNavClearance = 118;

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  Future<void> _add() async {
    HapticFeedback.lightImpact();
    final kind = await showVaultSheet<ItemKind>(context, builder: (_) => const _TypeSheet());
    if (kind == null || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ItemFormPage(kind: kind)));
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final pill = ClipRRect(
      borderRadius: BorderRadius.circular(31),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 62,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: vc.nav.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(31),
            border: Border.all(color: vc.line),
          ),
          child: Row(children: [
            Expanded(child: _Tab(Icons.shield_outlined, Icons.shield, 'Vault', _tab == 0, () => setState(() => _tab = 0))),
            Expanded(child: _Tab(Icons.person_outline_rounded, Icons.person_rounded, 'Profile', _tab == 1, () => setState(() => _tab = 1))),
            Expanded(child: _Tab(Icons.tune_rounded, Icons.tune_rounded, 'Settings', _tab == 2, () => setState(() => _tab = 2))),
          ]),
        ),
      ),
    );
    return Scaffold(
      body: Stack(children: [
        IndexedStack(index: _tab, children: const [HomePage(), ProfilePage(), SettingsPage()]),
        Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 14,
          child: Row(children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 10))
                ], borderRadius: BorderRadius.circular(31)),
                child: pill,
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: vc.accent,
              shape: const CircleBorder(),
              elevation: 6,
              shadowColor: Colors.black54,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _add,
                child: SizedBox(
                    width: 62, height: 62, child: Icon(Icons.add_rounded, size: 30, color: vc.onAccent)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(this.icon, this.activeIcon, this.label, this.on, this.onTap);
  final IconData icon, activeIcon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final col = on ? vc.accent : vc.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!on) HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: on ? vc.accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(26)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(on ? activeIcon : icon, size: 22, color: col),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontFamily: kSans, fontSize: 10.5, fontWeight: FontWeight.w600, color: col)),
        ]),
      ),
    );
  }
}

class _TypeSheet extends StatelessWidget {
  const _TypeSheet();

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String title, String sub, VoidCallback onTap) {
      final vc = context.vc;
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: vc.accent.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: vc.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: VT.body(context).copyWith(fontWeight: FontWeight.w600)),
              Text(sub, style: VT.sub(context)),
            ])),
            Icon(Icons.chevron_right_rounded, color: vc.faint),
          ]),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Align(
          alignment: Alignment.centerLeft,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Add to vault', style: VT.h2(context)))),
      row(Icons.language_rounded, 'Login', 'Websites and apps',
          () => Navigator.pop(context, ItemKind.login)),
      row(Icons.credit_card_rounded, 'Bank & Card', 'Cards, bank accounts and UPI',
          () => Navigator.pop(context, ItemKind.card)),
      row(Icons.badge_outlined, 'Identity', 'Aadhaar, PAN, Passport, Licence, Voter ID',
          () => Navigator.pop(context, ItemKind.aadhaar)),
      const SizedBox(height: 14),
    ]);
  }
}
