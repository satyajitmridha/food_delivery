/// Change [apiBase] to your site, or pass it at build time:
///   flutter run --dart-define=API_BASE=https://yourdomain.com/api/v1/index.php
class AppConfig {
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://YOUR-DOMAIN.com/api/v1/index.php',
  );
  static const String appName = 'Foodie';

  /// Free OpenStreetMap tiles are fine for testing. Use a paid tile provider for real traffic.
  static const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Must match your Android applicationId / iOS bundle id (OpenStreetMap asks apps to identify themselves).
  static const String userAgentPackage = 'com.example.food_customer';
}
