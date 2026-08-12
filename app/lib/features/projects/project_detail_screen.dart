import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';

final projectDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  ref.keepAlive();
  final dio = ref.watch(dioProvider);
  final response = await dio.get('${ApiConstants.projects}/$id');
  return response.data ?? {};
});

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(projectDetailProvider(projectId));

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppTheme.canvasDefault,
        appBar: AppBar(
          backgroundColor: AppTheme.canvasSubtle,
          title: Text(
            'Repository Details',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.fgDefault),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.sync_rounded, color: AppTheme.fgMuted),
              onPressed: () async {
                final dio = ref.read(dioProvider);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await dio.post('/sync/all');
                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.successGreen.withValues(alpha: 0.15),
                      content: Text(
                        'GitHub sync started in background!',
                        style: GoogleFonts.inter(color: AppTheme.successGreen),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  ref.invalidate(projectDetailProvider(projectId));
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.dangerRed.withValues(alpha: 0.15),
                      content: Text('Sync failed: $e', style: GoogleFonts.inter(color: AppTheme.dangerRed)),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 12),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: AppTheme.accentBlue,
            labelColor: AppTheme.accentBlue,
            unselectedLabelColor: AppTheme.fgMuted,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
            tabs: const [
              Tab(text: 'Overview & README'),
              Tab(text: 'Branches'),
              Tab(text: 'Issues & PRs'),
              Tab(text: 'CI/CD Workflows'),
              Tab(text: 'Notes & Goals'),
            ],
          ),
        ),
        body: detailAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accentBlue, strokeWidth: 2),
          ),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 36),
                const SizedBox(height: 12),
                Text(
                  'Error loading project details',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.fgDefault),
                ),
                const SizedBox(height: 6),
                Text('$err', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted)),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.refresh(projectDetailProvider(projectId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (data) {
            return TabBarView(
              children: [
                _OverviewTab(data: data),
                _BranchesTab(branches: (data['branches'] as List?) ?? []),
                _IssuesPRsTab(
                  issues: (data['issues'] as List?) ?? [],
                  pullRequests: (data['pull_requests'] as List?) ?? [],
                ),
                _WorkflowsTab(runs: (data['workflow_runs'] as List?) ?? []),
                _NotesGoalsTab(projectId: projectId, data: data, ref: ref),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Overview & README Tab ───────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OverviewTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final readme = data['readme_content'] as String?;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Title & Badges
        Row(
          children: [
            Expanded(
              child: Text(
                data['name'] ?? 'Repository',
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.fgDefault),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.4)),
              ),
              child: Text(
                data['status']?.toUpperCase() ?? 'ACTIVE',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.successGreen, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          data['full_name'] ?? '',
          style: GoogleFonts.inter(color: AppTheme.fgMuted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Text(
          data['description'] ?? 'No description provided for this repository.',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.fgDefault, height: 1.5),
        ),
        const SizedBox(height: 20),

        // Info Badges
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _InfoBadge(icon: Icons.star_rounded, label: 'Stars', value: '${data['stars'] ?? 0}'),
            _InfoBadge(icon: Icons.call_split_rounded, label: 'Forks', value: '${data['forks'] ?? 0}'),
            _InfoBadge(icon: Icons.code_rounded, label: 'Language', value: data['primary_language'] ?? 'Code'),
            _InfoBadge(icon: Icons.alt_route_rounded, label: 'Default Branch', value: data['default_branch'] ?? 'main'),
          ],
        ),

        const SizedBox(height: 28),

        // ── GitHub Styled README Card ───────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppTheme.canvasSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderDefault, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // README Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppTheme.canvasOverlay,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  border: Border(
                    bottom: BorderSide(color: AppTheme.borderDefault, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, size: 16, color: AppTheme.fgMuted),
                    const SizedBox(width: 8),
                    Text(
                      'README.md',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.fgDefault,
                      ),
                    ),
                  ],
                ),
              ),

              // README Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: (readme != null && readme.trim().isNotEmpty)
                    ? MarkdownBody(
                        data: readme,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: GoogleFonts.inter(fontSize: 14, color: AppTheme.fgDefault, height: 1.6),
                          h1: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.fgDefault),
                          h2: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.fgDefault),
                          h3: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.fgDefault),
                          code: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.accentBlue,
                            backgroundColor: AppTheme.canvasDefault,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: AppTheme.canvasDefault,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.borderDefault),
                          ),
                          blockquoteDecoration: BoxDecoration(
                            color: AppTheme.canvasOverlay,
                            borderRadius: BorderRadius.circular(4),
                            border: const Border(
                              left: BorderSide(color: AppTheme.accentBlue, width: 3),
                            ),
                          ),
                          a: GoogleFonts.inter(color: AppTheme.accentBlue, decoration: TextDecoration.underline),
                          listBullet: GoogleFonts.inter(color: AppTheme.fgMuted),
                          horizontalRuleDecoration: BoxDecoration(
                            border: Border.all(color: AppTheme.borderDefault, width: 0.5),
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.description_outlined, size: 36, color: AppTheme.fgSubtle),
                              const SizedBox(height: 12),
                              Text(
                                'No README.md found in this repository.',
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.fgMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoBadge({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.canvasOverlay,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.accentBlue),
          const SizedBox(width: 8),
          Text('$label: ', style: GoogleFonts.inter(color: AppTheme.fgMuted, fontSize: 12)),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.fgDefault)),
        ],
      ),
    );
  }
}

// ─── Branches Tab ─────────────────────────────────────────────────────────────

class _BranchesTab extends StatelessWidget {
  final List<dynamic> branches;
  const _BranchesTab({required this.branches});

  String _formatBranchDate(String? isoStr) {
    if (isoStr == null || isoStr.isEmpty) return 'No recent commit recorded';
    try {
      final dt = DateTime.parse(isoStr);
      final now = DateTime.now().toUtc();
      final diff = now.difference(dt);

      String rel = '';
      if (diff.inMinutes < 1) {
        rel = 'just now';
      } else if (diff.inMinutes < 60) {
        rel = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        rel = '${diff.inHours}h ago';
      } else if (diff.inDays == 1) {
        rel = 'yesterday';
      } else if (diff.inDays < 7) {
        rel = '${diff.inDays}d ago';
      } else if (diff.inDays < 30) {
        rel = '${(diff.inDays / 7).floor()}w ago';
      } else if (diff.inDays < 365) {
        rel = '${(diff.inDays / 30).floor()}mo ago';
      } else {
        rel = '${(diff.inDays / 365).floor()}y ago';
      }

      final dateStr =
          "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} UTC";
      return 'Last commit $rel  •  $dateStr';
    } catch (_) {
      return 'Last commit: $isoStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty) {
      return Center(
        child: Text(
          'No branches synced yet for this repository.',
          style: GoogleFonts.inter(color: AppTheme.fgMuted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: branches.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final b = branches[index];
        final name = b['name'] ?? 'branch';
        final isDefault = b['is_default'] ?? false;
        final isStale = b['is_stale'] ?? false;
        final timeStr = _formatBranchDate(b['last_commit_at']);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.canvasSubtle,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDefault
                  ? AppTheme.accentBlue.withValues(alpha: 0.3)
                  : AppTheme.borderDefault,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDefault
                      ? AppTheme.accentBlue.withValues(alpha: 0.12)
                      : AppTheme.canvasOverlay,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDefault
                        ? AppTheme.accentBlue.withValues(alpha: 0.3)
                        : AppTheme.borderDefault,
                  ),
                ),
                child: Icon(
                  Icons.call_split_rounded,
                  size: 16,
                  color: isDefault ? AppTheme.accentBlue : AppTheme.fgMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDefault ? AppTheme.accentBlue : AppTheme.fgDefault,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.fgMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'DEFAULT',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppTheme.accentBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (isStale) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.warningAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.warningAmber.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'STALE (>30d)',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppTheme.warningAmber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Issues & PRs Tab ─────────────────────────────────────────────────────────

class _IssuesPRsTab extends StatelessWidget {
  final List<dynamic> issues;
  final List<dynamic> pullRequests;
  const _IssuesPRsTab({required this.issues, required this.pullRequests});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pull Requests (${pullRequests.length})', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.fgDefault)),
          const SizedBox(height: 10),
          if (pullRequests.isEmpty)
            Text('No pull requests recorded.', style: GoogleFonts.inter(color: AppTheme.fgMuted))
          else
            ...pullRequests.map((pr) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.merge_type_rounded, color: AppTheme.openPrColor),
                    title: Text('#${pr['github_pr_number']} ${pr['title']}'),
                    subtitle: Text('Author: ${pr['author'] ?? 'unknown'}'),
                    trailing: Chip(
                      label: Text(pr['state']?.toUpperCase() ?? 'OPEN'),
                    ),
                  ),
                )),
          const SizedBox(height: 28),
          Text('Issues (${issues.length})', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.fgDefault)),
          const SizedBox(height: 10),
          if (issues.isEmpty)
            Text('No issues recorded.', style: GoogleFonts.inter(color: AppTheme.fgMuted))
          else
            ...issues.map((iss) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline_rounded, color: AppTheme.warningAmber),
                    title: Text('#${iss['github_issue_number']} ${iss['title']}'),
                    subtitle: Text('State: ${iss['state']}'),
                  ),
                )),
        ],
      ),
    );
  }
}

// ─── Workflows Tab ────────────────────────────────────────────────────────────

class _WorkflowsTab extends StatelessWidget {
  final List<dynamic> runs;
  const _WorkflowsTab({required this.runs});

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty) {
      return Center(
        child: Text('No GitHub Actions workflow runs found.', style: GoogleFonts.inter(color: AppTheme.fgMuted)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: runs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final run = runs[index];
        final status = run['status'] ?? 'unknown';
        final isSuccess = status == 'success';

        return Card(
          child: ListTile(
            leading: Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isSuccess ? AppTheme.successGreen : AppTheme.dangerRed,
            ),
            title: Text(run['workflow_name'] ?? 'CI Workflow', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            subtitle: Text('Run #${run['run_number'] ?? ''} • Status: $status'),
          ),
        );
      },
    );
  }
}

// ─── Notes & Goals Tab ────────────────────────────────────────────────────────

class _NotesGoalsTab extends StatelessWidget {
  final String projectId;
  final Map<String, dynamic> data;
  final WidgetRef ref;
  const _NotesGoalsTab({required this.projectId, required this.data, required this.ref});

  @override
  Widget build(BuildContext context) {
    final notes = (data['notes'] as List?) ?? [];
    final goals = (data['goals'] as List?) ?? [];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Project Notes', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.fgDefault)),
              IconButton(
                icon: const Icon(Icons.add_rounded, color: AppTheme.accentBlue),
                onPressed: () => _showAddNoteDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (notes.isEmpty)
            Text('No notes added yet for this repository.', style: GoogleFonts.inter(color: AppTheme.fgMuted))
          else
            ...notes.map((n) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.notes_rounded, color: AppTheme.warningAmber),
                    title: Text(n['content'] ?? ''),
                  ),
                )),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Project Goals', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.fgDefault)),
              IconButton(
                icon: const Icon(Icons.add_rounded, color: AppTheme.accentBlue),
                onPressed: () => _showAddGoalDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (goals.isEmpty)
            Text('No goals added yet.', style: GoogleFonts.inter(color: AppTheme.fgMuted))
          else
            ...goals.map((g) => Card(
                  child: CheckboxListTile(
                    value: g['is_complete'] ?? false,
                    title: Text(
                      g['title'] ?? '',
                      style: TextStyle(
                        decoration: (g['is_complete'] ?? false) ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    onChanged: (val) {},
                  ),
                )),
        ],
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Project Note'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Enter note details...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.invalidate(projectDetailProvider(projectId));
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Project Goal'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. Achieve 80% test coverage'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.invalidate(projectDetailProvider(projectId));
            },
            child: const Text('Save Goal'),
          ),
        ],
      ),
    );
  }
}
