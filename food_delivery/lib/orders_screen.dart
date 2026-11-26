import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'login_screen.dart';
import 'order_screen.dart';
import 'pay_screen.dart';
import 'state.dart';
import 'ui.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Nav.tab.addListener(_onTab);
  }

  @override
  void dispose() {
    Nav.tab.removeListener(_onTab);
    super.dispose();
  }

  // Refresh every time the Orders tab is opened.
  void _onTab() {
    if (Nav.tab.value == 2 && mounted && context.read<AppState>().loggedIn) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Api.get('orders');
      if (mounted) setState(() => _orders = maps(r['orders']));
    } on ApiException catch (e) {
      if (mounted && !e.unauthorized) setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadedOnce = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.loggedIn && !_loadedOnce && !_loading && Nav.tab.value == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    if (!s.loggedIn && _orders.isNotEmpty) _orders = [];

    Widget body;
    if (!s.loggedIn) {
      body = const LoginPrompt(title: 'See your orders', subtitle: 'Log in to track orders and order again.');
    } else if (_loading && _orders.isEmpty) {
      body = const Center(child: CircularProgressIndicator(color: kBrand));
    } else if (_error != null && _orders.isEmpty) {
      body = ErrorView(_error!, onRetry: _load);
    } else if (_orders.isEmpty) {
      body = const EmptyView(icon: Icons.receipt_long_outlined, title: 'No orders yet', subtitle: 'Your orders will show up here.');
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _orders.length,
          itemBuilder: (_, i) => _tile(_orders[i]),
        ),
      );
    }
    return Scaffold(appBar: AppBar(title: const Text('Your orders')), backgroundColor: kBg, body: body);
  }

  Widget _tile(Map<String, dynamic> o) {
    final status = '${o['status']}';
    final awaiting = status == 'Awaiting Payment';
    final done = status == 'Delivered' || status == 'Cancelled' || status == 'Rejected';
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE9E9EB))),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final id = toI(o['id']);
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => awaiting ? PayScreen(orderId: id) : OrderScreen(orderId: id)));
          if (mounted) _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${o['restaurant']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('${o['ref']} \u00B7 ${o['created_at']}', style: const TextStyle(color: kMuted, fontSize: 12)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(money(toD(o['total'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Pill('${o['status_label']}', kind: statusKind(status)),
              ]),
            ]),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8)),
              child: Text('${o['summary']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 13)),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              paymentPill('${o['payment_status']}'),
              Text(awaiting ? 'Complete payment' : (done ? 'View' : 'Track order'),
                  style: const TextStyle(color: Color(0xFFB8500A), fontWeight: FontWeight.w800)),
            ]),
          ]),
        ),
      ),
    );
  }
}
