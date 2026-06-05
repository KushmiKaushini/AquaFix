import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';

/// Provides the API service as a singleton
final apiServiceProvider = Provider<ApiService>((ref) {
  final config = ref.watch(appConfigProvider);
  return ApiService(
    baseUrl: config.apiBaseUrl,
    config: config,
  );
});

/// Provides the app configuration
final appConfigProvider = Provider<AppConfig>((ref) {
  return getAppConfig();
});
