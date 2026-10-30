import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../theme/theme.dart';
import 'item_detail.dart';
import 'shell.dart' show kNavClearance;
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = TextEditingController();
  String _query = '';
  String _cat = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
  }

  List<Item> _visible(AppState app) {
    final q = _query.trim().toLowerCase();
    final list = app.data.items.where((i) {
      if (_cat != 'all' && i.categoryId != _cat) return false;
      if (q.isEmpty) return true;
      return i.title.toLowerCase().contains(q) ||
          i.subtitle.toLowerCase().contains(q) ||
          i.field('username').toLowerCase().contains(q) ||
          i.field('url').toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.status != AppStatus.unlocked) return const SizedBox.shrink();
    final vc = context.vc;
    final items = _visible(app);
    final total = app.data.items.length;
    if (_cat != 'all' &&
        _cat != kUncategorisedId &&
        !app.data.categories.any((c) => c.id == _cat)) {
      _cat = 'all';
    }
    final name = app.data.profile.name;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_greeting(),
                        style: TextStyle(
                            fontFamily: kSans,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: vc.muted)),
                    const SizedBox(height: 2),
                    Text(name.isEmpty ? 'Your vault' : name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: VT.title(context)),
                  ]),
                ),
                RoundIconButton(Icons.lock_outline_rounded,
                    tooltip: 'Lock now', onTap: () {
                  HapticFeedback.mediumImpact();
                  app.lock();
                }),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Row(children: [
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                        color: vc.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: vc.line)),
                    child: Row(children: [
                      Icon(Icons.search_rounded, size: 20, color: vc.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (v) => setState(() => _query = v),
                          style: VT.body(context),
                          cursorColor: vc.accent,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: 'Search $total ${total == 1 ? 'item' : 'items'}',
                            hintStyle: VT.body(context)
                                .copyWith(color: vc.muted, fontWeight: FontWeight.w400),
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                          child: Icon(Icons.close_rounded, size: 18, color: vc.muted),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                _FilterButton(
                  label: _cat == 'all' ? 'All' : app.categoryOf(_cat).name,
                  color: _cat == 'all' ? null : app.categoryOf(_cat).colour,
                  active: _cat != 'all',
                  onTap: _openFilter,
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
              child: SectionLabel(
                  _cat == 'all' ? 'All items' : app.categoryOf(_cat).name,
                  trailing: 'A–Z')),
          if (items.isEmpty)
            SliverToBoxAdapter(child: _Empty(searching: _query.isNotEmpty, hasAny: total > 0))
          else
            SliverToBoxAdapter(
              child: Group(children: [
                for (final it in items) _ItemRow(item: it),
              ]),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: kNavClearance)),
        ],
      ),
    );
  }

  Future<void> _openFilter() async {
    final picked = await showVaultSheet<String>(context,
        scroll: true, builder: (_) => _FilterSheet(current: _cat));
    if (picked != null && mounted) setState(() => _cat = picked);
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton(
      {required this.label, required this.onTap, this.color, this.active = false});
  final String label;
  final Color? color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        constraints: const BoxConstraints(maxWidth: 140),
        padding: const EdgeInsets.only(left: 12, right: 6),
        decoration: BoxDecoration(
          color: active ? vc.accent.withValues(alpha: 0.15) : vc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? vc.accent.withValues(alpha: 0.45) : vc.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (color != null) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: active ? vc.accent : vc.text)),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: active ? vc.accent : vc.muted),
        ]),
      ),
    );
  }
}

/// Pick a category, or add / rename / recolour / delete categories.
class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.current});
  final String current;

  Future<void> _edit(BuildContext context, AppState app, Category c) async {
    final res = await showVaultSheet<(String, int)>(context,
        scroll: true,
        builder: (_) => CategorySheet(
              title: 'Edit category',
              initialName: c.name,
              initialColor: c.color,
              onDelete: () async {
                final n = app.data.items.where((i) => i.categoryId == c.id).length;
                final ok = await confirmDialog(context,
                    title: 'Delete "${c.name}"?',
                    message: n == 0
                        ? 'This category is empty.'
                        : '$n ${n == 1 ? 'item moves' : 'items move'} to Uncategorised. Nothing is deleted.',
                    confirmLabel: 'Delete');
                if (ok) await app.deleteCategory(c.id);
                return ok;
              },
            ));
    if (res != null) await app.updateCategory(c, name: res.$1, color: res.$2);
  }

  Future<void> _add(BuildContext context, AppState app) async {
    final res = await showVaultSheet<(String, int)>(context,
        scroll: true, builder: (_) => const CategorySheet(title: 'New category'));
    if (res == null) return;
    final c = await app.addCategory(res.$1, res.$2);
    if (context.mounted) Navigator.pop(context, c.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final vc = context.vc;
    int count(String id) => app.data.items.where((i) => i.categoryId == id).length;

    Widget row(String id, String name, Color? color, int n, {Category? editable}) => InkWell(
          onTap: () => Navigator.pop(context, id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
            child: Row(children: [
              SizedBox(
                width: 12,
                child: color == null
                    ? Icon(Icons.apps_rounded, size: 14, color: vc.muted)
                    : Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(name,
                    style: VT.body(context).copyWith(
                        fontWeight: id == current ? FontWeight.w700 : FontWeight.w500,
                        color: id == current ? vc.accent : vc.text)),
              ),
              Text('$n', style: TextStyle(fontFamily: kMono, fontSize: 12.5, color: vc.muted)),
              const SizedBox(width: 4),
              if (editable != null)
                IconButton(
                    splashRadius: 20,
                    tooltip: 'Edit',
                    onPressed: () => _edit(context, app, editable),
                    icon: Icon(Icons.edit_outlined, size: 18, color: vc.muted))
              else
                const SizedBox(width: 48, height: 48),
            ]),
          ),
        );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: ListView(shrinkWrap: true, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text('Categories', style: VT.h2(context))),
        row('all', 'All items', null, app.data.items.length),
        for (final c in app.data.categories) row(c.id, c.name, c.colour, count(c.id), editable: c),
        if (count(kUncategorisedId) > 0)
          row(kUncategorisedId, kUncategorised.name, kUncategorised.colour, count(kUncategorisedId)),
        InkWell(
          onTap: () => _add(context, app),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              Icon(Icons.add_rounded, size: 18, color: vc.accent),
              const SizedBox(width: 12),
              Text('New category',
                  style: VT.body(context).copyWith(color: vc.accent, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final cat = app.categoryOf(item.categoryId);
    final iconFor = item.kind.isIdentity
        ? Icons.badge_outlined
        : (item.kind == ItemKind.account ? Icons.account_balance_outlined : null);
    return InkWell(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => ItemDetailPage(itemId: item.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          LetterTile(letter: item.title, color: cat.colour, icon: iconFor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VT.body(context).copyWith(fontWeight: FontWeight.w600)),
              if (item.subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VT.sub(context)),
                ),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: context.vc.faint),
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.searching, required this.hasAny});
  final bool searching;
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final title = searching ? 'No matches' : (hasAny ? 'Nothing in this category' : 'Your vault is empty');
    final body = searching
        ? 'Try a different name, username or website.'
        : (hasAny ? 'Items you add here will show up in this list.' : 'Tap the gold + button to add your first login, card or ID.');
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 56, 40, 0),
      child: Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: vc.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
          child: Icon(searching ? Icons.search_off_rounded : Icons.shield_outlined,
              color: vc.accent, size: 30),
        ),
        const SizedBox(height: 16),
        Text(title, style: VT.h2(context).copyWith(fontSize: 18)),
        const SizedBox(height: 6),
        Text(body,
            textAlign: TextAlign.center,
            style: VT.sub(context).copyWith(height: 1.5, fontSize: 13)),
      ]),
    );
  }
}

/// Name + colour editor used for both new and existing categories.
class CategorySheet extends StatefulWidget {
  const CategorySheet(
      {super.key, required this.title, this.initialName = '', this.initialColor, this.onDelete});
  final String title;

  /// When set, a Delete button is shown. Returns true if the category was deleted.
  final Future<bool> Function()? onDelete;
  final String initialName;
  final int? initialColor;

  @override
  State<CategorySheet> createState() => CategorySheetState();
}

class CategorySheetState extends State<CategorySheet> {
  late final _name = TextEditingController(text: widget.initialName);
  late int _color = widget.initialColor ?? kCategoryPalette.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text(widget.title, style: VT.h2(context))),
        VField(
          label: 'Name',
          controller: _name,
          autofocus: true,
          hint: 'e.g. Banking',
          maxLength: 24,
          onChanged: (_) => setState(() {}),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          child: Wrap(spacing: 14, children: [
            for (final col in kCategoryPalette)
              GestureDetector(
                onTap: () => setState(() => _color = col),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: Color(col),
                      shape: BoxShape.circle,
                      border: col == _color ? Border.all(color: vc.text, width: 2.5) : null),
                  child: col == _color
                      ? const Icon(Icons.check_rounded, size: 18, color: Colors.black87)
                      : null,
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: VButton('Save',
              onPressed: _name.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, (_name.text.trim(), _color))),
        ),
        if (widget.onDelete != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: VButton('Delete category',
                kind: VButtonKind.dangerGhost,
                icon: Icons.delete_outline_rounded, onPressed: () async {
              if (await widget.onDelete!() && context.mounted) Navigator.pop(context);
            }),
          ),
      ]),
    );
  }
}
