import 'package:flutter/foundation.dart';
import 'dart:io';

/// App configuration for different environments
abstract class AppConfig {
  String get apiBaseUrl;
  String get appName;
  bool get debugMode;
  int get requestTimeoutSeconds;
  int get maxRetries;
}

/// Development configuration
class DevConfig implements AppConfig {
  @override
  String get apiBaseUrl {
    // Detect platform and use appropriate localhost
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api/v1';
    } else if (Platform.isIOS) {
      return 'http://localhost:8000/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }

  @override
  String get appName => 'AquaFix (Dev)';

  @override
  bool get debugMode => true;

  @override
  int get requestTimeoutSeconds => 30;

  @override
  int get maxRetries => 3;
}

/// Staging configuration
class StagingConfig implements AppConfig {
  @override
  String get apiBaseUrl => 'https://staging-api.aquafix.example.com/api/v1';

  @override
  String get appName => 'AquaFix (Staging)';

  @override
  bool get debugMode => false;

  @override
  int get requestTimeoutSeconds => 30;

  @override
  int get maxRetries => 3;
}

/// Production configuration
class ProdConfig implements AppConfig {
  @override
  String get apiBaseUrl => 'https://api.aquafix.example.com/api/v1';

  @override
  String get appName => 'AquaFix';

  @override
  bool get debugMode => false;

  @override
  int get requestTimeoutSeconds => 30;

  @override
  int get maxRetries => 2;
}

/// Get configuration based on build mode
AppConfig getAppConfig() {
  if (kDebugMode) {
    return DevConfig();
  } else {
    // In production, use staging config for now
    // TODO: Switch to ProdConfig after domain is set up
    return StagingConfig();
  }
}
