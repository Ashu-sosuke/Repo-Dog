import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool isSyncing;        // true while post-login GitHub sync is running
  final String? syncMessage;   // progress text shown on sync loading screen
  final int syncReposCount;    // how many repos were synced (shown after complete)
  final User? firebaseUser;
  final String? errorMessage;
  final bool githubConnected;

  AuthState({
    required this.isAuthenticated,
    required this.isLoading,
    this.isSyncing = false,
    this.syncMessage,
    this.syncReposCount = 0,
    this.firebaseUser,
    this.errorMessage,
    this.githubConnected = false,
  });

  factory AuthState.initial() => AuthState(
        isAuthenticated: FirebaseAuth.instance.currentUser != null,
        isLoading: false,
        firebaseUser: FirebaseAuth.instance.currentUser,
      );

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isSyncing,
    String? syncMessage,
    int? syncReposCount,
    User? firebaseUser,
    String? errorMessage,
    bool? githubConnected,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      syncMessage: syncMessage ?? this.syncMessage,
      syncReposCount: syncReposCount ?? this.syncReposCount,
      firebaseUser: firebaseUser ?? this.firebaseUser,
      errorMessage: errorMessage,
      githubConnected: githubConnected ?? this.githubConnected,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Dio _dio;

  /// Guards against authStateChanges firing mid sign-in flow and
  /// prematurely redirecting to dashboard before the backend callback
  /// and sync have completed.
  bool _isSigningIn = false;

  AuthNotifier(this._dio) : super(AuthState.initial()) {
    _checkInitialState();

    // FIX #2: Only allow authStateChanges to drive navigation when we are NOT
    // inside an active signInWithGitHub() call. On Android, this listener fires
    // BEFORE signInWithProvider() returns its Future, which previously caused
    // the router to redirect to /dashboard before the backend callback posted.
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (_isSigningIn) {
        debugPrint('[Auth] authStateChanges suppressed — sign-in flow in progress');
        return;
      }
      if (user != null && !state.isAuthenticated) {
        debugPrint('[Auth] authStateChanges: restoring session for ${user.email}');
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          firebaseUser: user,
        );
        fetchUserProfile();
      }
    });
  }

  Future<void> _checkInitialState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      state = state.copyWith(isAuthenticated: true, firebaseUser: user);
      await fetchUserProfile();
    }
  }

  Future<void> signInWithGitHub() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    // FIX #2: Raise flag so authStateChanges listener does not interfere.
    _isSigningIn = true;

    try {
      // FIX #3: Removed the pre-signOut() call.
      // On Web, signing out first forced a fresh consent flow.
      // On Android, signOut() triggered authStateChanges(user=null) and then
      // immediately signInWithProvider caused a race condition between the
      // listener resetting state and the sign-in flow updating state.
      // The provider's fresh Chrome Custom Tab already guarantees a new token.

      final githubProvider = GithubAuthProvider();
      githubProvider.addScope('repo');
      githubProvider.addScope('read:user');
      // NOTE: 'prompt: consent' is a Google/OIDC parameter — GitHub ignores it.
      // Removed to keep the OAuth parameters clean.

      UserCredential userCredential;
      if (kIsWeb) {
        userCredential = await FirebaseAuth.instance.signInWithPopup(githubProvider).timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw TimeoutException('Sign-in timed out. Please try again.'),
        );
      } else {
        userCredential = await FirebaseAuth.instance.signInWithProvider(githubProvider).timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw TimeoutException('Sign-in timed out. Please try again.'),
        );
      }

      // FIX #4: Wait for Firebase session to fully propagate so that
      // FirebaseTokenInterceptor finds a non-null currentUser and attaches
      // the real ID token instead of falling back to the mock dev token.
      User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        // Poll briefly for currentUser to appear (Android propagation delay).
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          firebaseUser = FirebaseAuth.instance.currentUser;
          if (firebaseUser != null) break;
        }
      }
      debugPrint('[Auth] Firebase user ready: ${firebaseUser?.uid}');

      // FIX #1: Extract GitHub access token from OAuthCredential.
      // On Web (signInWithPopup) this is populated. On Android (signInWithProvider)
      // the Firebase SDK may return null for accessToken — this is a known limitation
      // of the Chrome Custom Tab flow in firebase_auth 5.x on Android.
      // We proceed without it; the backend stores any valid token if provided.
      String? accessToken;
      final cred = userCredential.credential;
      if (cred is OAuthCredential) {
        accessToken = cred.accessToken;
        debugPrint('[Auth] OAuthCredential accessToken: ${accessToken != null ? "OK (${accessToken.length} chars)" : "NULL — Android limitation, proceeding without it"}');
      }

      // Log additional user info for debugging
      final profile = userCredential.additionalUserInfo?.profile;
      debugPrint('[Auth] GitHub username: ${userCredential.additionalUserInfo?.username}');
      debugPrint('[Auth] GitHub user ID: ${profile?['id']}');
      debugPrint('[Auth] Firebase UID: ${firebaseUser?.uid}');

      // 1. Build callback payload
      final Map<String, dynamic> callbackData = {
        'github_user_id': profile?['id'],
        'github_username': userCredential.additionalUserInfo?.username,
        'email': firebaseUser?.email,
        'display_name': firebaseUser?.displayName,
        'avatar_url': firebaseUser?.photoURL,
        'scopes': ['repo', 'read:user'],
      };
      if (accessToken != null && accessToken.isNotEmpty) {
        callbackData['github_access_token'] = accessToken;
      }

      // 2. Post callback to backend (updates user record & encrypted token if provided).
      // FirebaseTokenInterceptor will now find a valid currentUser because we waited above.
      debugPrint('[Auth] Posting auth callback to backend...');
      final callbackResp = await _dio.post(
        ApiConstants.authGithubCallback,
        data: callbackData,
      );
      debugPrint('[Auth] Callback response: ${callbackResp.data}');

      // 3. Mark state as syncing so UI transitions to SyncLoadingScreen
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        isSyncing: true,
        syncMessage: 'Connecting to GitHub...',
        firebaseUser: firebaseUser,
        githubConnected: true,
      );

      // 4. Trigger full GitHub repo sync
      try {
        state = state.copyWith(syncMessage: 'Fetching your repositories...');
        final syncResp = await _dio.post('/sync/all?sync_now=true');
        debugPrint('[Auth] Sync result: ${syncResp.data}');
        final reposSynced = (syncResp.data['repos_synced'] as int?) ?? 0;
        state = state.copyWith(
          syncMessage: 'Synced $reposSynced repositories ✓',
          syncReposCount: reposSynced,
        );
        await Future.delayed(const Duration(milliseconds: 1200));
      } catch (e) {
        debugPrint('[Auth] Sync notice: $e');
      }

      // 5. Complete sign-in process → navigates to Dashboard
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        isSyncing: false,
        syncMessage: null,
        firebaseUser: firebaseUser,
        githubConnected: true,
      );
    } catch (e) {
      debugPrint('[Auth] GitHub sign-in error: $e');

      // Sign out on failure so Firebase session is clean for next attempt.
      try { await FirebaseAuth.instance.signOut(); } catch (_) {}

      String msg = e.toString();
      if (msg.contains('connection timeout') || msg.contains('connectTimeout') || msg.contains('receiveTimeout')) {
        msg = 'Server was sleeping (Render Free Tier cold start). Now awake! Please tap "Sign in with GitHub" again.';
      } else if (msg.contains('INVALID_APP_ID')) {
        msg = 'Android Firebase App ID mismatch. Check SHA-1 is registered in Firebase Console.';
      } else if (msg.contains('missing initial state') || msg.contains('sessionStorage') || msg.contains('storage-partitioned') || msg.contains('initial state')) {
        msg = 'Mobile browser blocked storage session. Please try again.';
      } else if (msg.contains('timed out') || msg.contains('TimeoutException')) {
        msg = 'Sign-in timed out. Please try again.';
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
      );
    } finally {
      // FIX #2: Always lower the flag when sign-in flow ends (success or error).
      _isSigningIn = false;
    }
  }

  Future<void> signInWithPAT(String patToken) async {
    final token = patToken.trim();
    if (token.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter a valid GitHub token.');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      debugPrint('[Auth] Verifying GitHub PAT token...');
      final ghDio = Dio();
      final ghResp = await ghDio.get(
        'https://api.github.com/user',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github.v3+json',
        }),
      );
      final ghUser = ghResp.data ?? {};
      final username = ghUser['login'];
      final email = ghUser['email'];
      final name = ghUser['name'] ?? username;
      final avatar = ghUser['avatar_url'];
      final ghId = ghUser['id'];

      debugPrint('[Auth] PAT Validated for user: $username ($ghId)');

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        isSyncing: true,
        syncMessage: 'Connecting GitHub Account ($username)...',
        githubConnected: true,
      );

      final callbackResp = await _dio.post(
        ApiConstants.authGithubCallback,
        data: {
          'github_access_token': token,
          'github_user_id': ghId,
          'github_username': username,
          'email': email,
          'display_name': name,
          'avatar_url': avatar,
          'scopes': ['repo', 'read:user'],
        },
      );
      debugPrint('[Auth] PAT Callback response: ${callbackResp.data}');

      try {
        state = state.copyWith(syncMessage: 'Fetching repositories for $username...');
        final syncResp = await _dio.post('/sync/all?sync_now=true');
        final reposSynced = (syncResp.data['repos_synced'] as int?) ?? 0;
        state = state.copyWith(
          syncMessage: 'Synced $reposSynced repositories ✓',
          syncReposCount: reposSynced,
        );
        await Future.delayed(const Duration(milliseconds: 1200));
      } catch (e) {
        debugPrint('[Auth] Sync error: $e');
      }

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        isSyncing: false,
        syncMessage: null,
        githubConnected: true,
      );
    } catch (e) {
      debugPrint('[Auth] PAT sign-in error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid GitHub Token or Network Error: ${e.toString()}',
      );
    }
  }

  Future<void> devMockSignIn() async {
    state = state.copyWith(isLoading: true);
    try {
      debugPrint('[DevMode] Posting mock token to /auth/github/callback...');
      final resp = await _dio.post(
        ApiConstants.authGithubCallback,
        data: {
          'github_access_token': 'gho_mock_access_token_123456789',
          'github_username': 'devuser',
          'email': 'dev@example.com',
          'display_name': 'Developer User',
          'avatar_url': 'https://github.com/ghost.png',
        },
      );
      debugPrint('[DevMode] Callback response: ${resp.data}');

      try {
        final syncResp = await _dio.post('/sync/all?sync_now=true');
        debugPrint('[DevMode] Sync result: ${syncResp.data}');
      } catch (e) {
        debugPrint('[DevMode] Sync notice: $e');
      }
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        isSyncing: false,
        syncMessage: null,
        githubConnected: true,
      );
    } catch (e) {
      debugPrint('[DevMode] Error: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> fetchUserProfile() async {
    try {
      final response = await _dio.get(ApiConstants.authMe);
      if (response.data != null) {
        final githubConnected = response.data['github_connected'] ?? false;
        state = state.copyWith(githubConnected: githubConnected);
      }
    } catch (e) {
      debugPrint('[Auth] Failed to fetch user profile: $e');
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    state = AuthState(isAuthenticated: false, isLoading: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthNotifier(dio);
});
