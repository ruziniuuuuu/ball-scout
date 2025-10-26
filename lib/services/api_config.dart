import 'package:flutter/foundation.dart';

class ApiConfig {
  static final String baseUrl = _resolveBaseUrl();

  static String _resolveBaseUrl() {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) {
      return override;
    }

    if (kIsWeb) {
      final origin = Uri.base;
      return Uri(
        scheme: origin.scheme.isEmpty ? 'http' : origin.scheme,
        host: origin.host.isEmpty ? 'localhost' : origin.host,
        port: origin.port == 0 ? 8080 : origin.port,
      ).toString();
    }

    return 'http://localhost:8080';
  }

  static String join(String relativePath) {
    return Uri.parse(baseUrl).resolve(relativePath).toString();
  }
}
