import 'package:flutter/material.dart';

import '../core/models.dart';
import '../theme/theme.dart';

/// The dark card picture used in the form preview and detail header. Flat
/// colours only, and dark in both themes like a real metal card.
class CardVisual extends StatelessWidget {
  const CardVisual({
    super.key,
    required this.bank,
    required this.number,
    required this.holder,
    required this.expiry,
    this.masked = false,
  });

  final String bank;
  final String number;
  final String holder;
  final String expiry;
  final bool masked;

  static String group(String digits, {bool amex = false}) {
    final d = digits.replaceAll(RegExp(r'\D'), '');
    final parts = <String>[];
    if (amex) {
      // 4-6-5
      if (d.isNotEmpty) parts.add(d.substring(0, d.length.clamp(0, 4)));
      if (d.length > 4) parts.add(d.substring(4, d.length.clamp(4, 10)));
      if (d.length > 10) parts.add(d.substring(10, d.length.clamp(10, 15)));
      return parts.join(' ');
    }
    for (var i = 0; i < d.length; i += 4) {
      parts.add(d.substring(i, (i + 4).clamp(0, d.length)));
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final net = CardNetwork.detect(number);
    final digits = number.replaceAll(RegExp(r'\D'), '');
    String shown;
    if (digits.isEmpty) {
      shown = '•••• •••• •••• ••••';
    } else if (masked && digits.length >= 4) {
      shown = '•••• •••• •••• ${digits.substring(digits.length - 4)}';
    } else {
      shown = group(digits, amex: net == CardNetwork.amex);
    }
    const ink = Color(0xFFEDE9E1);
    const dim = Color(0xFF8E897F);
    const gold = Color(0xFFD4B47A);
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2E2D33)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(
              child: Text(bank.isEmpty ? 'Card' : bank,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: kSans, fontSize: 13, fontWeight: FontWeight.w600, color: ink)),
            ),
            if (net != CardNetwork.other)
              Text(net.label.toUpperCase(),
                  style: const TextStyle(
                      fontFamily: kMono, fontSize: 10.5, letterSpacing: 1.4, color: gold)),
          ]),
          const SizedBox(height: 16),
          Container(
            width: 38,
            height: 28,
            decoration: BoxDecoration(
                color: const Color(0xFFC6A970), borderRadius: BorderRadius.circular(6)),
            child: Center(
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                    border: Border.all(color: const Color(0x73281C08)),
                    borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(shown,
                style: const TextStyle(
                    fontFamily: kMono,
                    fontSize: 17,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w500,
                    color: ink)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _Meta('CARD HOLDER', holder.isEmpty ? '—' : holder.toUpperCase(), dim, ink),
            ),
            _Meta('VALID THRU', expiry.isEmpty ? '—' : expiry, dim, ink),
          ]),
        ]),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.label, this.value, this.dim, this.ink);
  final String label, value;
  final Color dim, ink;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontFamily: kMono, fontSize: 8.5, letterSpacing: 1.2, color: dim)),
        const SizedBox(height: 2),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: kMono, fontSize: 12, fontWeight: FontWeight.w500, color: ink)),
      ]);
}
