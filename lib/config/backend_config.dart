// lib/config/backend_config.dart

/// Production (Render)
const String _prodBaseUrl = 'https://mooder.onrender.com';

/// Optional override when you want local dev.
/// Example:
/// flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8787
/// flutter run --dart-define=BACKEND_BASE_URL=http://YOUR_MAC_IP_ADDRESS:8787
const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: _prodBaseUrl,
);

Uri suggestionsUri() => Uri.parse('$backendBaseUrl/suggestions');
