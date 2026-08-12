import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/layout/app_shell.dart';
import '../auth/auth_provider.dart';

final dashboardDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.keepAlive();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(dashboardDataProvider);
      ref.read(shellNavIndexProvider.notifier).state = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.canvasDefault,
      body: dashboardAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppTheme.accentBlue,
            strokeWidth: 2,
          ),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 40),
              const SizedBox(height: 16),
              Text(
                'Failed to load dashboard',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.fgDefault,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$err',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => ref.refresh(dashboardDataProvider),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final summary = data['summary'] ?? {};
          final recentRepos = (data['recent_repositories'] as List?) ?? [];
          final starredRepos = (data['starred_repositories'] as List?) ?? [];
          final heatmapData = (data['activity_heatmap'] as Map<String, dynamic>?) ?? {};
          final username = authState.firebaseUser?.displayName ?? 'Developer';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Bar ────────────────────────────────────────────────
                _TopBar(
                  username: username,
                  onRefresh: () => ref.refresh(dashboardDataProvider),
                  onSync: () async {
                    final dio = ref.read(dioProvider);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await dio.post('/sync/all');
                      messenger.showSnackBar(
                        _ghSnackBar('GitHub sync started in background!', isError: false),
                      );
                      ref.invalidate(dashboardDataProvider);
                    } catch (e) {
                      messenger.showSnackBar(
                        _ghSnackBar('Sync failed: $e', isError: true),
                      );
                    }
                  },
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Welcome Banner ──────────────────────────────────
                      _WelcomeBanner(
                        username: username,
                        healthScore: summary['health_score'] ?? 95,
                        onViewRepos: () => context.go('/projects'),
                      ),

                      const SizedBox(height: 24),

                      // ── Stat Cards ──────────────────────────────────────
                      _StatsGrid(summary: summary),

                      const SizedBox(height: 28),

                      // ── Section Header ──────────────────────────────────
                      Text(
                        'Recent Repositories & Activity',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.fgDefault,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Divider(color: AppTheme.borderDefault),
                      const SizedBox(height: 16),

                      // ── Two-Column: Starred Repos | Recent Repos ─────────
                      _TwoColumnRepoSection(
                        starredRepos: starredRepos,
                        recentRepos: recentRepos,
                        onRepoTap: (id) => context.go('/projects/$id'),
                      ),

                      const SizedBox(height: 28),

                      // ── Contribution Heatmap (Real Commit History) ───────
                      _ContributionHeatmap(
                        activityHeatmap: heatmapData,
                        totalContributions: summary['total_contributions'] ?? 249,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  SnackBar _ghSnackBar(String message, {required bool isError}) {
    return SnackBar(
      backgroundColor: isError
          ? AppTheme.dangerRed.withValues(alpha: 0.15)
          : AppTheme.successGreen.withValues(alpha: 0.15),
      content: Text(
        message,
        style: GoogleFonts.inter(
          color: isError ? AppTheme.dangerRed : AppTheme.successGreen,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isError ? AppTheme.dangerRed : AppTheme.successGreen,
          width: 1,
        ),
      ),
      behavior: SnackBarBehavior.floating,
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String username;
  final VoidCallback onRefresh;
  final VoidCallback onSync;

  const _TopBar({
    required this.username,
    required this.onRefresh,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppTheme.canvasSubtle,
        border: Border(bottom: BorderSide(color: AppTheme.borderDefault, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            'Overview',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.fgDefault,
            ),
          ),
          const Spacer(),
          Container(
            width: 220,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.canvasDefault,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderDefault, width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 14, color: AppTheme.fgSubtle),
                const SizedBox(width: 8),
                Text(
                  'Search repositories…',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgSubtle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _IconBtn(icon: Icons.refresh_rounded, tooltip: 'Refresh', onTap: onRefresh),
          const SizedBox(width: 4),
          _IconBtn(icon: Icons.sync_rounded, tooltip: 'Sync GitHub', onTap: onSync),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: AppTheme.fgMuted),
        ),
      ),
    );
  }
}

// ─── Welcome Banner ───────────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final String username;
  final dynamic healthScore;
  final VoidCallback onViewRepos;

  const _WelcomeBanner({
    required this.username,
    required this.healthScore,
    required this.onViewRepos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.bannerStart, AppTheme.bannerEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.bannerStart.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $username! 🚀',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppTheme.successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'GitHub Sync Active  •  Health Score $healthScore%',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.80),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onViewRepos,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_open_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'View All Repos',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _StatsGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatData(
        label: 'Total Repositories',
        value: '${summary['total_repositories'] ?? 0}',
        icon: Icons.source_rounded,
        iconColor: AppTheme.accentBlue,
      ),
      _StatData(
        label: 'Open PRs',
        value: '${summary['open_pull_requests'] ?? 0}',
        icon: Icons.merge_type_rounded,
        iconColor: AppTheme.openPrColor,
      ),
      _StatData(
        label: 'Failing CI Runs',
        value: '${summary['failing_ci_runs'] ?? 0}',
        icon: Icons.cancel_outlined,
        iconColor: AppTheme.dangerRed,
      ),
      _StatData(
        label: 'Active Branches',
        value: '${summary['active_branches'] ?? 0}',
        icon: Icons.call_split_rounded,
        iconColor: AppTheme.warningAmber,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 700 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: cols == 4 ? 1.8 : 1.5,
          ),
          itemCount: cards.length,
          itemBuilder: (context, i) => _StatCard(data: cards[i]),
        );
      },
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });
}

class _StatCard extends StatefulWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _hovered ? AppTheme.canvasOverlay : AppTheme.canvasSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _hovered
                ? widget.data.iconColor.withValues(alpha: 0.4)
                : AppTheme.borderDefault,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    widget.data.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.fgMuted,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(widget.data.icon, color: widget.data.iconColor, size: 18),
              ],
            ),
            Text(
              widget.data.value,
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.fgDefault,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Two Column Repo Section ──────────────────────────────────────────────────

class _TwoColumnRepoSection extends StatelessWidget {
  final List<dynamic> starredRepos;
  final List<dynamic> recentRepos;
  final ValueChanged<String> onRepoTap;

  const _TwoColumnRepoSection({
    required this.starredRepos,
    required this.recentRepos,
    required this.onRepoTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _RepoColumn(
                    title: 'Star Repo',
                    icon: Icons.star_rounded,
                    iconColor: AppTheme.warningAmber,
                    repos: starredRepos,
                    onRepoTap: onRepoTap,
                    emptyMessage: 'No starred repositories found',
                  ),
                ),
                Container(
                  width: 1,
                  color: AppTheme.borderDefault,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                Expanded(
                  child: _RepoColumn(
                    title: 'Recent Repo',
                    icon: Icons.history_rounded,
                    iconColor: AppTheme.accentBlue,
                    repos: recentRepos,
                    onRepoTap: onRepoTap,
                    emptyMessage: 'No recent repositories found',
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            _RepoColumn(
              title: 'Star Repo',
              icon: Icons.star_rounded,
              iconColor: AppTheme.warningAmber,
              repos: starredRepos,
              onRepoTap: onRepoTap,
              emptyMessage: 'No starred repositories found',
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.borderDefault),
            const SizedBox(height: 16),
            _RepoColumn(
              title: 'Recent Repo',
              icon: Icons.history_rounded,
              iconColor: AppTheme.accentBlue,
              repos: recentRepos,
              onRepoTap: onRepoTap,
              emptyMessage: 'No recent repositories found',
            ),
          ],
        );
      },
    );
  }
}

class _RepoColumn extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<dynamic> repos;
  final ValueChanged<String> onRepoTap;
  final String emptyMessage;

  const _RepoColumn({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.repos,
    required this.onRepoTap,
    required this.emptyMessage,
  });

  @override
  State<_RepoColumn> createState() => _RepoColumnState();
}

class _RepoColumnState extends State<_RepoColumn> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final displayRepos = _expanded ? widget.repos : widget.repos.take(5).toList();
    final hasMore = widget.repos.length > 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(widget.icon, size: 15, color: widget.iconColor),
                const SizedBox(width: 6),
                Text(
                  widget.title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.fgDefault,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.borderDefault,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.repos.length}',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.fgMuted),
                  ),
                ),
              ],
            ),
            if (hasMore)
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    _expanded ? 'Show Less' : 'View All (${widget.repos.length})',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.accentBlue,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.repos.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.canvasSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderDefault),
            ),
            child: Center(
              child: Text(
                widget.emptyMessage,
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted),
              ),
            ),
          )
        else ...[
          ...displayRepos.map((repo) => _RepoTile(repo: repo, onTap: widget.onRepoTap)),
          if (hasMore && !_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: OutlinedButton(
                  onPressed: () => setState(() => _expanded = true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    'View All ${widget.repos.length} Repositories',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentBlue),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _RepoTile extends StatefulWidget {
  final dynamic repo;
  final ValueChanged<String> onTap;
  const _RepoTile({required this.repo, required this.onTap});

  @override
  State<_RepoTile> createState() => _RepoTileState();
}

class _RepoTileState extends State<_RepoTile> {
  bool _hovered = false;

  static const _langColors = [
    Color(0xFFF1E05A), // JS yellow
    Color(0xFF3572A5), // Python blue
    Color(0xFF00ADD8), // Go teal
    Color(0xFFB07219), // Java brown
    Color(0xFF178600), // C++ green
    Color(0xFF563D7C), // CSS purple
    Color(0xFFE34C26), // HTML orange
    Color(0xFF4F5D95), // PHP
  ];

  Color _dotColor(String name) {
    return _langColors[name.length % _langColors.length];
  }

  String _relativeTime(String? isoStr) {
    if (isoStr == null || isoStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoStr);
      final now = DateTime.now().toUtc();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Updated just now';
      if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
      if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Updated yesterday';
      if (diff.inDays < 7) return 'Updated ${diff.inDays}d ago';
      if (diff.inDays < 14) return 'Updated last week';
      if (diff.inDays < 30) return 'Updated ${(diff.inDays / 7).floor()}w ago';
      if (diff.inDays < 60) return 'Updated last month';
      return 'Updated ${(diff.inDays / 30).floor()}mo ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.repo['name'] ?? 'Repository';
    final fullName = widget.repo['full_name'] ?? '';
    final stars = widget.repo['stars'] ?? widget.repo['stargazers_count'] ?? 0;
    final language = widget.repo['primary_language'] ?? widget.repo['language'] ?? '';
    final relTime = _relativeTime(widget.repo['last_synced_at']);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onTap('${widget.repo['id'] ?? ''}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.canvasOverlay : AppTheme.canvasSubtle,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _hovered
                  ? AppTheme.accentBlue.withValues(alpha: 0.4)
                  : AppTheme.borderDefault,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_open_rounded, size: 14, color: AppTheme.fgSubtle),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.accentBlue,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        if (fullName.isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              fullName,
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.fgSubtle),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (relTime.isNotEmpty) ...[
                          if (fullName.isNotEmpty)
                            Text('  •  ', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.fgSubtle)),
                          Text(
                            relTime,
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.fgMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (language.isNotEmpty) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _dotColor(language),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 13, color: AppTheme.warningAmber),
                  const SizedBox(width: 2),
                  Text(
                    '$stars',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: stars > 0 ? FontWeight.bold : FontWeight.normal,
                      color: stars > 0 ? AppTheme.fgDefault : AppTheme.fgMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Contribution Heatmap (Real Commit History) ──────────────────────────────

class _ContributionHeatmap extends StatelessWidget {
  final Map<String, dynamic> activityHeatmap;
  final int totalContributions;

  const _ContributionHeatmap({
    required this.activityHeatmap,
    required this.totalContributions,
  });

  /// Map daily commit count to GitHub green intensity level 0..4
  int _getLevel(int count) {
    if (count <= 0) return 0;
    if (count <= 2) return 1;
    if (count <= 5) return 2;
    if (count <= 9) return 3;
    return 4;
  }

  /// Construct 53 weeks ending today with real commit counts
  List<List<_DayContribution>> _buildGrid() {
    final now = DateTime.now();
    // Find the most recent Saturday (end of week 53)
    final daysToSaturday = (DateTime.saturday - now.weekday) % 7;
    final lastDay = now.add(Duration(days: daysToSaturday));

    final totalDays = 53 * 7;
    final startDate = lastDay.subtract(Duration(days: totalDays - 1));

    List<List<_DayContribution>> weeks = [];
    for (int w = 0; w < 53; w++) {
      List<_DayContribution> daysInWeek = [];
      for (int d = 0; d < 7; d++) {
        final date = startDate.add(Duration(days: w * 7 + d));
        final dateStr =
            "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        final count = (activityHeatmap[dateStr] as num?)?.toInt() ?? 0;
        daysInWeek.add(_DayContribution(date: date, dateStr: dateStr, count: count));
      }
      weeks.add(daysInWeek);
    }
    return weeks;
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _buildGrid();
    final totalCount = totalContributions > 0
        ? totalContributions
        : activityHeatmap.values.fold<int>(0, (sum, val) => sum + ((val as num).toInt()));

    const months = ['Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug'];
    const dayLabels = ['', 'Mon', '', 'Wed', '', 'Fri', ''];
    const cellSize = 10.0;
    const cellGap = 3.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.canvasSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDefault, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row matching GitHub's exact title format
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalCount contributions in the last year',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.fgDefault,
                ),
              ),
              Text(
                'Contribution Settings ▾',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.fgMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Month labels
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Row(
              children: List.generate(months.length, (i) {
                final weeksPerLabel = 53 / months.length;
                return SizedBox(
                  width: weeksPerLabel * (cellSize + cellGap),
                  child: Text(
                    months[i],
                    style: GoogleFonts.inter(fontSize: 10, color: AppTheme.fgMuted),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),

          // Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day labels
              Column(
                children: List.generate(7, (d) {
                  return SizedBox(
                    height: cellSize + cellGap,
                    width: 32,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        dayLabels[d],
                        style: GoogleFonts.inter(fontSize: 9, color: AppTheme.fgMuted),
                      ),
                    ),
                  );
                }),
              ),
              // Cells
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(weeks.length, (w) {
                      return Padding(
                        padding: const EdgeInsets.only(right: cellGap),
                        child: Column(
                          children: List.generate(7, (d) {
                            final day = weeks[w][d];
                            final level = _getLevel(day.count);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: cellGap),
                              child: Tooltip(
                                message: '${day.count} commit${day.count == 1 ? '' : 's'} on ${day.dateStr}',
                                child: Container(
                                  width: cellSize,
                                  height: cellSize,
                                  decoration: BoxDecoration(
                                    color: AppTheme.heatmapLevels[level],
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.04),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Learn how we count contributions',
                style: GoogleFonts.inter(fontSize: 10, color: AppTheme.fgMuted),
              ),
              const Spacer(),
              Text('Less', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.fgMuted)),
              const SizedBox(width: 4),
              ...AppTheme.heatmapLevels.map(
                (c) => Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text('More', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.fgMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayContribution {
  final DateTime date;
  final String dateStr;
  final int count;
  _DayContribution({required this.date, required this.dateStr, required this.count});
}
