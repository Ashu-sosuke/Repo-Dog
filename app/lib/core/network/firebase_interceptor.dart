import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseTokenInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final idToken = await user.getIdToken();
        if (idToken != null) {
          options.headers['Authorization'] = 'Bearer $idToken';
          debugPrint('[HTTP] ${options.method} ${options.path} → using Firebase ID token');
        }
      } else {
        // Fallback for local testing / mock token
        options.headers['Authorization'] = 'Bearer mock_dev_token_dev_user_123';
        debugPrint('[HTTP] ${options.method} ${options.path} → using MOCK token (no Firebase user)');
      }
    } catch (e) {
      debugPrint('[HTTP] Error fetching Firebase ID Token: $e');
    }
    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('[HTTP] ← ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('[HTTP] ✗ ERROR ${err.response?.statusCode} ${err.requestOptions.path}: ${err.message}');
    if (err.response != null) {
      debugPrint('[HTTP]   Response body: ${err.response?.data}');
    }
    handler.next(err);
  }
}
