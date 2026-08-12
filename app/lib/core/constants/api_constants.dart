import 'package:flutter/foundation.dart';

class ApiConstants {
  // Backend is always on localhost:8000 during local development.
  // On Flutter Web the browser itself calls this URL directly.
  // On Android emulator use 10.0.2.2:8000 instead of localhost.
  static String get baseUrl {
    if (kReleaseMode) {
      return 'https://repo-dog.onrender.com';
    }
    return 'http://localhost:8000';
  }

  static const String authGithubCallback = '/auth/github/callback';
  static const String authMe = '/auth/me';

  static const String dashboard = '/dashboard';
  static const String projects = '/projects';
  static const String userDescription = '/user/description';
}
