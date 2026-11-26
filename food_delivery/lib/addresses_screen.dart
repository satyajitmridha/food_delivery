import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'address_add_screen.dart';
import 'api.dart';
import 'state.dart';
import 'ui.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Api.get('addresses');
      if (mounted) setState(() => _list = maps(r['addresses']));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove this address?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.post('addresses/delete', {'id': toI(a['id'])});
      final s = context.read<AppState>();
      if (s.location?.addressId == toI(a['id'])) s.setLocation(DeliveryLocation(s.location!.lat, s.location!.lng, 'Current location', null));
      _load();
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = context.watch<AppState>().location?.addressId;
    Widget body;
    if (_loading && _list.isEmpty) {
      body = const Center(child: CircularProgressIndicator(color: kBrand));
    } else if (_error != null) {
      body = ErrorView(_error!, onRetry: _load);
    } else if (_list.isEmpty) {
      body = const EmptyView(icon: Icons.location_off_outlined, title: 'No saved addresses', subtitle: 'Add one with a map pin so we can check delivery distance.');
    } else {
      body = ListView.separated(
        itemCount: _list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final a = _list[i];
          final hasPin = a['latitude'] != null;
          return ListTile(
            leading: Icon(a['type'] == 'Work' ? Icons.work_outline : (a['type'] == 'Home' ? Icons.home_outlined : Icons.place_outlined)),
            title: Row(children: [
              Text('${a['type']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              if (current == toI(a['id'])) const Pill('Delivering here', kind: 'ok'),
              if (!hasPin) const Pill('No map pin', kind: 'bad'),
            ]),
            subtitle: Text('${a['address_line']}${(a['landmark'] ?? '').toString().isEmpty ? '' : ' \u00B7 near ${a['landmark']}'} \u00B7 ${a['pincode']}'),
            trailing: IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(a)),
            onTap: !hasPin
                ? null
                : () {
                    context.read<AppState>().setLocation(DeliveryLocation(toD(a['latitude']), toD(a['longitude']), '${a['type']}: ${a['address_line']}', toI(a['id'])));
                    snack(context, 'Delivering to this address.');
                  },
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My addresses')),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kBrand,
        foregroundColor: kInk,
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const AddressAddScreen()));
          if (added == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
    );
  }
}
