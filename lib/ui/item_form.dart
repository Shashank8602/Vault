import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../theme/theme.dart';
import 'card_visual.dart';
import 'home_page.dart' show CategorySheet;
import 'widgets.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

DateTime? parseDate(String s) {
  final p = s.split(' ');
  if (p.length != 3) return null;
  final m = _months.indexOf(p[1]);
  final d = int.tryParse(p[0]);
  final y = int.tryParse(p[2]);
  if (m < 0 || d == null || y == null) return null;
  return DateTime(y, m + 1, d);
}

/// Add or edit any item. Fields come from [kKindSpecs], so every kind shares this form.
class ItemFormPage extends StatefulWidget {
  const ItemFormPage({super.key, required this.kind, this.item});
  final ItemKind kind;
  final Item? item;

  @override
  State<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<ItemFormPage> {
  late ItemKind _kind = widget.kind;
  final _title = TextEditingController();
  final Map<String, TextEditingController> _c = {};
  late String _categoryId;
  bool _saving = false;
  bool get _editing => widget.item != null;

  TextEditingController _ctl(String key) => _c.putIfAbsent(key, () {
        final c = TextEditingController(text: widget.item?.field(key) ?? '');
        c.addListener(() => setState(() {}));
        return c;
      });

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    if (_editing) {
      _title.text = widget.item!.title;
      _categoryId = widget.item!.categoryId;
    } else {
      _categoryId = _defaultCategory(app);
    }
  }

  String _defaultCategory(AppState app) {
    final want = _kind.isBank ? 'banking' : (_kind.isIdentity ? 'ids' : 'social');
    if (app.data.categories.any((c) => c.id == want)) return want;
    return app.data.categories.isNotEmpty ? app.data.categories.first.id : kUncategorisedId;
  }

  @override
  void dispose() {
    _title.dispose();
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _switchKind(ItemKind k) {
    if (k == _kind) return;
    setState(() {
      _kind = k;
      for (final c in _c.values) {
        c.clear();
      }
      if (!_editing) _categoryId = _defaultCategory(context.read<AppState>());
    });
  }

  Future<void> _save() async {
    final app = context.read<AppState>();
    setState(() => _saving = true);
    final fields = <String, String>{};
    for (final f in kKindSpecs[_kind]!.fields) {
      var v = _ctl(f.key).text.trim();
      if (f.type == FieldType.number) v = v.replaceAll(RegExp(r'\s'), '');
      if (v.isNotEmpty) fields[f.key] = v;
    }
    final now = DateTime.now();
    final item = widget.item ??
        Item(
            id: newId(),
            kind: _kind,
            title: '',
            categoryId: _categoryId,
            fields: {},
            createdAt: now,
            updatedAt: now);
    item
      ..kind = _kind
      ..title = _title.text.trim()
      ..categoryId = _categoryId
      ..fields = fields;
    await app.saveItem(item);
    if (mounted) Navigator.pop(context);
  }

  List<TextInputFormatter> _formatters(FieldDef f) {
    switch (f.key) {
      case 'number':
        if (_kind == ItemKind.card) return [_DigitsFormatter(19, group: true)];
        if (_kind == ItemKind.aadhaar) return [_DigitsFormatter(12, group: true)];
        break;
      case 'accountNo':
        return [_DigitsFormatter(18)];
      case 'cvv':
        return [_DigitsFormatter(4)];
      case 'pin':
      case 'upiPin':
        return [_DigitsFormatter(6)];
      case 'phone':
        return [_DigitsFormatter(13)];
      case 'expiry':
        return [_ExpiryFormatter()];
    }
    if (f.upper) {
      return [
        TextInputFormatter.withFunction(
            (o, n) => n.copyWith(text: n.text.toUpperCase()))
      ];
    }
    return const [];
  }

  TextInputType _keyboard(FieldDef f) => switch (f.type) {
        FieldType.number || FieldType.phone => TextInputType.number,
        _ => f.key == 'url'
            ? TextInputType.url
            : (f.key == 'username' ? TextInputType.emailAddress : TextInputType.text),
      };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final vc = context.vc;
    final spec = kKindSpecs[_kind]!;
    final cat = app.categoryOf(_categoryId);
    final title = _editing ? 'Edit ${spec.label.toLowerCase()}' : 'New ${_kind.isBank ? 'bank item' : spec.label.toLowerCase()}';
    final titleOk = _title.text.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          PageBar(
            title: _kind.isIdentity ? (_editing ? 'Edit ID' : 'New ID') : title,
            leading: TextAction('Cancel', onTap: () => Navigator.pop(context)),
            trailing: TextAction('Save', gold: true, onTap: (titleOk && !_saving) ? _save : null),
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 32),
              children: [
                if (_kind.isBank && !_editing)
                  _Segment(
                    labels: const ['Card', 'Bank account'],
                    index: _kind == ItemKind.card ? 0 : 1,
                    onChanged: (i) => _switchKind(i == 0 ? ItemKind.card : ItemKind.account),
                  ),
                if (_kind.isIdentity && !_editing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final k in ItemKind.values.where((k) => k.isIdentity))
                        GestureDetector(
                          onTap: () => _switchKind(k),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: k == _kind ? vc.accent.withValues(alpha: 0.15) : vc.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: k == _kind
                                        ? vc.accent.withValues(alpha: 0.45)
                                        : vc.line)),
                            child: Text(kKindSpecs[k]!.label,
                                style: TextStyle(
                                    fontFamily: kSans,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: k == _kind ? vc.accent : vc.muted)),
                          ),
                        ),
                    ]),
                  ),
                if (_kind == ItemKind.card)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: CardVisual(
                      bank: _title.text,
                      number: _ctl('number').text,
                      holder: _ctl('holder').text,
                      expiry: _ctl('expiry').text,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 18),
                    child: Center(
                      child: LetterTile(
                          letter: _title.text,
                          color: cat.colour,
                          size: 72,
                          icon: _title.text.isEmpty && _kind.isIdentity ? Icons.badge_outlined : null),
                    ),
                  ),
                VField(
                  label: 'Title',
                  controller: _title,
                  hint: spec.titleHint,
                  autofocus: !_editing,
                  onChanged: (_) => setState(() {}),
                ),
                for (final f in spec.fields) _fieldWidget(f),
                _CategoryPicker(
                  category: cat,
                  onTap: () async {
                    final id = await _pickCategory(context, app, _categoryId);
                    if (id != null) setState(() => _categoryId = id);
                  },
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _fieldWidget(FieldDef f) {
    if (f.type == FieldType.date) {
      return _DateBox(label: f.label, controller: _ctl(f.key));
    }
    return VField(
      label: f.label,
      controller: _ctl(f.key),
      hint: f.hint,
      mono: f.mono,
      secret: f.secret,
      upper: f.upper,
      keyboard: _keyboard(f),
      formatters: _formatters(f),
    );
  }
}

Future<String?> _pickCategory(BuildContext context, AppState app, String current) {
  return showVaultSheet<String>(context, scroll: true, builder: (ctx) {
    final vc = ctx.vc;
    Widget row(String id, String name, Color color) => InkWell(
          onTap: () => Navigator.pop(ctx, id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 14),
              Expanded(child: Text(name, style: VT.body(ctx))),
              if (id == current) Icon(Icons.check_rounded, size: 20, color: vc.accent),
            ]),
          ),
        );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
      child: ListView(shrinkWrap: true, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Category', style: VT.h2(ctx))),
        for (final c in app.data.categories) row(c.id, c.name, c.colour),
        row(kUncategorisedId, kUncategorised.name, kUncategorised.colour),
        InkWell(
          onTap: () async {
            final res = await showVaultSheet<(String, int)>(ctx,
                scroll: true, builder: (_) => const CategorySheet(title: 'New category'));
            if (res == null) return;
            final c = await app.addCategory(res.$1, res.$2);
            if (ctx.mounted) Navigator.pop(ctx, c.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(children: [
              Icon(Icons.add_rounded, size: 18, color: vc.accent),
              const SizedBox(width: 10),
              Text('New category',
                  style: VT.body(ctx).copyWith(color: vc.accent, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
      ]),
    );
  });
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.category, required this.onTap});
  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text('Category',
              style: TextStyle(
                  fontFamily: kSans, fontSize: 12, fontWeight: FontWeight.w600, color: vc.muted)),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: vc.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: vc.line)),
            child: Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: category.colour, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(category.name, style: VT.body(context))),
              Icon(Icons.chevron_right_rounded, color: vc.faint),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 6, 18, 16),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: vc.bg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: vc.line)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: i == index ? vc.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(7)),
                child: Text(labels[i],
                    style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: i == index ? vc.text : vc.muted)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final has = controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label,
              style: TextStyle(
                  fontFamily: kSans, fontSize: 12, fontWeight: FontWeight.w600, color: vc.muted)),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final now = DateTime.now();
            final initial = parseDate(controller.text) ?? now;
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(1900),
              lastDate: DateTime(now.year + 40),
              initialEntryMode: DatePickerEntryMode.calendarOnly,
              builder: (ctx, child) => child!,
            );
            if (picked != null) controller.text = formatDate(picked);
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.only(left: 14, right: 6),
            decoration: BoxDecoration(
                color: vc.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: vc.line)),
            child: Row(children: [
              Expanded(
                child: Text(has ? controller.text : 'Select date',
                    style: VT.body(context).copyWith(color: has ? vc.text : vc.faint)),
              ),
              if (has)
                IconButton(
                    splashRadius: 20,
                    onPressed: controller.clear,
                    icon: Icon(Icons.close_rounded, size: 18, color: vc.muted))
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.calendar_today_outlined, size: 18, color: vc.muted),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _DigitsFormatter extends TextInputFormatter {
  _DigitsFormatter(this.max, {this.group = false});
  final int max;
  final bool group;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue neu) {
    var d = neu.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > max) d = d.substring(0, max);
    final out = group ? CardVisual.group(d) : d;
    return TextEditingValue(text: out, selection: TextSelection.collapsed(offset: out.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue neu) {
    var d = neu.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > 4) d = d.substring(0, 4);
    // Backspacing over the slash should remove a digit, not get stuck.
    if (old.text.endsWith('/') && neu.text.length < old.text.length && d.length == 2) {
      d = d.substring(0, 1);
    }
    var out = d;
    if (d.length > 2) {
      out = '${d.substring(0, 2)}/${d.substring(2)}';
    } else if (d.length == 2 && neu.text.length >= old.text.length) {
      out = '$d/';
    }
    return TextEditingValue(text: out, selection: TextSelection.collapsed(offset: out.length));
  }
}
