import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../../features/auth/auth_provider.dart';

/// Tracks the currently active nav index across the shell.
final shellNavIndexProvider = StateProvider<int>((ref) => 0);

/// Persistent GitHub-styled shell that wraps all authenticated screens.
/// On mobile (< 600px): bottom navigation bar + full-width content.
/// On desktop/tablet (>= 600px): left sidebar.
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _navItems = [
    _NavItem(label: 'Dashboard', icon: Icons.grid_view_rounded, route: '/dashboard'),
    _NavItem(label: 'All Repo', icon: Icons.source_rounded, route: '/projects'),
    _NavItem(label: 'Profile', icon: Icons.person_outline_rounded, route: '/description'),
    _NavItem(label: 'Settings', icon: Icons.settings_outlined, route: '/settings'),
  ];

  void _handleSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.canvasSubtle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.borderDefault),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppTheme.dangerRed, size: 20),
            const SizedBox(width: 10),
            Text(
              'Sign Out',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.fgDefault,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of Repo Dog?\nYour session will be closed.',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.fgMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.fgMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).signOut();
            },
            child: Text('Sign Out', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIndex = ref.watch(shellNavIndexProvider);
    final authState = ref.watch(authProvider);
    final username = authState.firebaseUser?.displayName ?? 'Developer';
    final photoUrl = authState.firebaseUser?.photoURL;
    final isMobile = MediaQuery.of(context).size.width < 600;

    void onNavTap(int index) {
      ref.read(shellNavIndexProvider.notifier).state = index;
      context.go(_navItems[index].route);
    }

    if (isMobile) {
      // ── Mobile Layout: Bottom Nav Bar + Full-Width Content ──────────────
      return Scaffold(
        backgroundColor: AppTheme.canvasDefault,
        // ── Mobile App Bar ───────────────────────────────────────────────
        appBar: AppBar(
          backgroundColor: AppTheme.canvasSubtle,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.pets_rounded, color: AppTheme.accentBlue, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'Repo Dog',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.fgDefault,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _handleSignOut(context, ref),
                child: _Avatar(photoUrl: photoUrl, username: username, size: 32),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.borderDefault),
          ),
        ),
        // ── Content ───────────────────────────────────────────────────────
        body: child,
        // ── Bottom Navigation Bar ─────────────────────────────────────────
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppTheme.canvasSubtle,
            border: Border(top: BorderSide(color: AppTheme.borderDefault, width: 1)),
          ),
          child: SafeArea(
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.accentBlue,
              unselectedItemColor: AppTheme.fgMuted,
              selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
              currentIndex: activeIndex,
              onTap: onNavTap,
              items: _navItems.map((item) => BottomNavigationBarItem(
                icon: Icon(item.icon, size: 22),
                label: item.label,
              )).toList(),
            ),
          ),
        ),
      );
    }

    // ── Desktop/Tablet Layout: Sidebar + Content ─────────────────────────
    return Scaffold(
      backgroundColor: AppTheme.canvasDefault,
      body: Row(
        children: [
          _Sidebar(
            activeIndex: activeIndex,
            navItems: _navItems,
            username: username,
            photoUrl: photoUrl,
            onNavTap: onNavTap,
            onSignOut: () => _handleSignOut(context, ref),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─── Sidebar (Desktop Only) ──────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final int activeIndex;
  final List<_NavItem> navItems;
  final String username;
  final String? photoUrl;
  final ValueChanged<int> onNavTap;
  final VoidCallback onSignOut;

  const _Sidebar({
    required this.activeIndex,
    required this.navItems,
    required this.username,
    required this.photoUrl,
    required this.onNavTap,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      decoration: const BoxDecoration(
        color: AppTheme.canvasSubtle,
        border: Border(right: BorderSide(color: AppTheme.borderDefault, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.4), width: 1),
                  ),
                  child: const Icon(Icons.pets_rounded, color: AppTheme.accentBlue, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  'Repo Dog',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.fgDefault,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderDefault),
          const SizedBox(height: 8),

          ...List.generate(navItems.length - 1, (i) => _SidebarNavTile(
            item: navItems[i],
            isActive: activeIndex == i,
            onTap: () => onNavTap(i),
          )),

          const Spacer(),
          const Divider(height: 1, color: AppTheme.borderDefault),
          const SizedBox(height: 8),

          _SidebarNavTile(
            item: navItems.last,
            isActive: activeIndex == navItems.length - 1,
            onTap: () => onNavTap(navItems.length - 1),
          ),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.borderDefault, width: 1)),
            ),
            child: Row(
              children: [
                _Avatar(photoUrl: photoUrl, username: username, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    username,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.fgDefault),
                  ),
                ),
                GestureDetector(
                  onTap: onSignOut,
                  child: const Icon(Icons.logout_rounded, size: 15, color: AppTheme.fgMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar Nav Tile ────────────────────────────────────────────────────────

class _SidebarNavTile extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarNavTile({required this.item, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accentBlue.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive ? Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.25), width: 1) : null,
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 16, color: isActive ? AppTheme.accentBlue : AppTheme.fgMuted),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppTheme.fgDefault : AppTheme.fgMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Avatar Widget ────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String username;
  final double size;

  const _Avatar({required this.photoUrl, required this.username, required this.size});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.accentBlue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: AppTheme.borderDefault, width: 1),
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : 'U',
          style: GoogleFonts.outfit(
            fontSize: size * 0.45,
            fontWeight: FontWeight.bold,
            color: AppTheme.accentBlue,
          ),
        ),
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem({required this.label, required this.icon, required this.route});
}
