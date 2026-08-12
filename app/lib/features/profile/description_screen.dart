import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/layout/app_shell.dart';

final userDescriptionProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.keepAlive();
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiConstants.userDescription);
  return response.data ?? {};
});

class DescriptionScreen extends ConsumerStatefulWidget {
  const DescriptionScreen({super.key});

  @override
  ConsumerState<DescriptionScreen> createState() => _DescriptionScreenState();
}

class _DescriptionScreenState extends ConsumerState<DescriptionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shellNavIndexProvider.notifier).state = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userDescriptionProvider);

    return Scaffold(
      backgroundColor: AppTheme.canvasDefault,
      body: Column(
        children: [
          // ── Top Bar ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              color: AppTheme.canvasSubtle,
              border: Border(bottom: BorderSide(color: AppTheme.borderDefault, width: 1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.accentBlue),
                const SizedBox(width: 10),
                Text(
                  'User Profile & Description',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.fgDefault,
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => ref.refresh(userDescriptionProvider),
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

          // ── Main Content View ────────────────────────────────────────────
          Expanded(
            child: userAsync.when(
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
                      'Error loading user profile',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.fgDefault),
                    ),
                    const SizedBox(height: 6),
                    Text('$err', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted)),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => ref.refresh(userDescriptionProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (user) {
                final login = user['login'] ?? user['github_username'] ?? 'User';
                final name = user['name'] ?? login;
                final bio = user['bio'] ?? 'No bio provided.';
                final avatarUrl = user['avatar_url'] ?? '';
                final blog = user['blog'] as String?;
                final location = user['location'] as String?;
                final company = user['company'] as String?;
                final twitter = user['twitter_username'] as String?;
                final htmlUrl = user['html_url'] ?? 'https://github.com/$login';
                final followers = user['followers'] ?? 0;
                final following = user['following'] ?? 0;
                final publicRepos = user['public_repos'] ?? 0;
                final profileReadme = user['profile_readme'] as String?;

                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // ── Profile Header Card ──────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.canvasSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderDefault, width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: AppTheme.borderDefault,
                                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl.isEmpty
                                    ? Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                        style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.fgDefault),
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: AppTheme.successGreen,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.canvasSubtle, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),

                          // User info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.fgDefault,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '@$login',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: AppTheme.fgMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  bio,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AppTheme.fgDefault,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Stats row
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 6,
                                  children: [
                                    _StatChip(icon: Icons.people_outline_rounded, label: '$followers followers'),
                                    _StatChip(icon: Icons.person_add_alt_rounded, label: '$following following'),
                                    _StatChip(icon: Icons.source_rounded, label: '$publicRepos public repos'),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // User Links Bar
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    _LinkButton(
                                      icon: Icons.open_in_new_rounded,
                                      label: 'GitHub Profile',
                                      url: htmlUrl,
                                    ),
                                    if (blog != null && blog.isNotEmpty)
                                      _LinkButton(
                                        icon: Icons.link_rounded,
                                        label: blog,
                                        url: blog.startsWith('http') ? blog : 'https://$blog',
                                      ),
                                    if (twitter != null && twitter.isNotEmpty)
                                      _LinkButton(
                                        icon: Icons.alternate_email_rounded,
                                        label: '@$twitter',
                                        url: 'https://x.com/$twitter',
                                      ),
                                    if (location != null && location.isNotEmpty)
                                      _InfoChip(icon: Icons.location_on_outlined, label: location),
                                    if (company != null && company.isNotEmpty)
                                      _InfoChip(icon: Icons.business_rounded, label: company),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── GitHub Profile README Card ─────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.canvasSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderDefault, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Header
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
                                const Icon(Icons.menu_book_rounded, size: 16, color: AppTheme.accentBlue),
                                const SizedBox(width: 8),
                                Text(
                                  '$login / README.md',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.fgDefault,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentBlue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'Profile README',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: AppTheme.accentBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Card Body (Markdown Renderer)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: (profileReadme != null && profileReadme.trim().isNotEmpty)
                                ? MarkdownBody(
                                    data: profileReadme,
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
                                    padding: const EdgeInsets.symmetric(vertical: 32),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          const Icon(Icons.description_outlined, size: 36, color: AppTheme.fgSubtle),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No Profile README found.',
                                            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.fgMuted),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Create a public repository named $login with a README.md to show your profile here.',
                                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgSubtle),
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
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.fgMuted),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.canvasDefault,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.fgMuted),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted)),
        ],
      ),
    );
  }
}

class _LinkButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String url;
  const _LinkButton({required this.icon, required this.label, required this.url});

  @override
  State<_LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<_LinkButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          // Open URL in external window / tab
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening: ${widget.url}'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.accentBlue.withValues(alpha: 0.15) : AppTheme.canvasDefault,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _hovered ? AppTheme.accentBlue : AppTheme.borderDefault,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 13, color: AppTheme.accentBlue),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.accentBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
