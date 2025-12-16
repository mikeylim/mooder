// lib/config/backend_config.dart
import 'dart:io';

/// Local dev (your laptop/server)
/// - Android emulator: http://10.0.2.2 maps to your computer's localhost
/// - iOS simulator: http://localhost works
/// - Physical phone: use your laptop IP (only while dev on same Wi-Fi)
///
const String _devAndroid = 'http://10.0.2.2:8787';
const String _devIOS = 'http://localhost:8787';
const String _prod = 'https://mooder.onrender.com';

/// Production (Render)
const String _prodBaseUrl = 'https://mooder.onrender.com';

/// dart.vm.product is true in release builds (APK / App Store builds)
bool get _isProd => const bool.fromEnvironment('dart.vm.product');

String get backendBaseUrl {
  if (_isProd) return _prod;
  if (Platform.isAndroid) return _devAndroid;
  return _devIOS;
}
