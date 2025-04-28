// lib/config/dio_client.dart
import 'package:dio/dio.dart';
import 'package:sib_expense_app/config/app_config.dart'; // Import AppConfig
import 'package:shared_preferences/shared_preferences.dart'; // If needed for interceptor

Dio createDioClient() {
  final dio = Dio(
    BaseOptions(
      // Use the loaded base URL from the singleton
      baseUrl: AppConfig.instance.baseUrl,
      connectTimeout: const Duration(milliseconds: 15000), // Centralized timeout
      receiveTimeout: const Duration(milliseconds: 15000),
    ),
  );

  // Add the interceptor here, so it's applied consistently
  dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Get token from storage
        final prefs = await SharedPreferences.getInstance();
        final String? token = prefs.getString('jwt_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['Content-Type'] = 'application/json'; // Default content type
        print('--> ${options.method} ${options.uri}'); // Log request
        print('Headers: ${options.headers}');
        if (options.data != null) print('Data: ${options.data}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('<-- ${response.statusCode} ${response.requestOptions.uri}'); // Log response
        print('Response Data: ${response.data}');
        return handler.next(response);
      },
      onError: (DioException e, handler) { // Use DioException
        print('<-- DioError!');
        print('<-- ${e.message}');
        if(e.response != null) {
          print('<-- ${e.response?.statusCode} ${e.response?.requestOptions.uri}');
          print('Error Response Data: ${e.response?.data}');
        }
        return handler.next(e); // Forward the error
      }
  ));

  return dio;
}