import 'package:flutter/material.dart';

const kBrand = Color(0xFFFC8019);
const kInk = Color(0xFF282C3F);
const kMuted = Color(0xFF686B78);
const kGreen = Color(0xFF0F8A65);
const kRed = Color(0xFFD6293E);
const kBg = Color(0xFFF4F4F5);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kBrand).copyWith(primary: kBrand, onPrimary: kInk, secondary: kGreen);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kBrand,
        foregroundColor: kInk,
        minimumSize: const Size(88, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kInk,
        minimumSize: const Size(88, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    navigationBarTheme: const NavigationBarThemeData(indicatorColor: Color(0xFFFFE3CC)),
  );
}

double toD(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
int toI(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);

List<Map<String, dynamic>> maps(dynamic v) =>
    ((v as List?) ?? <dynamic>[]).map((e) => Map<String, dynamic>.from(e as Map)).toList();

String money(num n) {
  final v = n.toDouble();
  final whole = (v - v.roundToDouble()).abs() < 0.005;
  return '\u20B9${whole ? v.round().toString() : v.toStringAsFixed(2)}';
}

void snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

/// Small coloured pill. kind: ok | warn | bad | info | muted
class Pill extends StatelessWidget {
  final String text;
  final String kind;
  const Pill(this.text, {super.key, this.kind = 'muted'});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (kind) {
      case 'ok':
        bg = const Color(0xFFE6F7EE);
        fg = const Color(0xFF0B6B4F);
        break;
      case 'warn':
        bg = const Color(0xFFFFF7E0);
        fg = const Color(0xFF8A5A00);
        break;
      case 'bad':
        bg = const Color(0xFFFDF0F0);
        fg = kRed;
        break;
      case 'info':
        bg = const Color(0xFFEAF1FF);
        fg = const Color(0xFF1D4ED8);
        break;
      default:
        bg = kBg;
        fg = kMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

Widget paymentPill(String status) {
  switch (status) {
    case 'Paid':
      return const Pill('Paid', kind: 'ok');
    case 'Pending COD':
      return const Pill('Pay cash on delivery', kind: 'warn');
    case 'Verification Pending':
      return const Pill('Payment being verified', kind: 'warn');
    case 'Unpaid':
      return const Pill('Not paid', kind: 'bad');
    case 'Failed':
      return const Pill('Payment failed', kind: 'bad');
    case 'Refund Due':
      return const Pill('Refund due', kind: 'bad');
    case 'Refunded':
      return const Pill('Refunded', kind: 'info');
  }
  return Pill(status);
}

String statusKind(String status) {
  if (status == 'Delivered') return 'ok';
  if (status == 'Cancelled' || status == 'Rejected') return 'bad';
  if (status == 'Awaiting Payment') return 'warn';
  return 'info';
}

class NetImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  const NetImage(this.url, {super.key, this.width, this.height, this.radius = 12, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(radius)),
      child: const Icon(Icons.restaurant, color: Color(0xFFCFD2DA)),
    );
    final u = url;
    if (u == null || u.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(u, width: width, height: height, fit: fit, errorBuilder: (_, __, ___) => placeholder),
    );
  }
}

class VegDot extends StatelessWidget {
  final bool veg;
  const VegDot(this.veg, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = veg ? kGreen : kRed;
    return Semantics(
      label: veg ? 'Vegetarian' : 'Non-vegetarian',
      child: Container(
        width: 14,
        height: 14,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(border: Border.all(color: c, width: 1.5), borderRadius: BorderRadius.circular(3)),
        child: DecoratedBox(decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView(this.message, {super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off, size: 44, color: Color(0xFFCFD2DA)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: kMuted)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ]),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyView({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 52, color: const Color(0xFFCFD2DA)),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: kMuted)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

class Section extends StatelessWidget {
  final String? title;
  final Widget child;
  const Section({super.key, this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Text(title!, style: const TextStyle(fontWeight: FontWeight.w700, color: kMuted, fontSize: 13)),
          const SizedBox(height: 10),
        ],
        child,
      ]),
    );
  }
}

class BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const BillRow(this.label, this.value, {super.key, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final s = TextStyle(fontSize: bold ? 17 : 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w400, color: bold ? kInk : kMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: s), Text(value, style: s)]),
    );
  }
}

/// Tab switching from anywhere in the app (0 Home, 1 Cart, 2 Orders, 3 Account).
class Nav {
  static final ValueNotifier<int> tab = ValueNotifier<int>(0);
}
