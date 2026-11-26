import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'location_sheet.dart';
import 'login_screen.dart';
import 'order_screen.dart';
import 'pay_screen.dart';
import 'state.dart';
import 'ui.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic>? _q;
  bool _loading = false;
  bool _placing = false;
  String? _error;
  String _sig = '\u0000';
  String _method = '';
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _quote() async {
    final s = context.read<AppState>();
    if (s.cart.isEmpty) {
      setState(() {
        _q = null;
        _loading = false;
      });
      return;
    }
    final loc = s.location;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        'items': s.cart.values.map((l) => {'id': l.id, 'qty': l.qty}).toList(),
      };
      if (s.loggedIn && loc != null && loc.addressId != null) {
        body['address_id'] = loc.addressId;
      } else if (loc != null) {
        body['lat'] = loc.lat;
        body['lng'] = loc.lng;
      }
      final r = await Api.post('quote', body);
      if (!mounted) return;
      setState(() {
        _q = r;
        final methods = maps(r['methods']);
        if (!methods.any((m) => '${m['key']}' == _method)) {
          _method = methods.isEmpty ? '' : '${methods.first['key']}';
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _place() async {
    final s = context.read<AppState>();
    if (!s.loggedIn) {
      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (ok == true) _sig = '\u0000';
      if (mounted) setState(() {});
      return;
    }
    final loc = s.location;
    if (loc == null || loc.addressId == null) {
      snack(context, 'Choose a saved address to deliver to.');
      showLocationSheet(context);
      return;
    }
    setState(() => _placing = true);
    try {
      final r = await Api.post('order/create', {
        'items': s.cart.values.map((l) => {'id': l.id, 'qty': l.qty}).toList(),
        'address_id': loc.addressId,
        'method': _method,
        'note': _note.text.trim(),
        'client_key': s.checkoutKey(),
      });
      final id = toI(r['order_id']);
      final pay = r['next'] == 'pay';
      s.resetCheckoutKey();
      s.clearCart();
      _note.clear();
      Nav.tab.value = 2;
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pay ? PayScreen(orderId: id) : OrderScreen(orderId: id)));
    } on ApiException catch (e) {
      if (mounted) {
        snack(context, e.message);
        _sig = '\u0000';
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final loc = s.location;
    final sig = '${s.cart.entries.map((e) => '${e.key}x${e.value.qty}').join(',')}|${loc?.lat},${loc?.lng},${loc?.addressId}|${s.loggedIn}';
    if (sig != _sig) {
      _sig = sig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _quote();
      });
    }

    if (s.cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your cart')),
        body: EmptyView(
          icon: Icons.shopping_basket_outlined,
          title: 'Your cart is empty',
          subtitle: 'Add something tasty from a restaurant near you.',
          action: FilledButton(onPressed: () => Nav.tab.value = 0, child: const Text('Find food')),
        ),
      );
    }

    final q = _q;
    final errors = q == null ? <String>[] : (q['errors'] as List).map((e) => '$e').toList();
    final methods = q == null ? <Map<String, dynamic>>[] : maps(q['methods']);
    final unavailable = <int>{};
    if (q != null) {
      for (final l in maps(q['lines'])) {
        if (l['available'] != true) unavailable.add(toI(l['id']));
      }
    }
    final canPlace = q != null && q['ok'] == true && !_loading && !_placing && _method.isNotEmpty && s.loggedIn && loc?.addressId != null;
    final total = q == null ? s.cartSubtotal : toD(q['total']);

    return Scaffold(
      appBar: AppBar(title: const Text('Your cart')),
      backgroundColor: kBg,
      body: ListView(children: [
        Section(
          title: 'FROM ${s.cartRestaurantName.toUpperCase()}',
          child: Column(children: [
            for (final l in s.cart.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  VegDot(l.veg),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (unavailable.contains(l.id)) const Text('Sold out. Remove it to continue.', style: TextStyle(color: kRed, fontSize: 12)),
                    ]),
                  ),
                  Container(
                    decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(tooltip: 'Remove one', visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove, color: Colors.white, size: 18), onPressed: () => s.decrement(l.id)),
                      Text('${l.qty}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      IconButton(
                        tooltip: 'Add one',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add, color: Colors.white, size: 18),
                        onPressed: () => s.addItem(restaurantId: s.cartRestaurantId!, restaurantName: s.cartRestaurantName, itemId: l.id, name: l.name, price: l.price, veg: l.veg),
                      ),
                    ]),
                  ),
                  SizedBox(width: 64, child: Text(money(l.price * l.qty), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
                ]),
              ),
          ]),
        ),
        Section(
          title: 'DELIVER TO',
          child: !s.loggedIn
              ? Row(children: [
                  const Expanded(child: Text('Log in to choose an address and place your order.')),
                  FilledButton(onPressed: _place, child: const Text('Log in')),
                ])
              : InkWell(
                  onTap: () => showLocationSheet(context),
                  child: Row(children: [
                    const Icon(Icons.location_on, color: kBrand),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(loc?.label ?? 'No address chosen', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (loc != null && loc.addressId == null)
                          const Text('Pick one of your saved addresses to order.', style: TextStyle(color: kRed, fontSize: 12))
                        else if (q != null && q['distance_km'] != null)
                          Text('${toD(q['distance_km']).toStringAsFixed(1)} km from the restaurant', style: const TextStyle(color: kMuted, fontSize: 12)),
                      ]),
                    ),
                    const Text('Change', style: TextStyle(color: Color(0xFFB8500A), fontWeight: FontWeight.w700)),
                  ]),
                ),
        ),
        if (methods.isNotEmpty)
          Section(
            title: 'HOW WOULD YOU LIKE TO PAY?',
            child: Column(children: [
              for (final m in methods)
                InkWell(
                  onTap: () => setState(() => _method = '${m['key']}'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _method == '${m['key']}' ? kBrand : const Color(0xFFE9E9EB), width: 1.5),
                    ),
                    child: Row(children: [
                      Icon(_method == '${m['key']}' ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _method == '${m['key']}' ? kBrand : kMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${m['label']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${m['sub']}', style: const TextStyle(color: kMuted, fontSize: 12)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              TextField(controller: _note, maxLength: 200, decoration: const InputDecoration(labelText: 'Note for the restaurant (optional)')),
            ]),
          ),
        Section(
          title: 'BILL',
          child: _loading && q == null
              ? const Center(child: CircularProgressIndicator(color: kBrand))
              : _error != null
                  ? Text(_error!, style: const TextStyle(color: kRed))
                  : Column(children: [
                      BillRow('Items', money(q == null ? s.cartSubtotal : toD(q['subtotal']))),
                      BillRow('Delivery', q != null && q['distance_km'] != null ? money(toD(q['delivery_fee'])) : 'Choose an address'),
                      const Divider(),
                      BillRow('To pay', money(total), bold: true),
                      const Align(alignment: Alignment.centerLeft, child: Text('Prices include taxes.', style: TextStyle(color: kMuted, fontSize: 12))),
                    ]),
        ),
        if (errors.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFDF0F0), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Fix this to place your order', style: TextStyle(color: kRed, fontWeight: FontWeight.w800)),
              for (final e in errors) Padding(padding: const EdgeInsets.only(top: 4), child: Text('\u2022 $e', style: const TextStyle(color: kRed, fontSize: 13))),
            ]),
          ),
        const SizedBox(height: 12),
      ]),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 12)]),
        child: SafeArea(
          top: false,
          child: Row(children: [
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(money(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Text('Total', style: TextStyle(color: kMuted, fontSize: 12)),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: s.loggedIn ? (canPlace ? _place : null) : _place,
                child: _placing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(s.loggedIn ? 'Place order' : 'Log in to order'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
