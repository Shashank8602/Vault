import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/clipboard_guard.dart';
import '../core/models.dart';
import '../theme/theme.dart';
import 'card_visual.dart';
import 'item_form.dart';
import 'widgets.dart';

/// Revealed secrets hide themselves again after this long.
const Duration kRevealFor = Duration(seconds: 30);

class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({super.key, required this.itemId});
  final String itemId;

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  final Map<String, Timer> _revealed = {};

  @override
  void dispose() {
    for (final t in _revealed.values) {
      t.cancel();
    }
    super.dispose();
  }

  void _toggle(String key) {
    setState(() {
      final t = _revealed.remove(key);
      if (t != null) {
        t.cancel();
      } else {
        _revealed[key] = Timer(kRevealFor, () {
          if (mounted) setState(() => _revealed.remove(key));
        });
      }
    });
  }

  Future<void> _copy(FieldDef f, String value) async {
    final app = context.read<AppState>();
    final secs = app.clipboardSeconds;
    await ClipboardGuard.copy(value, Duration(seconds: secs));
    if (!mounted) return;
    showToast(context, secs > 0 && f.secret
        ? '${f.label} copied · clears in ${secs}s'
        : '${f.label} copied');
  }

  Future<void> _delete(Item item) async {
    final app = context.read<AppState>();
    final ok = await confirmDialog(context,
        title: 'Delete ${item.title}?',
        message: "This removes it from your vault. It can't be undone.",
        confirmLabel: 'Delete');
    if (!ok) return;
    await app.deleteItem(item.id);
    if (mounted) Navigator.pop(context);
  }

  static String _masked(FieldDef f, Item item, String v) {
    if (f.key == 'number' && item.kind == ItemKind.card) {
      final d = v.replaceAll(RegExp(r'\D'), '');
      return d.length <= 4 ? '••••' : '•••• •••• •••• ${d.substring(d.length - 4)}';
    }
    return '•' * (v.length.clamp(4, 12));
  }

  static String _display(FieldDef f, Item item, String v) {
    if (f.key == 'number' && item.kind == ItemKind.card) return CardVisual.group(v);
    if (f.key == 'number' && item.kind == ItemKind.aadhaar) return CardVisual.group(v);
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.status != AppStatus.unlocked) return const SizedBox.shrink();
    final idx = app.data.items.indexWhere((i) => i.id == widget.itemId);
    if (idx < 0) return const Scaffold(); // deleted
    final item = app.data.items[idx];
    final vc = context.vc;
    final cat = app.categoryOf(item.categoryId);
    final spec = item.spec;
    final rows = [for (final f in spec.fields) if (item.field(f.key).isNotEmpty) f];
    final isCard = item.kind == ItemKind.card;

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          PageBar(
            leading: RoundIconButton(Icons.arrow_back_rounded,
                tooltip: 'Back', onTap: () => Navigator.pop(context)),
            trailing: RoundIconButton(Icons.edit_outlined,
                tooltip: 'Edit',
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => ItemFormPage(kind: item.kind, item: item)))),
          ),
          if (isCard)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: CardVisual(
                bank: item.title,
                number: item.field('number'),
                holder: item.field('holder'),
                expiry: item.field('expiry'),
                masked: !_revealed.containsKey('number'),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
              child: Column(children: [
                LetterTile(
                    letter: item.title,
                    color: cat.colour,
                    size: 72,
                    icon: item.kind.isIdentity
                        ? Icons.badge_outlined
                        : (item.kind == ItemKind.account ? Icons.account_balance_outlined : null)),
                const SizedBox(height: 14),
                Text(item.title,
                    textAlign: TextAlign.center,
                    style: VT.h2(context).copyWith(fontSize: 26)),
                const SizedBox(height: 10),
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                      color: vc.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: vc.line)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: cat.colour, shape: BoxShape.circle)),
                    const SizedBox(width: 7),
                    Text(cat.name,
                        style: TextStyle(
                            fontFamily: kSans,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: vc.muted)),
                  ]),
                ),
              ]),
            ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No details saved yet. Tap the pencil to add some.',
                  textAlign: TextAlign.center, style: VT.sub(context)),
            )
          else
            Group(children: [
              for (final f in rows)
                _FieldRow(
                  def: f,
                  value: item.field(f.key),
                  shown: !f.secret || _revealed.containsKey(f.key),
                  display: _display(f, item, item.field(f.key)),
                  masked: _masked(f, item, item.field(f.key)),
                  onToggle: () => _toggle(f.key),
                  onCopy: () => _copy(f, item.field(f.key)),
                ),
            ]),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: VButton('Delete ${spec.label.toLowerCase()}',
                icon: Icons.delete_outline_rounded,
                kind: VButtonKind.dangerGhost,
                onPressed: () => _delete(item)),
          ),
        ]),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.def,
    required this.value,
    required this.shown,
    required this.display,
    required this.masked,
    required this.onToggle,
    required this.onCopy,
  });
  final FieldDef def;
  final String value;
  final bool shown;
  final String display;
  final String masked;
  final VoidCallback onToggle;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final mono = def.mono || def.secret;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(def.label.toUpperCase(), style: VT.label(context).copyWith(color: vc.muted, fontSize: 10.5)),
            const SizedBox(height: 6),
            Text(
              shown ? display : masked,
              style: TextStyle(
                fontFamily: mono ? kMono : kSans,
                fontSize: mono ? 15 : 15.5,
                fontWeight: FontWeight.w500,
                letterSpacing: shown || !def.secret ? 0.2 : 1.5,
                color: (def.secret && shown) ? vc.accent : vc.text,
              ),
            ),
          ]),
        ),
        if (def.secret)
          _ActionButton(
            icon: shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            tooltip: shown ? 'Hide' : 'Reveal',
            active: shown,
            onTap: onToggle,
          ),
        const SizedBox(width: 6),
        _ActionButton(icon: Icons.copy_rounded, tooltip: 'Copy', onTap: onCopy),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.onTap, this.tooltip, this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: active ? vc.accent.withValues(alpha: 0.14) : vc.surface2,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
              width: 36, height: 36, child: Icon(icon, size: 18, color: active ? vc.accent : vc.muted)),
        ),
      ),
    );
  }
}
