// Renders the main screens to PNGs (test/shots) so layout can be reviewed
// without a device. Skipped by default; run:
//   flutter test --update-goldens --run-skipped test/screens_test.dart
@Tags(['render'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vault/core/app_state.dart';
import 'package:vault/core/models.dart';
import 'package:vault/theme/theme.dart';
import 'package:vault/ui/item_detail.dart';
import 'package:vault/ui/item_form.dart';
import 'package:vault/ui/lock_screen.dart';
import 'package:vault/ui/onboarding.dart';
import 'package:vault/ui/shell.dart';
import 'package:vault/ui/splash_screen.dart';

Item _item(String id, ItemKind k, String title, String cat, Map<String, String> f) => Item(
    id: id, kind: k, title: title, categoryId: cat, fields: f,
    createdAt: DateTime(2026, 10, 30), updatedAt: DateTime(2026, 10, 30));

VaultData _sample() {
  final d = VaultData.empty();
  d.profile.name = 'Alex';
  d.items.addAll([
    _item('1', ItemKind.login, 'Amazon', 'shopping', {'username': 'alex@example.com', 'password': 'sample-password-1', 'url': 'amazon.in'}),
    _item('2', ItemKind.aadhaar, 'Aadhaar', 'ids', {'number': '000011112222', 'name': 'Alex Doe', 'dob': '1 Jan 1990'}),
    _item('3', ItemKind.login, 'Gmail', 'email', {'username': 'alex@example.com', 'password': 'sample-password-2', 'url': 'mail.google.com'}),
    _item('4', ItemKind.card, 'HDFC Millennia', 'banking', {'number': '5100000000004821', 'holder': 'Alex Doe', 'expiry': '08/29', 'cvv': '317', 'pin': '4821'}),
    _item('5', ItemKind.login, 'Instagram', 'social', {'username': '@alex.doe', 'password': 'abc12345'}),
    _item('6', ItemKind.passport, 'Passport', 'ids', {'number': 'Z4821736', 'issued': '15 Mar 2021', 'expires': '14 Mar 2031'}),
    _item('7', ItemKind.account, 'SBI Savings', 'banking', {'accountNo': '00000000000', 'ifsc': 'SBIN0001234', 'upiId': 'alex@upi'}),
  ]);
  return d;
}

Future<void> _pump(WidgetTester t, Widget home, {Brightness b = Brightness.dark, AppState? app}) async {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({});
  final a = app ?? AppState(await SharedPreferences.getInstance());
  await t.pumpWidget(ChangeNotifierProvider.value(
    value: a,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(b),
      home: home,
    ),
  ));
  await t.pump(const Duration(milliseconds: 1200));
}

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await l.load();
  }
  await load('IBMPlexSans', ['IBMPlexSans-Regular.ttf', 'IBMPlexSans-Medium.ttf', 'IBMPlexSans-SemiBold.ttf', 'IBMPlexSans-Bold.ttf']);
  await load('IBMPlexMono', ['IBMPlexMono-Regular.ttf', 'IBMPlexMono-Medium.ttf']);
}

void main() {
  setUpAll(_loadFonts);
  Future<AppState> open(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({});
    final a = AppState(await SharedPreferences.getInstance());
    a.debugOpen(_sample());
    return a;
  }

  for (final b in [Brightness.dark, Brightness.light]) {
    final n = b == Brightness.dark ? 'dark' : 'light';
    testWidgets('home $n', (t) async {
      await _pump(t, const Shell(), b: b, app: await open(t));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/home_$n.png'));
    });
    testWidgets('card detail $n', (t) async {
      await _pump(t, const ItemDetailPage(itemId: '4'), b: b, app: await open(t));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/card_$n.png'));
    });
  }
  testWidgets('login detail', (t) async {
    await _pump(t, const ItemDetailPage(itemId: '3'), app: await open(t));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/login.png'));
  });
  testWidgets('passport detail', (t) async {
    await _pump(t, const ItemDetailPage(itemId: '6'), app: await open(t));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/passport.png'));
  });
  testWidgets('new card form', (t) async {
    await _pump(t, const ItemFormPage(kind: ItemKind.card), app: await open(t));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/form_card.png'));
  });
  testWidgets('new login form', (t) async {
    await _pump(t, const ItemFormPage(kind: ItemKind.login), app: await open(t));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/form_login.png'));
  });
  testWidgets('profile + settings', (t) async {
    final a = await open(t);
    await _pump(t, const Shell(), app: a);
    await t.tap(find.text('Profile'));
    await t.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/profile.png'));
    await t.tap(find.text('Settings'));
    await t.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/settings.png'));
  });
  testWidgets('splash, lock, welcome', (t) async {
    await _pump(t, const SplashScreen());
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/splash.png'));
    await _pump(t, const LockScreen());
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/lock.png'));
    await _pump(t, const WelcomeScreen());
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/welcome.png'));
  });
}
