import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'address_add_screen.dart';
import 'api.dart';
import 'login_screen.dart';
import 'state.dart';
import 'ui.dart';

Future<void> showLocationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _LocationSheet(),
  );
}

class _LocationSheet extends StatefulWidget {
  const _LocationSheet();

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  List<Map<String, dynamic>> _addresses = [];
  bool _loading = false;
  bool _gps = false;

  @override
  void initState() {
    super.initState();
    if (context.read<AppState>().loggedIn) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Api.get('addresses');
      if (mounted) setState(() => _addresses = maps(r['addresses']));
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useGps() async {
    setState(() => _gps = true);
    try {
      await context.read<AppState>().useCurrentGps();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _gps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final current = state.location?.addressId;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: ListView(shrinkWrap: true, children: [
          ListTile(
            leading: _gps ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location, color: kBrand),
            title: const Text('Use my current location', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: _gps ? null : _useGps,
          ),
          const Divider(height: 1),
          if (!state.loggedIn)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Log in to use your saved addresses'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            )
          else ...[
            if (_loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            for (final a in _addresses)
              if (a['latitude'] != null)
                ListTile(
                  leading: Icon(a['type'] == 'Work' ? Icons.work_outline : (a['type'] == 'Home' ? Icons.home_outlined : Icons.place_outlined)),
                  title: Text('${a['type']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${a['address_line']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: current == toI(a['id']) ? const Icon(Icons.check_circle, color: kBrand) : null,
                  onTap: () {
                    state.setLocation(DeliveryLocation(toD(a['latitude']), toD(a['longitude']), '${a['type']}: ${a['address_line']}', toI(a['id'])));
                    Navigator.of(context).pop();
                  },
                ),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Add a new address'),
              onTap: () async {
                final nav = Navigator.of(context);
                nav.pop();
                await nav.push(MaterialPageRoute(builder: (_) => const AddressAddScreen()));
              },
            ),
          ],
        ]),
      ),
    );
  }
}
