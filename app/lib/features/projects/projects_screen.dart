import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/layout/app_shell.dart';

final projectsListProvider = FutureProvider<List<dynamic>>((ref) async {
  ref.keepAlive();
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiConstants.projects);
  return (response.data['projects'] as List?) ?? [];
});

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String _searchQuery = '';
  String _selectedType = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shellNavIndexProvider.notifier).state = 1;
    });
  }

  static const _langColors = <String, Color>{
    'JavaScript': Color(0xFFF1E05A),
    'TypeScript': Color(0xFF3178C6),
    'Python': Color(0xFF3572A5),
    'Dart': Color(0xFF00B4AB),
    'Go': Color(0xFF00ADD8),
    'Java': Color(0xFFB07219),
    'Kotlin': Color(0xFFA97BFF),
    'Swift': Color(0xFFFA7343),
    'C++': Color(0xFF178600),
    'C#': Color(0xFF178600),
    'PHP': Color(0xFF4F5D95),
    'Ruby': Color(0xFF701516),
    'Rust': Color(0xFFDEA584),
    'HTML': Color(0xFFE34C26),
    'CSS': Color(0xFF563D7C),
    'Shell': Color(0xFF89E051),
  };

  Color _langColor(String lang) => _langColors[lang] ?? AppTheme.fgSubtle;

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsListProvider);

    return Scaffold(
      backgroundColor: AppTheme.canvasDefault,
      body: Column(
        children: [
          // ── Top Bar (Header with Search & Filter) ────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.canvasSubtle,
              border: Border(bottom: BorderSide(color: AppTheme.borderDefault, width: 1)),
            ),
            child: Row(
              children: [
                Text(
                  'Repositories',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.fgDefault,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.borderDefault,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: projectsAsync.when(
                    data: (p) => Text(
                      '${p.length}',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.fgDefault),
                    ),
                    loading: () => const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.fgMuted),
                    ),
                    error: (err, stack) => const SizedBox.shrink(),
                  ),
                ),
                const Spacer(),
                // Filter Dropdown
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.canvasDefault,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderDefault),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedType,
                      dropdownColor: AppTheme.canvasOverlay,
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgDefault),
                      icon: const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.fgMuted),
                      items: ['All', 'Public', 'Private', 'Starred'].map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Search Input
                SizedBox(
                  width: 240,
                  height: 32,
                  child: TextField(
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.fgDefault),
                    decoration: InputDecoration(
                      hintText: 'Find a repository…',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgSubtle),
                      prefixIcon: const Icon(Icons.search, size: 14, color: AppTheme.fgSubtle),
                      filled: true,
                      fillColor: AppTheme.canvasDefault,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.borderDefault),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.borderDefault),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.accentBlue, width: 2),
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 10),
                // Refresh Button
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => ref.refresh(projectsListProvider),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.canvasDefault,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderDefault),
                    ),
                    child: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.fgMuted),
                  ),
                ),
              ],
            ),
          ),

          // ── Repo List View ───────────────────────────────────────────
          Expanded(
            child: projectsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accentBlue, strokeWidth: 2),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      'Error loading repositories',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.fgDefault,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('$err', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted)),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => ref.refresh(projectsListProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (projects) {
                // Apply type and search filtering
                final filtered = projects.where((p) {
                  final name = (p['name'] ?? '').toString().toLowerCase();
                  final desc = (p['description'] ?? '').toString().toLowerCase();
                  final isPrivate = p['is_private'] == true || p['private'] == true;
                  final stars = p['stars'] ?? p['stargazers_count'] ?? 0;

                  if (_selectedType == 'Public' && isPrivate) return false;
                  if (_selectedType == 'Private' && !isPrivate) return false;
                  if (_selectedType == 'Starred' && stars <= 0) return false;

                  if (_searchQuery.isNotEmpty) {
                    return name.contains(_searchQuery) || desc.contains(_searchQuery);
                  }
                  return true;
                }).toList();

                if (projects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.canvasSubtle,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: AppTheme.borderDefault),
                          ),
                          child: const Icon(Icons.folder_off_rounded, size: 28, color: AppTheme.fgSubtle),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No repositories synced yet',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.fgDefault,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Trigger GitHub Sync on the Dashboard to import your projects.',
                          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.fgMuted),
                        ),
                      ],
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No repositories match your filter.',
                      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.fgMuted),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: filtered.length,
                  separatorBuilder: (context2, idx) => const Divider(
                    color: AppTheme.borderMuted,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final lang = item['primary_language'] ?? item['language'] ?? '';
                    return _RepoListItem(
                      repo: item,
                      langColor: _langColor(lang),
                      onTap: () => context.go('/projects/${item['id']}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Repo List Item ───────────────────────────────────────────────────────────

class _RepoListItem extends StatefulWidget {
  final dynamic repo;
  final Color langColor;
  final VoidCallback onTap;

  const _RepoListItem({
    required this.repo,
    required this.langColor,
    required this.onTap,
  });

  @override
  State<_RepoListItem> createState() => _RepoListItemState();
}

class _RepoListItemState extends State<_RepoListItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.repo['name'] ?? 'Repository';
    final fullName = widget.repo['full_name'] ?? '';
    final desc = widget.repo['description'] ?? 'No description provided';
    final stars = widget.repo['stars'] ?? widget.repo['stargazers_count'] ?? 0;
    final forks = widget.repo['forks_count'] ?? widget.repo['forks'] ?? 0;
    final language = widget.repo['primary_language'] ?? widget.repo['language'] ?? '';
    final isPrivate = widget.repo['is_private'] == true || widget.repo['private'] == true;
    final updatedAt = widget.repo['last_synced_at'] ?? widget.repo['updated_at'] ?? '';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.canvasSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Repo icon container
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(top: 2, right: 14),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderDefault),
                ),
                child: const Icon(Icons.source_rounded, size: 18, color: AppTheme.accentBlue),
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Public/Private Badge
                    Row(
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentBlue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Badge(label: isPrivate ? 'Private' : 'Public'),
                      ],
                    ),
                    if (fullName.isNotEmpty && fullName != name) ...[
                      const SizedBox(height: 2),
                      Text(
                        fullName,
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.fgSubtle),
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Description
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.fgMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Language, Stars, Forks, Updated relative time
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (language.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: widget.langColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                language,
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted),
                              ),
                            ],
                          ),
                        _MetaChip(
                          icon: Icons.star_rounded,
                          iconColor: stars > 0 ? AppTheme.warningAmber : AppTheme.fgMuted,
                          label: '$stars',
                        ),
                        _MetaChip(
                          icon: Icons.call_split_rounded,
                          iconColor: AppTheme.fgMuted,
                          label: '$forks',
                        ),
                        if (updatedAt.isNotEmpty)
                          Text(
                            _relativeDate(updatedAt),
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Star Action Button
              const SizedBox(width: 16),
              _GhButton(
                icon: stars > 0 ? Icons.star_rounded : Icons.star_outline_rounded,
                iconColor: stars > 0 ? AppTheme.warningAmber : AppTheme.fgMuted,
                label: stars > 0 ? 'Starred' : 'Star',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
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
      return iso;
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    final isPrivate = label == 'Private';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrivate ? AppTheme.warningAmber.withValues(alpha: 0.5) : AppTheme.borderDefault,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: isPrivate ? AppTheme.warningAmber : AppTheme.fgMuted,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  const _MetaChip({required this.icon, required this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted)),
      ],
    );
  }
}

class _GhButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _GhButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  State<_GhButton> createState() => _GhButtonState();
}

class _GhButtonState extends State<_GhButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.canvasOverlay : AppTheme.canvasSubtle,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderDefault),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 13, color: widget.iconColor),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.fgDefault,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
