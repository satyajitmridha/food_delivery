import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'location_sheet.dart';
import 'restaurant_screen.dart';
import 'state.dart';
import 'ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _cats = [];
  List<Map<String, dynamic>> _list = [];
  String _category = '';
  String _loadedFor = '\u0000';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loc = context.read<AppState>().location;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Api.get('home', query: {
        if (loc != null) 'lat': '${loc.lat}',
        if (loc != null) 'lng': '${loc.lng}',
        'q': _search.text.trim(),
        'category': _category,
      });
      if (!mounted) return;
      setState(() {
        _cats = maps(r['categories']);
        _list = maps(r['restaurants']);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<AppState>().location;
    final key = loc == null ? '' : '${loc.lat},${loc.lng}';
    if (key != _loadedFor) {
      _loadedFor = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: InkWell(
          onTap: () => showLocationSheet(context),
          child: Row(children: [
            const Icon(Icons.location_on, color: kBrand),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(loc?.label ?? 'Set delivery location',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Text('Tap to change', style: TextStyle(fontSize: 11, color: kMuted)),
              ]),
            ),
            const Icon(Icons.keyboard_arrow_down),
          ]),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Search restaurants or dishes',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: kBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _load();
                        },
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_cats.isNotEmpty)
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: _cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final c = _cats[i];
                  final on = _category == '${c['name']}';
                  return InkWell(
                    borderRadius: BorderRadius.circular(40),
                    onTap: () {
                      setState(() => _category = on ? '' : '${c['name']}');
                      _load();
                    },
                    child: SizedBox(
                      width: 72,
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? kBrand : Colors.transparent, width: 2)),
                          child: ClipOval(child: NetImage(c['image_url'] as String?, width: 60, height: 60, radius: 30)),
                        ),
                        const SizedBox(height: 4),
                        Text('${c['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kMuted)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 1, thickness: 6, color: kBg),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text('Restaurants near you', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          ..._body(loc),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  List<Widget> _body(DeliveryLocation? loc) {
    if (_loading && _list.isEmpty) {
      return const [Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: kBrand)))];
    }
    if (_error != null) return [SizedBox(height: 300, child: ErrorView(_error!, onRetry: _load))];
    if (loc == null) {
      return [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: const Color(0xFFFFF3E8), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            const Text('Where should we deliver?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('We only show restaurants that can reach you.', style: TextStyle(color: kMuted)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => showLocationSheet(context),
              icon: const Icon(Icons.my_location),
              label: const Text('Set my location'),
            ),
          ]),
        ),
      ];
    }
    if (_list.isEmpty) {
      return [
        const SizedBox(
          height: 260,
          child: EmptyView(
            icon: Icons.storefront_outlined,
            title: 'No restaurants deliver here',
            subtitle: 'Try a different address or clear your search.',
          ),
        ),
      ];
    }
    return [for (final r in _list) _RestaurantCard(r)];
  }
}

class _RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> r;
  const _RestaurantCard(this.r);

  static const _grey = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final open = r['open'] == true;
    final label = '${r['status_label'] ?? ''}';
    Widget img = NetImage(r['image_url'] as String?, width: 100, height: 100);
    if (!open) img = Opacity(opacity: 0.7, child: ColorFiltered(colorFilter: _grey, child: img));
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RestaurantScreen(id: toI(r['id'])))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          img,
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFF1F9D55), borderRadius: BorderRadius.circular(4)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star, size: 12, color: Colors.white),
                    const SizedBox(width: 2),
                    Text('${r['rating']}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
                Text('${r['delivery_time']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${r['distance_km']} km', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
              const SizedBox(height: 3),
              Text('${r['cuisine']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 13)),
              const SizedBox(height: 3),
              Text(open ? (label.isEmpty ? 'Open now' : label) : label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: open ? kGreen : kRed)),
            ]),
          ),
        ]),
      ),
    );
  }
}
