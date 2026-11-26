import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'config.dart';
import 'pay_screen.dart';
import 'restaurant_screen.dart';
import 'state.dart';
import 'ui.dart';

/// Order status, delivery code and the live rider map.
class OrderScreen extends StatefulWidget {
  final int orderId;
  const OrderScreen({super.key, required this.orderId});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _o;
  Map<String, dynamic>? _t;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Timer? _timer;
  final MapController _map = MapController();
  bool _mapReady = false;
  bool _fitted = false;

  static const _steps = ['Placed', 'Preparing', 'Ready', 'On the way', 'Delivered'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _map.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _poll();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  bool get _ended {
    final st = '${_o?['status']}';
    return st == 'Delivered' || st == 'Cancelled' || st == 'Rejected';
  }

  Future<void> _load() async {
    try {
      final r = await Api.get('order', query: {'id': '${widget.orderId}'});
      if (!mounted) return;
      final o = Map<String, dynamic>.from(r['order'] as Map);
      if (o['status'] == 'Awaiting Payment') {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PayScreen(orderId: widget.orderId)));
        return;
      }
      setState(() {
        _o = o;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && _o == null) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _poll() async {
    if (_o == null || _ended || !mounted) return;
    try {
      final t = await Api.get('track', query: {'id': '${widget.orderId}'});
      if (!mounted) return;
      if (t['status'] != _o!['status']) {
        _fitted = false;
        await _load();
      }
      if (!mounted) return;
      setState(() => _t = t);
      final p = _riderPoint();
      if (p != null) _followRider(p);
    } on ApiException {
      // A missed poll is harmless; the next one will catch up.
    }
  }

  LatLng? _riderPoint() {
    final rider = _t?['rider'];
    if (rider is Map && rider['lat'] != null && rider['lng'] != null) {
      return LatLng(toD(rider['lat']), toD(rider['lng']));
    }
    return null;
  }

  LatLng? get _home {
    final o = _o;
    if (o == null || o['delivery_lat'] == null || o['delivery_lng'] == null) return null;
    return LatLng(toD(o['delivery_lat']), toD(o['delivery_lng']));
  }

  LatLng? get _shop {
    final r = _o?['restaurant'];
    if (r is Map && r['lat'] != null && r['lng'] != null) return LatLng(toD(r['lat']), toD(r['lng']));
    return null;
  }

  void _followRider(LatLng p) {
    final home = _home;
    if (!_mapReady || home == null) return;
    if (!_fitted) {
      _map.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints([p, home]), padding: const EdgeInsets.all(60), maxZoom: 16));
      _fitted = true;
    } else if (!_map.camera.visibleBounds.contains(p)) {
      _map.move(p, _map.camera.zoom);
    }
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final r = await Api.post('order/cancel', {'id': widget.orderId});
      if (mounted) snack(context, '${r['message']}');
      await _load();
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reorder() async {
    final s = context.read<AppState>();
    setState(() => _busy = true);
    try {
      await s.reorder(widget.orderId);
      if (!mounted) return;
      Nav.tab.value = 1;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _o;
    return Scaffold(
      appBar: AppBar(title: Text(o == null ? 'Order' : '${o['ref']}')),
      backgroundColor: kBg,
      body: _loading && o == null
          ? const Center(child: CircularProgressIndicator(color: kBrand))
          : _error != null
              ? ErrorView(_error!, onRetry: _load)
              : RefreshIndicator(onRefresh: () async { await _load(); await _poll(); }, child: _content(o!)),
    );
  }

  Widget _content(Map<String, dynamic> o) {
    final status = '${o['status']}';
    final ended = status == 'Cancelled' || status == 'Rejected';
    final live = status == 'Out for Delivery' && _home != null && _shop != null;
    final rider = o['rider'] is Map ? Map<String, dynamic>.from(o['rider'] as Map) : null;
    final items = maps(o['items']);
    final eta = _t?['eta_min'];
    final stale = _t?['stale'] == true;
    final restaurant = Map<String, dynamic>.from(o['restaurant'] as Map);

    return ListView(children: [
      Section(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${o['status_label']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                Text('${restaurant['name']} \u00B7 ${o['created_at']}', style: const TextStyle(color: kMuted, fontSize: 13)),
              ]),
            ),
            paymentPill('${o['payment_status']}'),
          ]),
          if (!ended && status != 'Delivered' && eta != null) ...[
            const SizedBox(height: 8),
            Text(
              'Arriving around ${TimeOfDay.fromDateTime(DateTime.now().add(Duration(minutes: toI(eta)))).format(context)} (about ${toI(eta)} min)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ]),
      ),
      if (ended)
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFDF0F0), borderRadius: BorderRadius.circular(10)),
          child: Text(
            '${status == 'Rejected' ? 'The restaurant could not take this order.' : 'This order was cancelled.'}'
            '${(o['cancel_reason'] ?? '').toString().isEmpty ? '' : '\n${o['cancel_reason']}'}'
            '${o['payment_status'] == 'Refund Due' ? '\nYour payment will be refunded by the restaurant.' : ''}',
            style: const TextStyle(color: kRed, fontWeight: FontWeight.w600),
          ),
        )
      else
        Section(child: _stepper(toI(o['step']), status == 'Delivered')),
      if (o['otp'] != null)
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFFF3E8), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            const Text('Give this code to your rider when the food arrives', style: TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(height: 4),
            Semantics(label: 'Delivery code ${o['otp']}', child: Text('${o['otp']}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 10))),
          ]),
        ),
      if (live) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            Icon(Icons.circle, size: 10, color: stale ? const Color(0xFFB7791F) : kGreen),
            const SizedBox(width: 6),
            Text(
              _riderPoint() == null
                  ? 'Waiting for your rider\'s location...'
                  : stale
                      ? 'Rider location is updating...'
                      : 'Live${_t?['km_left'] != null ? ' \u00B7 ${toD(_t!['km_left']).toStringAsFixed(1)} km away' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ]),
        ),
        _mapView(),
      ] else if (!ended && status != 'Delivered')
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFEAF1FF), borderRadius: BorderRadius.circular(10)),
          child: const Text('You will see your rider on a live map as soon as they pick up your order.', style: TextStyle(color: Color(0xFF1D4ED8))),
        ),
      if (rider != null)
        Section(
          child: Row(children: [
            const CircleAvatar(backgroundColor: kBg, child: Icon(Icons.two_wheeler, color: kInk)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${rider['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const Text('Your delivery rider', style: TextStyle(color: kMuted, fontSize: 12)),
              ]),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(80, 40)),
              onPressed: () => _call('${rider['phone']}'),
              icon: const Icon(Icons.call, size: 18),
              label: const Text('Call'),
            ),
          ]),
        ),
      Section(
        title: 'ORDER DETAILS',
        child: Column(children: [
          for (final it in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text('${it['qty']} \u00D7 ${it['name']}')),
                Text(money(toD(it['price']) * toI(it['qty']))),
              ]),
            ),
          const Divider(),
          if (toD(o['subtotal']) > 0) ...[
            BillRow('Items', money(toD(o['subtotal']))),
            BillRow('Delivery', money(toD(o['delivery_fee']))),
          ],
          BillRow('Total', money(toD(o['total'])), bold: true),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: Text('Deliver to: ${o['address']}', style: const TextStyle(color: kMuted, fontSize: 12))),
          if ((o['payment_ref'] ?? '').toString().isNotEmpty)
            Align(alignment: Alignment.centerLeft, child: Text('Payment reference: ${o['payment_ref']}', style: const TextStyle(color: kMuted, fontSize: 12))),
        ]),
      ),
      Section(
        child: Column(children: [
          if (status == 'Delivered')
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => showReviewDialog(context, toI(restaurant['id'])),
                child: const Text('Rate this restaurant'),
              ),
            ),
          if (status == 'Delivered' || ended)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _busy ? null : _reorder, child: const Text('Order again'))),
            ),
          if (o['can_cancel'] == true)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: kRed),
                onPressed: _busy ? null : _cancel,
                child: const Text('Cancel order'),
              ),
            ),
          if (o['can_cancel'] == true)
            const Padding(padding: EdgeInsets.only(top: 6), child: Text('You can cancel until the restaurant accepts your order.', style: TextStyle(color: kMuted, fontSize: 12))),
          if (!ended && status != 'Delivered' && o['can_cancel'] != true && (restaurant['phone'] ?? '').toString().isNotEmpty)
            TextButton.icon(
              onPressed: () => _call('${restaurant['phone']}'),
              icon: const Icon(Icons.call),
              label: Text('Need to change something? Call ${restaurant['name']}'),
            ),
        ]),
      ),
      const SizedBox(height: 24),
    ]);
  }

  Widget _stepper(int idx, bool delivered) {
    return Row(children: [
      for (var i = 0; i < _steps.length; i++)
        Expanded(
          child: Column(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: delivered || i < idx ? kGreen : Colors.white,
                border: Border.all(color: delivered || i < idx ? kGreen : (i == idx ? kBrand : const Color(0xFFCFD2DA)), width: 3),
              ),
              child: delivered || i < idx ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(height: 6),
            Text(_steps[i],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: i == idx ? FontWeight.w800 : FontWeight.w600, color: i == idx ? const Color(0xFFB8500A) : kMuted)),
          ]),
        ),
    ]);
  }

  Widget _mapView() {
    final home = _home!;
    final shop = _shop!;
    final rider = _riderPoint();
    final trail = <LatLng>[];
    final raw = _t?['trail'];
    if (raw is List) {
      for (final p in raw) {
        if (p is List && p.length == 2) trail.add(LatLng(toD(p[0]), toD(p[1])));
      }
    }
    Marker pin(LatLng p, IconData icon, Color c, double size) => Marker(
          point: p,
          width: size,
          height: size,
          child: Container(
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: c, width: 3)),
            child: Icon(icon, size: size * 0.55, color: c),
          ),
        );
    return Container(
      height: 320,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(bounds: LatLngBounds(shop, home), padding: const EdgeInsets.all(60)),
            onMapReady: () {
              _mapReady = true;
              final p = _riderPoint();
              if (p != null) _followRider(p);
            },
          ),
          children: [
            TileLayer(urlTemplate: AppConfig.tileUrl, userAgentPackageName: AppConfig.userAgentPackage),
            if (trail.length > 1) PolylineLayer(polylines: [Polyline(points: trail, strokeWidth: 4, color: kGreen)]),
            if (rider != null) PolylineLayer(polylines: [Polyline(points: [rider, home], strokeWidth: 2, color: kMuted)]),
            MarkerLayer(markers: [
              pin(shop, Icons.storefront, const Color(0xFF2563EB), 36),
              pin(home, Icons.home, kBrand, 36),
              if (rider != null) pin(rider, Icons.two_wheeler, kGreen, 44),
            ]),
            const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
          ],
        ),
      ),
    );
  }
}
