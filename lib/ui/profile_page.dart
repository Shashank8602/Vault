import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../theme/theme.dart';
import 'shell.dart' show kNavClearance;
import 'widgets.dart';

/// Circular avatar: the chosen photo, or the first letter of the name.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({super.key, required this.profile, this.size = 44, this.ring = true});
  final Profile profile;
  final double size;
  final bool ring;

  static String? _cacheKey;
  static Uint8List? _cacheBytes;

  static Uint8List? _bytes(String? b64) {
    if (b64 == null) return null;
    if (_cacheKey != b64) {
      _cacheKey = b64;
      _cacheBytes = base64Decode(b64);
    }
    return _cacheBytes;
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final bytes = _bytes(profile.avatarB64);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: vc.surface,
        border: ring ? Border.all(color: vc.accent, width: size > 60 ? 2 : 1.5) : null,
        image: bytes == null
            ? null
            : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
      child: bytes != null
          ? null
          : Text(
              profile.name.isEmpty ? 'V' : profile.name.characters.first.toUpperCase(),
              style: TextStyle(
                  fontFamily: kSans,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w600,
                  color: vc.accent)),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static String _date(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Future<void> _editName(BuildContext context, AppState app) async {
    final c = TextEditingController(text: app.data.profile.name);
    final name = await showVaultSheet<String>(context, scroll: true, builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Text('Your name', style: VT.h2(ctx))),
            VField(
                label: 'Name',
                controller: c,
                autofocus: true,
                maxLength: 24,
                onChanged: (_) => set(() {}),
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => Navigator.pop(ctx, v)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: VButton('Save', onPressed: () => Navigator.pop(ctx, c.text)),
            ),
          ]),
        ),
      );
    });
    c.dispose();
    if (name != null) await app.updateProfile(name: name);
  }

  Future<void> _photo(BuildContext context, AppState app) async {
    final has = app.data.profile.avatarB64 != null;
    final choice = await showVaultSheet<String>(context, builder: (ctx) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        SettingsRow(
            icon: Icons.photo_library_outlined,
            title: 'Choose from gallery',
            onTap: () => Navigator.pop(ctx, 'pick')),
        if (has)
          SettingsRow(
              icon: Icons.delete_outline_rounded,
              title: 'Remove photo',
              danger: true,
              onTap: () => Navigator.pop(ctx, 'remove')),
        const SizedBox(height: 12),
      ]);
    });
    if (choice == 'remove') {
      await app.updateProfile(clearAvatar: true);
    } else if (choice == 'pick') {
      app.suspendLock();
      try {
        final f = await ImagePicker().pickImage(
            source: ImageSource.gallery, maxWidth: 320, maxHeight: 320, imageQuality: 85);
        if (f != null) await app.updateProfile(avatarB64: base64Encode(await f.readAsBytes()));
      } finally {
        app.resumeLock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.status != AppStatus.unlocked) return const SizedBox.shrink();
    final vc = context.vc;
    final profile = app.data.profile;
    final counts = <Category, int>{};
    for (final c in [...app.data.categories, kUncategorised]) {
      final n = app.data.items.where((i) => i.categoryId == c.id).length;
      if (n > 0) counts[c] = n;
    }
    final maxCount = counts.values.fold<int>(1, (a, b) => a > b ? a : b);
    final last = app.lastBackup;

    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.only(bottom: kNavClearance), children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
            child: Text('Profile', style: VT.title(context))),
        Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
          decoration: BoxDecoration(
              color: vc.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: vc.line)),
          child: Column(children: [
            GestureDetector(
              onTap: () => _photo(context, app),
              child: Stack(clipBehavior: Clip.none, children: [
                AvatarCircle(profile: profile, size: 84),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: vc.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: vc.surface, width: 3)),
                    child: Icon(Icons.photo_camera_outlined, size: 13, color: vc.onAccent),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _editName(context, app),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(profile.name.isEmpty ? 'Add your name' : profile.name,
                      style: VT.h2(context).copyWith(
                          color: profile.name.isEmpty ? vc.muted : vc.text)),
                  const SizedBox(width: 8),
                  Icon(Icons.edit_outlined, size: 15, color: vc.muted),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            Text('Vault created ${_date(app.data.createdAt)}', style: VT.sub(context)),
          ]),
        ),
        const SectionLabel('Your vault'),
        Group(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('${app.data.items.length}',
                  style: TextStyle(
                      fontFamily: kMono, fontSize: 40, fontWeight: FontWeight.w500, color: vc.text)),
              const SizedBox(width: 10),
              Text(app.data.items.length == 1 ? 'item stored' : 'items stored',
                  style: TextStyle(
                      fontFamily: kSans, fontSize: 14, fontWeight: FontWeight.w500, color: vc.muted)),
            ]),
          ),
          if (counts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Column(children: [
                for (final e in counts.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.5),
                    child: Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: e.key.colour, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 98,
                          child: Text(e.key.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: kSans,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: vc.text))),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: e.value / maxCount,
                            minHeight: 5,
                            backgroundColor: vc.surface2,
                            valueColor: AlwaysStoppedAnimation(e.key.colour),
                          ),
                        ),
                      ),
                      SizedBox(
                          width: 26,
                          child: Text('${e.value}',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontFamily: kMono, fontSize: 12.5, color: vc.muted))),
                    ]),
                  ),
              ]),
            ),
          SettingsRow(
            icon: Icons.cloud_outlined,
            title: 'Last backup',
            subtitle: last == null
                ? 'No backup yet'
                : '${_date(last)}${app.lastBackupWhere == null ? '' : ' · ${app.lastBackupWhere}'}',
            chevron: false,
          ),
        ]),
      ]),
    );
  }
}
