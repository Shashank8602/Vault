import 'dart:async';

import 'package:flutter/services.dart';

/// Copies a secret and wipes it from the clipboard after [clearAfter], but only
/// if the clipboard still holds that same value. The timer is global so it
/// survives leaving the screen the value was copied from.
class ClipboardGuard {
  ClipboardGuard._();
  static Timer? _timer;
  static String? _value;

  static Future<void> copy(String value, Duration clearAfter) async {
    _timer?.cancel();
    _value = value;
    await Clipboard.setData(ClipboardData(text: value));
    _timer = Timer(clearAfter, clearNow);
  }

  static Future<void> clearNow() async {
    _timer?.cancel();
    final expected = _value;
    _value = null;
    if (expected == null) return;
    final cur = await Clipboard.getData(Clipboard.kTextPlain);
    if (cur?.text == expected) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  }
}
