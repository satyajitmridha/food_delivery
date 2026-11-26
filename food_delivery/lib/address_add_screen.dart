import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'config.dart';
import 'state.dart';
import 'ui.dart';

/// Add an address and drop a pin on the map. Delivery distance is measured from this pin.
class AddressAddScreen extends StatefulWidget {
  const AddressAddScreen({super.key});

  @override
  State<AddressAddScreen> createState() => _AddressAddScreenState();
}

class _AddressAddScreenState extends State<AddressAddScreen> {
  final MapController _map = MapController();
  LatLng? _pin;
  String _type = 'Home';
  final _line = TextEditingController();
  final _landmark = TextEditingController();
  final _pincode = TextEditingController();
  bool _locating = false;
  bool _saving = false;

  @override
  void dispose() {
    _map.dispose();
    _line.dispose();
    _landmark.dispose();
    _pincode.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final pos = await currentPosition();
      final p = LatLng(pos.latitude, pos.longitude);
      setState(() => _pin = p);
      _map.move(p, 17);
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final pin = _pin;
    if (pin == null) {
      snack(context, 'Tap the map to drop a pin on your door first.');
      return;
    }
    if (_line.text.trim().isEmpty) {
      snack(context, 'Enter the full address.');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(_pincode.text.trim())) {
      snack(context, 'Enter a valid 6-digit pincode.');
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await Api.post('addresses/add', {
        'type': _type,
        'address_line': _line.text.trim(),
        'landmark': _landmark.text.trim(),
        'pincode': _pincode.text.trim(),
        'latitude': pin.latitude,
        'longitude': pin.longitude,
      });
      final a = Map<String, dynamic>.from(r['address'] as Map);
      if (!mounted) return;
      context.read<AppState>().setLocation(DeliveryLocation(toD(a['latitude']), toD(a['longitude']), '${a['type']}: ${a['address_line']}', toI(a['id'])));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.read<AppState>().location;
    final start = loc != null ? LatLng(loc.lat, loc.lng) : const LatLng(22.5, 80);
    return Scaffold(
      appBar: AppBar(title: const Text('Add address')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Pin your door on the map', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _locating ? null : _locate,
          icon: _locating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
          label: const Text('Use my current location'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: start,
                initialZoom: loc != null ? 15 : 4,
                onTap: (tap, point) => setState(() => _pin = point),
              ),
              children: [
                TileLayer(urlTemplate: AppConfig.tileUrl, userAgentPackageName: AppConfig.userAgentPackage),
                if (_pin != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: _pin!,
                      width: 46,
                      height: 46,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_on, size: 46, color: kRed),
                    ),
                  ]),
                const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 16),
          child: Text(_pin == null ? 'Tap the map to drop the pin.' : 'Pin set. Tap elsewhere to move it.', style: const TextStyle(color: kMuted, fontSize: 12)),
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Home', label: Text('Home')),
            ButtonSegment(value: 'Work', label: Text('Work')),
            ButtonSegment(value: 'Other', label: Text('Other')),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 14),
        TextField(controller: _line, maxLines: 2, maxLength: 400, decoration: const InputDecoration(labelText: 'Full address', hintText: 'Flat, building, street, area')),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _landmark, maxLength: 150, decoration: const InputDecoration(labelText: 'Landmark (optional)'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _pincode, maxLength: 6, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pincode'))),
        ]),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save address'),
        ),
      ]),
    );
  }
}
