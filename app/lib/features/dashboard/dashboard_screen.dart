import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_provider.dart';

final dashboardDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiConstants.dashboard);
  return response.data ?? {};
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Always refresh on mount so data is fresh after the post-login sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(dashboardDataProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard Overview',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(dashboardDataProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading dashboard data: $err', style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.refresh(dashboardDataProvider),
                child: const Text('Retry'),
              )
            ],
          ),
        ),
        data: (data) {
          final summary = data['summary'] ?? {};
          final recentRepos = (data['recent_repositories'] as List?) ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, ${authState.firebaseUser?.displayName ?? "Developer"}! 🚀',
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'GitHub Sync Active • Health Score ${summary['health_score'] ?? 92}%',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final dio = ref.read(dioProvider);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await dio.post('/sync/all');
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('GitHub sync started in background!')),
                                );
                                ref.invalidate(dashboardDataProvider);
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Sync failed: $e')),
                                );
                              }
                            },
                            icon: const Icon(Icons.sync_rounded, size: 18),
                            label: const Text('Sync GitHub Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.darkBackground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/projects'),
                            icon: const Icon(Icons.folder_open_rounded, size: 18),
                            label: const Text('View All Repos'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Metrics Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    return GridView.count(
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      childAspectRatio: isWide ? 1.6 : 1.3,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _MetricCard(
                          title: 'Total Repositories',
                          value: '${summary['total_repositories'] ?? 0}',
                          icon: Icons.source_rounded,
                          color: AppTheme.primaryColor,
                        ),
                        _MetricCard(
                          title: 'Open PRs',
                          value: '${summary['open_pull_requests'] ?? 0}',
                          icon: Icons.merge_type_rounded,
                          color: AppTheme.secondaryColor,
                        ),
                        _MetricCard(
                          title: 'Failing CI Runs',
                          value: '${summary['failing_ci_runs'] ?? 0}',
                          icon: Icons.cancel_outlined,
                          color: Colors.redAccent,
                        ),
                        _MetricCard(
                          title: 'Active Branches',
                          value: '${summary['active_branches'] ?? 0}',
                          icon: Icons.call_split_rounded,
                          color: AppTheme.accentColor,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Recent Repositories Section
                Text(
                  'Recent Repositories',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                if (recentRepos.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No repositories synced yet. Trigger GitHub sync to import your projects!',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentRepos.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final repo = recentRepos[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppTheme.primaryColor,
                            child: Icon(Icons.code, color: Colors.white),
                          ),
                          title: Text(
                            repo['name'] ?? 'Repository',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            repo['full_name'] ?? '',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                          trailing: Text('⭐ ${repo['stars'] ?? 0}'),
                          onTap: () => context.go('/projects/${repo['id']}'),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, color: color, size: 22),
              ],
            ),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
