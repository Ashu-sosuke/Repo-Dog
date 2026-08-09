import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';

final projectDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
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
        appBar: AppBar(
          title: Text('Repository Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              onPressed: () async {
                final dio = ref.read(dioProvider);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await dio.post('/sync/all');
                  messenger.showSnackBar(
                    const SnackBar(content: Text('GitHub sync started in background!')),
                  );
                  ref.invalidate(projectDetailProvider(projectId));
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Sync failed: $e')),
                  );
                }
              },
            ),
            const SizedBox(width: 12),
          ],
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppTheme.primaryColor,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Branches'),
              Tab(text: 'Issues & PRs'),
              Tab(text: 'CI/CD Workflows'),
              Tab(text: 'Notes & Goals'),
            ],
          ),
        ),
        body: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error loading project: $err')),
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

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OverviewTab({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data['name'] ?? 'Repository',
                  style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
              Chip(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                label: Text(
                  data['status']?.toUpperCase() ?? 'ACTIVE',
                  style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(data['full_name'] ?? '', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          const SizedBox(height: 16),
          Text(
            data['description'] ?? 'No description provided for this repository.',
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InfoBadge(icon: Icons.star_rounded, label: 'Stars', value: '${data['stars'] ?? 0}'),
              _InfoBadge(icon: Icons.call_split_rounded, label: 'Forks', value: '${data['forks'] ?? 0}'),
              _InfoBadge(icon: Icons.code_rounded, label: 'Language', value: data['primary_language'] ?? 'Dart'),
              _InfoBadge(icon: Icons.alt_route_rounded, label: 'Default Branch', value: data['default_branch'] ?? 'main'),
            ],
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _BranchesTab extends StatelessWidget {
  final List<dynamic> branches;
  const _BranchesTab({required this.branches});

  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty) {
      return Center(
        child: Text('No branch intelligence synced yet.', style: TextStyle(color: Colors.grey.shade400)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: branches.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final b = branches[index];
        final isDefault = b['is_default'] ?? false;
        final isStale = b['is_stale'] ?? false;

        return Card(
          child: ListTile(
            leading: Icon(
              Icons.alt_route_rounded,
              color: isDefault ? AppTheme.primaryColor : Colors.grey,
            ),
            title: Text(b['name'] ?? 'branch', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            subtitle: Text(
              b['last_commit_at'] != null ? 'Last commit: ${b['last_commit_at']}' : 'Synced branch',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('DEFAULT', style: TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  ),
                if (isStale) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('STALE (>30d)', style: TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

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
          Text('Pull Requests (${pullRequests.length})', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (pullRequests.isEmpty)
            Text('No pull requests recorded.', style: TextStyle(color: Colors.grey.shade400))
          else
            ...pullRequests.map((pr) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.merge_type_rounded, color: AppTheme.secondaryColor),
                    title: Text('#${pr['github_pr_number']} ${pr['title']}'),
                    subtitle: Text('Author: ${pr['author'] ?? 'unknown'}'),
                    trailing: Chip(
                      label: Text(pr['state']?.toUpperCase() ?? 'OPEN'),
                    ),
                  ),
                )),
          const SizedBox(height: 28),
          Text('Issues (${issues.length})', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (issues.isEmpty)
            Text('No issues recorded.', style: TextStyle(color: Colors.grey.shade400))
          else
            ...issues.map((iss) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline_rounded, color: Colors.amberAccent),
                    title: Text('#${iss['github_issue_number']} ${iss['title']}'),
                    subtitle: Text('State: ${iss['state']}'),
                  ),
                )),
        ],
      ),
    );
  }
}

class _WorkflowsTab extends StatelessWidget {
  final List<dynamic> runs;
  const _WorkflowsTab({required this.runs});

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty) {
      return Center(
        child: Text('No GitHub Actions workflow runs found.', style: TextStyle(color: Colors.grey.shade400)),
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
              color: isSuccess ? AppTheme.secondaryColor : Colors.redAccent,
            ),
            title: Text(run['workflow_name'] ?? 'CI Workflow', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            subtitle: Text('Run #${run['run_number'] ?? ''} • Status: $status'),
          ),
        );
      },
    );
  }
}

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
              Text('Project Notes', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_rounded, color: AppTheme.primaryColor),
                onPressed: () => _showAddNoteDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (notes.isEmpty)
            Text('No notes added yet for this repository.', style: TextStyle(color: Colors.grey.shade400))
          else
            ...notes.map((n) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.notes_rounded, color: AppTheme.accentColor),
                    title: Text(n['content'] ?? ''),
                  ),
                )),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Project Goals', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_rounded, color: AppTheme.primaryColor),
                onPressed: () => _showAddGoalDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (goals.isEmpty)
            Text('No goals added yet.', style: TextStyle(color: Colors.grey.shade400))
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
