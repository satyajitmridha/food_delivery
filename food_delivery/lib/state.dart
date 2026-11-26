import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'ui.dart';

class CartLine {
  final int id;
  final String name;
  final double price;
  final bool veg;
  int qty;
  CartLine({required this.id, required this.name, required this.price, required this.veg, required this.qty});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price, 'veg': veg, 'qty': qty};
  factory CartLine.fromJson(Map<String, dynamic> j) =>
      CartLine(id: toI(j['id']), name: '${j['name']}', price: toD(j['price']), veg: j['veg'] == true, qty: toI(j['qty']));
}

class DeliveryLocation {
  final double lat;
  final double lng;
  final String label;
  final int? addressId;
  const DeliveryLocation(this.lat, this.lng, this.label, this.addressId);

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'label': label, 'addressId': addressId};
  factory DeliveryLocation.fromJson(Map<String, dynamic> j) =>
      DeliveryLocation(toD(j['lat']), toD(j['lng']), '${j['label']}', j['addressId'] == null ? null : toI(j['addressId']));
}

class AppState extends ChangeNotifier {
  bool ready = false;
  Map<String, dynamic>? user;
  DeliveryLocation? location;
  int? cartRestaurantId;
  String cartRestaurantName = '';
  final Map<int, CartLine> cart = {};
  String? _checkoutKey;
  SharedPreferences? _prefs;

  bool get loggedIn => user != null;
  int get cartCount => cart.values.fold(0, (a, l) => a + l.qty);
  double get cartSubtotal => cart.values.fold(0.0, (a, l) => a + l.price * l.qty);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    Api.onUnauthorized = _sessionExpired;
    Api.token = prefs.getString('token');
    _loadCart();
    _loadLocation();

    final cached = prefs.getString('user');
    if (Api.token != null && cached != null) {
      user = Map<String, dynamic>.from(jsonDecode(cached) as Map);
    }
    ready = true;
    notifyListeners();

    if (Api.token != null) {
      try {
        final r = await Api.get('me');
        user = Map<String, dynamic>.from(r['user'] as Map);
        await prefs.setString('user', jsonEncode(user));
        notifyListeners();
      } on ApiException {
        // Offline is fine: keep the cached login. A real 401 is handled by _sessionExpired.
      }
    }
  }

  void _sessionExpired() {
    user = null;
    _prefs?.remove('token');
    _prefs?.remove('user');
    notifyListeners();
  }

  Future<void> _startSession(Map<String, dynamic> r) async {
    Api.token = r['token'] as String;
    user = Map<String, dynamic>.from(r['user'] as Map);
    await _prefs?.setString('token', Api.token!);
    await _prefs?.setString('user', jsonEncode(user));
    notifyListeners();
  }

  String get _device => 'flutter-${defaultTargetPlatform.name}';

  Future<void> login(String identifier, String password) async {
    final r = await Api.post('auth/login', {'identifier': identifier, 'password': password, 'device': _device});
    await _startSession(r);
  }

  Future<void> register(String name, String email, String phone, String password) async {
    final r = await Api.post('auth/register', {'name': name, 'email': email, 'phone': phone, 'password': password, 'device': _device});
    await _startSession(r);
  }

  Future<void> logout() async {
    try {
      await Api.post('auth/logout');
    } on ApiException {
      // Logging out locally is enough.
    }
    Api.token = null;
    user = null;
    await _prefs?.remove('token');
    await _prefs?.remove('user');
    notifyListeners();
  }

  // ------------------------------------------------------------ location ----
  void setLocation(DeliveryLocation l) {
    location = l;
    _prefs?.setString('location', jsonEncode(l.toJson()));
    notifyListeners();
  }

  void _loadLocation() {
    final s = _prefs?.getString('location');
    if (s != null) {
      try {
        location = DeliveryLocation.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
      } catch (_) {
        location = null;
      }
    }
  }

  Future<void> useCurrentGps() async {
    final pos = await currentPosition();
    setLocation(DeliveryLocation(pos.latitude, pos.longitude, 'Current location', null));
  }

  // ---------------------------------------------------------------- cart ----
  bool canAdd(int restaurantId) => cart.isEmpty || cartRestaurantId == restaurantId;

  /// The caller must [clearCart] first when [canAdd] is false.
  void addItem({
    required int restaurantId,
    required String restaurantName,
    required int itemId,
    required String name,
    required double price,
    required bool veg,
  }) {
    if (!canAdd(restaurantId)) return;
    cartRestaurantId = restaurantId;
    cartRestaurantName = restaurantName;
    final line = cart[itemId];
    if (line != null) {
      if (line.qty < 20) line.qty++;
    } else {
      cart[itemId] = CartLine(id: itemId, name: name, price: price, veg: veg, qty: 1);
    }
    _saveCart();
    notifyListeners();
  }

  void decrement(int itemId) {
    final line = cart[itemId];
    if (line == null) return;
    line.qty--;
    if (line.qty <= 0) cart.remove(itemId);
    if (cart.isEmpty) {
      cartRestaurantId = null;
      cartRestaurantName = '';
    }
    _saveCart();
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    cartRestaurantId = null;
    cartRestaurantName = '';
    _saveCart();
    notifyListeners();
  }

  /// "Order again": the server returns the dishes still on sale; prices come from a fresh quote.
  Future<void> reorder(int orderId) async {
    final r = await Api.post('order/reorder', {'id': orderId});
    final items = maps(r['items']);
    if (items.isEmpty) throw ApiException('Those dishes are not available right now.');
    final q = await Api.post('quote', {'items': items});
    final rest = q['restaurant'] as Map?;
    cart.clear();
    for (final l in maps(q['lines'])) {
      cart[toI(l['id'])] = CartLine(id: toI(l['id']), name: '${l['name']}', price: toD(l['price']), veg: l['is_veg'] == true, qty: toI(l['qty']));
    }
    cartRestaurantId = rest == null ? null : toI(rest['id']);
    cartRestaurantName = rest == null ? '' : '${rest['name']}';
    _saveCart();
    notifyListeners();
  }

  /// One key per checkout attempt: a double tap or a retry can never create two orders.
  String checkoutKey() {
    return _checkoutKey ??= '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${Random.secure().nextInt(1 << 30).toRadixString(36)}';
  }

  void resetCheckoutKey() => _checkoutKey = null;

  void _saveCart() {
    _prefs?.setString('cart', jsonEncode({
      'rid': cartRestaurantId,
      'rname': cartRestaurantName,
      'lines': cart.values.map((l) => l.toJson()).toList(),
    }));
  }

  void _loadCart() {
    final s = _prefs?.getString('cart');
    if (s == null) return;
    try {
      final j = Map<String, dynamic>.from(jsonDecode(s) as Map);
      cartRestaurantId = j['rid'] == null ? null : toI(j['rid']);
      cartRestaurantName = '${j['rname'] ?? ''}';
      for (final l in maps(j['lines'])) {
        final line = CartLine.fromJson(l);
        cart[line.id] = line;
      }
    } catch (_) {
      cart.clear();
    }
  }
}

/// One GPS fix, with friendly errors for the usual problems (GPS off, permission refused).
Future<Position> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw ApiException('Turn on your phone\'s location (GPS) and try again.');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
    throw ApiException('Location permission is off. Allow it in Settings, or choose a saved address.');
  }
  // No version-specific parameters here: the accuracy/settings arguments changed names between geolocator
  // releases, so the 20-second limit is applied with a plain Future timeout instead.
  try {
    return await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 20));
  } on TimeoutException {
    throw ApiException('Could not get your location in time. Move to an open area and try again.');
  }
}
