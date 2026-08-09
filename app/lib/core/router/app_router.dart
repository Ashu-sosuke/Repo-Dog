import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/sync_loading_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/projects/project_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (BuildContext context, GoRouterState state) {
      final isOnLogin = state.matchedLocation == '/login';
      final isOnSync = state.matchedLocation == '/syncing';

      // Not logged in → go to login
      if (!authState.isAuthenticated) {
        return isOnLogin ? null : '/login';
      }

      // Logged in + syncing in progress → show sync screen
      if (authState.isSyncing) {
        return isOnSync ? null : '/syncing';
      }

      // Logged in, sync done, on login or sync → go to dashboard
      if (isOnLogin || isOnSync) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/syncing',
        builder: (context, state) => const SyncLoadingScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/projects',
        builder: (context, state) => const ProjectsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return ProjectDetailScreen(projectId: id);
            },
          ),
        ],
      ),
    ],
  );
});
