import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'order_screen.dart';
import 'ui.dart';

/// Pay a UPI order: open an installed UPI app, then confirm with the 12-digit UTR.
class PayScreen extends StatefulWidget {
  final int orderId;
  const PayScreen({super.key, required this.orderId});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _info;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  int _left = 0;
  Timer? _timer;
  bool _wentToUpiApp = false;
  final _utr = TextEditingController();
  final _utrFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _utr.dispose();
    _utrFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _wentToUpiApp = true;
    if (state == AppLifecycleState.resumed && _wentToUpiApp) {
      _wentToUpiApp = false;
      snack(context, 'Enter the UTR from your UPI app to finish.');
      _utrFocus.requestFocus();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Api.get('pay/info', query: {'id': '${widget.orderId}'});
      if (!mounted) return;
      if (r['awaiting'] != true) {
        _goToOrder();
        return;
      }
      setState(() {
        _info = r;
        _left = toI(r['seconds_left']);
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_left <= 1) {
          _timer?.cancel();
          _load(); // the server has cancelled it by now: this sends us to the order screen
        } else {
          setState(() => _left--);
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToOrder() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrderScreen(orderId: widget.orderId)));
  }

  Future<void> _openUpi(String link) async {
    try {
      final ok = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      if (!ok && mounted) snack(context, 'No UPI app found for this option. Try another app.');
    } catch (_) {
      if (mounted) snack(context, 'No UPI app found for this option. Try another app.');
    }
  }

  Future<void> _submitUtr() async {
    final utr = _utr.text.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{12}$').hasMatch(utr)) {
      snack(context, 'Enter the 12-digit UTR (reference number) from your UPI app.');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Api.post('pay/utr', {'id': widget.orderId, 'utr': utr});
      if (!mounted) return;
      snack(context, '${r['message']}');
      _goToOrder();
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String text) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _payCash() async {
    if (!await _confirm('Pay cash instead?', 'You will pay the rider when the food arrives.')) return;
    setState(() => _busy = true);
    try {
      await Api.post('pay/cod', {'id': widget.orderId});
      if (mounted) _goToOrder();
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (!await _confirm('Cancel this order?', 'It has not been paid yet.')) return;
    setState(() => _busy = true);
    try {
      await Api.post('order/cancel', {'id': widget.orderId});
      if (mounted) _goToOrder();
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Scaffold(
      appBar: AppBar(title: Text(info == null ? 'Pay' : 'Pay ${info['ref']}')),
      body: _loading && info == null
          ? const Center(child: CircularProgressIndicator(color: kBrand))
          : _error != null
              ? ErrorView(_error!, onRetry: _load)
              : _body(info!),
    );
  }

  Widget _body(Map<String, dynamic> info) {
    final links = Map<String, dynamic>.from(info['links'] as Map);
    final mm = '${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}';
    final ios = Platform.isIOS;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kInk, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text('${info['restaurant']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          Text(money(toD(info['amount'])), style: const TextStyle(color: kBrand, fontSize: 24, fontWeight: FontWeight.w800)),
        ]),
      ),
      const SizedBox(height: 8),
      Center(child: Text('Complete payment within $mm or the order is cancelled.', style: const TextStyle(color: kMuted, fontSize: 13))),
      const SizedBox(height: 16),
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE9E9EB))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('1. Pay with your UPI app', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Tap an app. It opens with the amount already filled in. Pay, then come back here.', style: TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(height: 12),
            if (!ios)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openUpi('${links['generic']}'),
                  icon: const Icon(Icons.phone_android),
                  label: const Text('Choose a UPI app'),
                ),
              ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _openUpi('${links['gpay']}'), child: const Text('Google Pay'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => _openUpi('${links['phonepe']}'), child: const Text('PhonePe'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => _openUpi('${links['paytm']}'), child: const Text('Paytm'))),
            ]),
            const SizedBox(height: 12),
            Text('Paying to: ${info['upi_id']}', style: const TextStyle(color: kMuted, fontSize: 12)),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE9E9EB))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('2. Confirm your payment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Your UPI app shows a 12-digit reference number (UTR or transaction ID) after paying. Enter it so the restaurant can match your payment.',
                style: TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: _utr,
              focusNode: _utrFocus,
              keyboardType: TextInputType.number,
              maxLength: 14,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
              decoration: const InputDecoration(labelText: 'UTR / reference number', hintText: '12 digits'),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submitUtr,
                child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('I have paid'),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      if (info['cod_enabled'] == true)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton.icon(onPressed: _busy ? null : _payCash, icon: const Icon(Icons.payments_outlined), label: const Text('Pay cash on delivery instead')),
        ),
      OutlinedButton(
        style: OutlinedButton.styleFrom(foregroundColor: kRed),
        onPressed: _busy ? null : _cancel,
        child: const Text('Cancel order'),
      ),
    ]);
  }
}
