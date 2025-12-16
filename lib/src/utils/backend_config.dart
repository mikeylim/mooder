// lib/utils/backend_config.dart
class BackendConfig {
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://127.0.0.1:8787', // local dev fallback
  );

  static Uri suggestionsUri() => Uri.parse('$baseUrl/suggestions');
}
