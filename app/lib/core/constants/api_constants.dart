import 'package:flutter/foundation.dart';

class ApiConstants {
  // Production (Render) URL is always used on physical devices.
  // Only Flutter Web debug builds can safely use localhost:8000 because
  // the browser and the backend both run on the same machine.
  static const String _renderUrl = 'https://repo-dog.onrender.com';
  static const String _localUrl = 'http://localhost:8000';

  static String get baseUrl {
    // kIsWeb = true only when compiled for the browser
    if (kIsWeb && !kReleaseMode) {
      return _localUrl; // browser dev: localhost works fine
    }
    return _renderUrl; // physical Android/iOS + all release builds
  }

  static const String authGithubCallback = '/auth/github/callback';
  static const String authMe = '/auth/me';

  static const String dashboard = '/dashboard';
  static const String projects = '/projects';
  static const String userDescription = '/user/description';
}
