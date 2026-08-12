import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import 'firebase_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl, // platform-aware: web → localhost:8000
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 45),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(FirebaseTokenInterceptor());
  return dio;
});
