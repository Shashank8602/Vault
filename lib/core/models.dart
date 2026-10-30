import 'dart:math';

import 'package:flutter/material.dart';

const String kUncategorisedId = 'uncategorised';

class Category {
  Category({required this.id, required this.name, required this.color});

  final String id;
  String name;
  int color; // ARGB

  Color get colour => Color(color);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};
  factory Category.fromJson(Map<String, dynamic> j) => Category(
      id: j['id'] as String, name: j['name'] as String, color: j['color'] as int);
}

/// Colours offered when creating or recolouring a category.
const List<int> kCategoryPalette = [
  0xFFD4B47A, // gold
  0xFFD19A9A, // rose
  0xFF8FA8D1, // blue
  0xFF9FBF94, // green
  0xFFB0A2D6, // violet
  0xFFD8A36F, // amber
];

List<Category> defaultCategories() => [
      Category(id: 'banking', name: 'Banking', color: 0xFFD4B47A),
      Category(id: 'social', name: 'Social', color: 0xFFD19A9A),
      Category(id: 'email', name: 'Email', color: 0xFF8FA8D1),
      Category(id: 'ids', name: 'IDs', color: 0xFFB0A2D6),
      Category(id: 'shopping', name: 'Shopping', color: 0xFF9FBF94),
      Category(id: 'entertainment', name: 'Entertainment', color: 0xFFD8A36F),
    ];

final Category kUncategorised =
    Category(id: kUncategorisedId, name: 'Uncategorised', color: 0xFF8E897F);

/// What kind of record an item is. Each kind has a field template.
enum ItemKind { login, card, account, aadhaar, pan, passport, drivingLicense, voterId }

extension ItemKindX on ItemKind {
  bool get isIdentity => index >= ItemKind.aadhaar.index;
  bool get isBank => this == ItemKind.card || this == ItemKind.account;
}

enum FieldType { text, secret, date, phone, number }

class FieldDef {
  const FieldDef(this.key, this.label,
      {this.type = FieldType.text,
      this.secret = false,
      this.mono = false,
      this.hint,
      this.upper = false});
  final String key;
  final String label;
  final FieldType type;
  final bool secret;
  final bool mono;
  final String? hint;
  final bool upper;
}

class KindSpec {
  const KindSpec(this.kind, this.label, this.fields, {this.titleHint = ''});
  final ItemKind kind;
  final String label;
  final List<FieldDef> fields;
  final String titleHint;
}

const Map<ItemKind, KindSpec> kKindSpecs = {
  ItemKind.login: KindSpec(ItemKind.login, 'Login', [
    FieldDef('username', 'Username / Email'),
    FieldDef('password', 'Password', secret: true, mono: true),
    FieldDef('url', 'Website', hint: 'https://'),
  ], titleHint: 'e.g. Netflix'),
  ItemKind.card: KindSpec(ItemKind.card, 'Card', [
    FieldDef('number', 'Card number',
        type: FieldType.number, secret: true, mono: true),
    FieldDef('holder', 'Name on card', upper: true),
    FieldDef('expiry', 'Expiry', hint: 'MM/YY', mono: true),
    FieldDef('cvv', 'CVV', type: FieldType.number, secret: true, mono: true),
    FieldDef('pin', 'Card PIN', type: FieldType.number, secret: true, mono: true),
  ], titleHint: 'e.g. HDFC Millennia'),
  ItemKind.account: KindSpec(ItemKind.account, 'Bank account', [
    FieldDef('accountNo', 'Account number',
        type: FieldType.number, secret: true, mono: true),
    FieldDef('ifsc', 'IFSC', mono: true, upper: true),
    FieldDef('branch', 'Branch'),
    FieldDef('upiId', 'UPI ID', hint: 'name@bank'),
    FieldDef('upiPin', 'UPI PIN', type: FieldType.number, secret: true, mono: true),
  ], titleHint: 'e.g. SBI Savings'),
  ItemKind.aadhaar: KindSpec(ItemKind.aadhaar, 'Aadhaar', [
    FieldDef('number', 'Aadhaar number',
        type: FieldType.number, secret: true, mono: true),
    FieldDef('name', 'Name'),
    FieldDef('dob', 'Date of birth', type: FieldType.date),
    FieldDef('phone', 'Linked phone', type: FieldType.phone, mono: true),
  ], titleHint: 'Aadhaar'),
  ItemKind.pan: KindSpec(ItemKind.pan, 'PAN', [
    FieldDef('number', 'PAN number', mono: true, upper: true),
    FieldDef('name', 'Name'),
    FieldDef('dob', 'Date of birth', type: FieldType.date),
  ], titleHint: 'PAN'),
  ItemKind.passport: KindSpec(ItemKind.passport, 'Passport', [
    FieldDef('number', 'Passport number', mono: true, upper: true),
    FieldDef('issued', 'Date of issue', type: FieldType.date),
    FieldDef('expires', 'Date of expiry', type: FieldType.date),
    FieldDef('place', 'Place of issue'),
  ], titleHint: 'Passport'),
  ItemKind.drivingLicense: KindSpec(ItemKind.drivingLicense, 'Driving Licence', [
    FieldDef('number', 'Licence number', mono: true, upper: true),
    FieldDef('validUntil', 'Valid until', type: FieldType.date),
    FieldDef('authority', 'Issuing authority'),
  ], titleHint: 'Driving Licence'),
  ItemKind.voterId: KindSpec(ItemKind.voterId, 'Voter ID', [
    FieldDef('number', 'Voter ID number', mono: true, upper: true),
    FieldDef('name', 'Name'),
  ], titleHint: 'Voter ID'),
};

class Item {
  Item({
    required this.id,
    required this.kind,
    required this.title,
    required this.categoryId,
    required this.fields,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  ItemKind kind;
  String title;
  String categoryId;
  Map<String, String> fields;
  final DateTime createdAt;
  DateTime updatedAt;

  KindSpec get spec => kKindSpecs[kind]!;

  String field(String key) => fields[key] ?? '';

  /// One-line description for list rows. Never reveals secrets in full.
  String get subtitle {
    String last4(String s) {
      final d = s.replaceAll(RegExp(r'\D'), '');
      return d.length <= 4 ? d : d.substring(d.length - 4);
    }

    switch (kind) {
      case ItemKind.login:
        return field('username');
      case ItemKind.card:
        final n = field('number');
        if (n.isEmpty) return 'Card';
        return '${CardNetwork.detect(n).label} •••• ${last4(n)}';
      case ItemKind.account:
        final n = field('accountNo');
        if (n.isNotEmpty) return 'Account •••• ${last4(n)}';
        return field('upiId');
      case ItemKind.aadhaar:
        final n = field('number');
        return n.isEmpty ? '' : '•••• •••• ${last4(n)}';
      case ItemKind.passport:
        final e = field('expires');
        return e.isEmpty ? field('number') : 'Expires $e';
      case ItemKind.drivingLicense:
        final e = field('validUntil');
        return e.isEmpty ? field('number') : 'Valid until $e';
      case ItemKind.pan:
      case ItemKind.voterId:
        return field('number');
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'categoryId': categoryId,
        'fields': fields,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'] as String,
        kind: ItemKind.values.byName(j['kind'] as String),
        title: j['title'] as String,
        categoryId: j['categoryId'] as String? ?? kUncategorisedId,
        fields: Map<String, String>.from(j['fields'] as Map),
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

enum CardNetwork {
  visa('Visa'),
  mastercard('Mastercard'),
  rupay('RuPay'),
  amex('Amex'),
  other('Card');

  const CardNetwork(this.label);
  final String label;

  static CardNetwork detect(String number) {
    final n = number.replaceAll(RegExp(r'\D'), '');
    if (n.isEmpty) return other;
    if (n.startsWith('4')) return visa;
    if (n.startsWith('34') || n.startsWith('37')) return amex;
    final two = n.length >= 2 ? int.tryParse(n.substring(0, 2)) ?? 0 : 0;
    final four = n.length >= 4 ? int.tryParse(n.substring(0, 4)) ?? 0 : 0;
    if ((two >= 51 && two <= 55) || (four >= 2221 && four <= 2720)) {
      return mastercard;
    }
    // RuPay ranges: 60, 65, 81, 82, 508
    if (n.startsWith('60') ||
        n.startsWith('65') ||
        n.startsWith('81') ||
        n.startsWith('82') ||
        n.startsWith('508')) {
      return rupay;
    }
    return other;
  }
}

class Profile {
  Profile({this.name = '', this.avatarB64});
  String name;
  String? avatarB64;

  Map<String, dynamic> toJson() => {'name': name, 'avatar': avatarB64};
  factory Profile.fromJson(Map<String, dynamic> j) =>
      Profile(name: j['name'] as String? ?? '', avatarB64: j['avatar'] as String?);
}

/// Everything stored inside the encrypted vault file.
class VaultData {
  VaultData({
    required this.items,
    required this.categories,
    required this.profile,
    required this.createdAt,
    this.recoveryKey,
  });

  final List<Item> items;
  final List<Category> categories;
  final Profile profile;
  final DateTime createdAt;
  String? recoveryKey;

  factory VaultData.empty() => VaultData(
      items: [],
      categories: defaultCategories(),
      profile: Profile(),
      createdAt: DateTime.now());

  Map<String, dynamic> toJson() => {
        'v': 1,
        'recoveryKey': recoveryKey,
        'createdAt': createdAt.toIso8601String(),
        'profile': profile.toJson(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory VaultData.fromJson(Map<String, dynamic> j) => VaultData(
        createdAt: DateTime.parse(j['createdAt'] as String),
        recoveryKey: j['recoveryKey'] as String?,
        profile: Profile.fromJson(Map<String, dynamic>.from(j['profile'] as Map)),
        categories: [
          for (final c in j['categories'] as List)
            Category.fromJson(Map<String, dynamic>.from(c as Map))
        ],
        items: [
          for (final i in j['items'] as List)
            Item.fromJson(Map<String, dynamic>.from(i as Map))
        ],
      );
}

String newId() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
}
