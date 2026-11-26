import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'state.dart';
import 'ui.dart';

class RestaurantScreen extends StatefulWidget {
  final int id;
  const RestaurantScreen({super.key, required this.id});

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  Map<String, dynamic>? _res;
  List<Map<String, dynamic>> _menu = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _canReview = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loc = context.read<AppState>().location;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Api.get('restaurant', query: {
        'id': '${widget.id}',
        if (loc != null) 'lat': '${loc.lat}',
        if (loc != null) 'lng': '${loc.lng}',
      });
      if (!mounted) return;
      setState(() {
        _res = Map<String, dynamic>.from(r['restaurant'] as Map);
        _menu = maps(r['menu']);
        _reviews = maps(r['reviews']);
        _canReview = r['can_review'] == true;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(Map<String, dynamic> item) async {
    final s = context.read<AppState>();
    final rid = toI(_res!['id']);
    if (!s.canAdd(rid)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Start a new cart?'),
          content: Text('Your cart has dishes from ${s.cartRestaurantName}. Adding this one will clear it.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes, start new cart')),
          ],
        ),
      );
      if (ok != true) return;
      s.clearCart();
    }
    s.addItem(
      restaurantId: rid,
      restaurantName: '${_res!['name']}',
      itemId: toI(item['id']),
      name: '${item['name']}',
      price: toD(item['price']),
      veg: item['is_veg'] == true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final res = _res;
    return Scaffold(
      appBar: AppBar(title: Text(res == null ? '' : '${res['name']}')),
      body: _loading && res == null
          ? const Center(child: CircularProgressIndicator(color: kBrand))
          : _error != null
              ? ErrorView(_error!, onRetry: _load)
              : _content(state, res!),
      bottomNavigationBar: state.cartCount == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Material(
                  color: kGreen,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Nav.tab.value = 1;
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('${state.cartCount} ${state.cartCount == 1 ? 'item' : 'items'}  \u2022  ${money(state.cartSubtotal)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        const Text('View cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _content(AppState state, Map<String, dynamic> res) {
    final open = res['open'] == true;
    final out = res['out_of_range'] == true;
    final canOrder = open && !out;
    return DefaultTabController(
      length: 2,
      child: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${res['name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${res['cuisine']}${(res['address'] ?? '').toString().isEmpty ? '' : ' \u00B7 ${res['address']}'}',
                    style: const TextStyle(color: kMuted, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFF1F9D55), borderRadius: BorderRadius.circular(4)),
                    child: Text('\u2605 ${res['rating']}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  Text('${res['delivery_time']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (res['distance_km'] != null) Text('${toD(res['distance_km']).toStringAsFixed(1)} km away', style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                Text(open ? 'Open now${'${res['status_label']}'.isEmpty ? '' : ' \u00B7 ${res['status_label']}'}' : '${res['status_label']}',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: open ? kGreen : kRed)),
                const SizedBox(height: 4),
                Text('Today: ${res['hours_today']} \u00B7 Delivers up to ${toD(res['radius_km']).toStringAsFixed(toD(res['radius_km']) % 1 == 0 ? 0 : 1)} km',
                    style: const TextStyle(color: kMuted, fontSize: 12)),
                if (out)
                  _notice('This restaurant is too far from your location. You can look at the menu, but ordering is switched off.', true)
                else if (!open)
                  _notice('This restaurant is closed right now. You can browse the menu.', false)
                else if (state.location == null)
                  _notice('Set your delivery location on the Home tab so we can check that this restaurant delivers to you.', false),
              ]),
            ),
          ),
          const SliverToBoxAdapter(
            child: TabBar(tabs: [Tab(text: 'Menu'), Tab(text: 'Reviews')], labelColor: kInk, indicatorColor: kBrand),
          ),
        ],
        body: TabBarView(children: [_menuList(state, canOrder), _reviewList()]),
      ),
    );
  }

  Widget _notice(String text, bool bad) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        decoration: BoxDecoration(color: bad ? const Color(0xFFFDF0F0) : const Color(0xFFFFF7E0), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(fontSize: 13, color: bad ? kRed : const Color(0xFF7A5200))),
      );

  Widget _menuList(AppState state, bool canOrder) {
    if (_menu.isEmpty) return const EmptyView(icon: Icons.restaurant_menu, title: 'The menu is empty right now');
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _menu.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final m = _menu[i];
        final id = toI(m['id']);
        final avail = m['is_available'] == true;
        final qty = state.cart[id]?.qty ?? 0;
        Widget control;
        if (!avail) {
          control = const Pill('Sold out', kind: 'bad');
        } else if (!canOrder) {
          control = const OutlinedButton(onPressed: null, child: Text('ADD'));
        } else if (qty > 0) {
          control = Container(
            decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'Remove one', visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove, color: Colors.white), onPressed: () => state.decrement(id)),
              Text('$qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              IconButton(tooltip: 'Add one', visualDensity: VisualDensity.compact, icon: const Icon(Icons.add, color: Colors.white), onPressed: () => _add(m)),
            ]),
          );
        } else {
          control = OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: kGreen, minimumSize: const Size(78, 40)),
            onPressed: () => _add(m),
            child: const Text('ADD'),
          );
        }
        return Opacity(
          opacity: avail ? 1 : 0.6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  VegDot(m['is_veg'] == true),
                  const SizedBox(height: 4),
                  Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(money(toD(m['price'])), style: const TextStyle(fontWeight: FontWeight.w600)),
                  if ((m['description'] ?? '').toString().isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text('${m['description']}', style: const TextStyle(color: kMuted, fontSize: 13))),
                ]),
              ),
              const SizedBox(width: 12),
              control,
            ]),
          ),
        );
      },
    );
  }

  Widget _reviewList() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (_canReview)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: FilledButton(
            onPressed: () async {
              final done = await showReviewDialog(context, widget.id);
              if (done == true) _load();
            },
            child: const Text('Write a review'),
          ),
        )
      else
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text('You can review a restaurant after one of your orders from them is delivered.', style: TextStyle(color: kMuted, fontSize: 13)),
        ),
      if (_reviews.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No reviews yet.', style: TextStyle(color: kMuted)))),
      for (final r in _reviews)
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE9E9EB))),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('\u2605 ${r['rating']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
              Text('${r['date']}', style: const TextStyle(color: kMuted, fontSize: 12)),
              const SizedBox(height: 6),
              Text('${r['comment']}'),
            ]),
          ),
        ),
    ]);
  }
}

/// Star rating + comment. Returns true when a review was saved.
Future<bool?> showReviewDialog(BuildContext context, int restaurantId) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _ReviewDialog(restaurantId: restaurantId),
  );
}

class _ReviewDialog extends StatefulWidget {
  final int restaurantId;
  const _ReviewDialog({required this.restaurantId});

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int _stars = 0;
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await Api.post('review', {'restaurant_id': widget.restaurantId, 'rating': _stars, 'comment': _text.text.trim()});
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate your order'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              tooltip: '$i stars',
              icon: Icon(i <= _stars ? Icons.star : Icons.star_border, color: const Color(0xFFF5A300), size: 32),
              onPressed: () => setState(() => _stars = i),
            ),
        ]),
        TextField(controller: _text, maxLines: 3, maxLength: 500, decoration: const InputDecoration(hintText: 'How was it?')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _busy || _stars == 0 ? null : _send, child: const Text('Post')),
      ],
    );
  }
}
