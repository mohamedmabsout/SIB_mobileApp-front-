// lib/config/app_config.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class AppConfig {
  final String baseUrl;

  // Private constructor
  AppConfig._internal({required this.baseUrl});

  // Static variable to hold the single instance (Singleton)
  static AppConfig? _instance;

  // Public factory constructor or static getter to access the instance
  static AppConfig get instance {
    if (_instance == null) {
      throw Exception("AppConfig not loaded. Call AppConfig.load() before accessing instance.");
    }
    return _instance!;
  }

  // Asynchronous method to load the configuration from the asset file
  static Future<void> load(String environment) async {
    // Prevent reloading if already loaded
    if (_instance != null) {
      print("AppConfig already loaded.");
      return;
    }

    // Determine which config file to load based on the environment string
    String configPath;
    switch (environment.toLowerCase()) {
      case 'prod':
      case 'production':
      // If you create a prod config later:
      // configPath = 'lib/config/prod_config.json';
        print("WARNING: Production config not implemented, falling back to dev.");
        configPath = 'lib/config/dev_config.json'; // Fallback for now
        break;
      case 'dev':
      case 'development':
      default: // Default to development
        configPath = 'lib/config/dev_config.json';
        break;
    }

    try {
      print("Loading configuration from: $configPath");
      // Load the JSON file from assets
      final String configString = await rootBundle.loadString(configPath);
      // Decode the JSON string into a Map
      final Map<String, dynamic> jsonMap = json.decode(configString);

      // Create the singleton instance
      _instance = AppConfig._internal(
        baseUrl: jsonMap['baseUrl'] as String? ?? _getDefaultBaseUrl(), // Use default if null
      );

      print('Configuration loaded for environment: $environment');
      print('Base URL set to: ${_instance!.baseUrl}');

    } catch (e) {
      print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      print('!!! ERROR LOADING CONFIG FILE: $configPath !!!');
      print('!!! Error: $e');
      print('!!! Falling back to default Base URL.');
      print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      // Fallback to a default URL in case of error
      _instance = AppConfig._internal(baseUrl: _getDefaultBaseUrl());
    }
  }

  // Helper function to get a default base URL (e.g., for emulator)
  static String _getDefaultBaseUrl() {
    // Basic platform check (you might need 'dart:io' Platform.isAndroid/isIOS
    // or kIsWeb from 'package:flutter/foundation.dart' for more robust checks)
    // This example uses a simple check, assuming non-web defaults to Android emulator
    try {
      // Check if running on web
      if (const bool.fromEnvironment('dart.library.js_util')) { // Basic web check
        return 'http://localhost:8080';
      }
      // Check if running on Android (needs dart:io import)
      // if (Platform.isAndroid) {
      //    return 'http://10.0.2.2:8080'; // Android emulator localhost
      // }
      // Default for others (iOS Sim, Desktop, potentially physical Android if 10.0.2.2 fails)
      return 'http://localhost:8080';
    } catch (e) {
      // Fallback if platform check fails somehow
      return 'http://localhost:8080';
    }
  }
}