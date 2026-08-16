import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
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

      UserCredential? userCredential;
      String? accessToken;

      if (kIsWeb) {
        // ── Web: signInWithPopup returns the GitHub access token directly ──
        userCredential = await FirebaseAuth.instance.signInWithPopup(githubProvider).timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw TimeoutException('Sign-in timed out. Please try again.'),
        );
        final cred = userCredential.credential;
        if (cred is OAuthCredential) {
          accessToken = cred.accessToken;
          debugPrint('[Auth] Web accessToken: ${accessToken != null ? "OK (${accessToken.length} chars)" : "NULL"}');
        }
      } else {
        // ── Android: Two-step flow ─────────────────────────────────────────
        // Step 1: Open GitHub OAuth in Chrome Custom Tab via flutter_web_auth_2.
        //         This captures the authorization CODE (not the token).
        //         The redirect lands at repodog://callback?code=xxx
        const githubClientId = 'Ov23liXcvuEnM7eN6BTG'; // public — safe in app
        final githubAuthUrl = Uri.https('github.com', '/login/oauth/authorize', {
          'client_id': githubClientId,
          'redirect_uri': 'repodog://callback',
          'scope': 'repo read:user',
          'allow_signup': 'true',
        });

        final result = await FlutterWebAuth2.authenticate(
          url: githubAuthUrl.toString(),
          callbackUrlScheme: 'repodog',
        ).timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw TimeoutException('GitHub authorization timed out. Please try again.'),
        );

        final code = Uri.parse(result).queryParameters['code'];
        if (code == null || code.isEmpty) {
          throw Exception('GitHub did not return an authorization code.');
        }
        debugPrint('[Auth] Android: Got GitHub auth code, exchanging via backend...');

        // Step 2: Firebase sign-in for identity (so we have a Firebase UID
        //         and the interceptor can attach a valid ID token).
        userCredential = await FirebaseAuth.instance.signInWithProvider(githubProvider).timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw TimeoutException('Firebase sign-in timed out.'),
        );

        // Wait for Firebase session to propagate so interceptor gets real ID token.
        User? firebaseUser = userCredential.user;
        if (firebaseUser == null) {
          for (int i = 0; i < 10; i++) {
            await Future.delayed(const Duration(milliseconds: 200));
            firebaseUser = FirebaseAuth.instance.currentUser;
            if (firebaseUser != null) break;
          }
        }
        debugPrint('[Auth] Android: Firebase user ready: ${firebaseUser?.uid}');

        // Step 3: POST code to backend → backend exchanges for real GitHub token.
        final profile = userCredential.additionalUserInfo?.profile;
        final exchangeResp = await _dio.post(
          ApiConstants.authGithubExchangeCode,
          data: {
            'code': code,
            'github_user_id': profile?['id'],
            'github_username': userCredential.additionalUserInfo?.username,
            'email': firebaseUser?.email,
            'display_name': firebaseUser?.displayName,
            'avatar_url': firebaseUser?.photoURL,
          },
        );
        debugPrint('[Auth] Android exchange-code response: ${exchangeResp.data}');

        // Mark state as syncing → UI transitions to SyncLoadingScreen
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          isSyncing: true,
          syncMessage: 'Connecting to GitHub...',
          firebaseUser: firebaseUser,
          githubConnected: true,
        );

        // Trigger sync and complete
        try {
          state = state.copyWith(syncMessage: 'Fetching your repositories...');
          final syncResp = await _dio.post('/sync/all?sync_now=true');
          debugPrint('[Auth] Android sync result: ${syncResp.data}');
          final reposSynced = (syncResp.data['repos_synced'] as int?) ?? 0;
          state = state.copyWith(
            syncMessage: 'Synced $reposSynced repositories ✓',
            syncReposCount: reposSynced,
          );
          await Future.delayed(const Duration(milliseconds: 1200));
        } catch (e) {
          debugPrint('[Auth] Android sync notice: $e');
        }

        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          isSyncing: false,
          syncMessage: null,
          firebaseUser: firebaseUser,
          githubConnected: true,
        );
        return; // Android flow complete — skip the web block below
      }

      // ── Web continuation (after signInWithPopup) ─────────────────────────
      // userCredential is non-null here (Android returned above).
      final webUser = userCredential!;
      User? firebaseUser = webUser.user ?? FirebaseAuth.instance.currentUser;
      final profile = webUser.additionalUserInfo?.profile;

      // Post callback to backend (stores token if accessToken was captured)
      final Map<String, dynamic> callbackData = {
        'github_user_id': profile?['id'],
        'github_username': webUser.additionalUserInfo?.username,
        'email': firebaseUser?.email,
        'display_name': firebaseUser?.displayName,
        'avatar_url': firebaseUser?.photoURL,
        'scopes': ['repo', 'read:user'],
      };
      if (accessToken != null && accessToken.isNotEmpty) {
        callbackData['github_access_token'] = accessToken;
      }
      debugPrint('[Auth] Posting web callback to backend...');
      final callbackResp = await _dio.post(ApiConstants.authGithubCallback, data: callbackData);
      debugPrint('[Auth] Web callback response: ${callbackResp.data}');

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
