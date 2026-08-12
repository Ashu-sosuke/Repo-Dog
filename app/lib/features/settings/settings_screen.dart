import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/layout/app_shell.dart';
import '../auth/auth_provider.dart';

// ── Settings State ────────────────────────────────────────────────────────────

class SettingsState {
  final String autoSyncInterval;
  final bool showPrivateContribs;
  final bool showHeatmapOnDashboard;
  final String defaultRepoSort;
  final int staleBranchDays;
  final String themeVariant;

  const SettingsState({
    this.autoSyncInterval = 'Every 1 Hour',
    this.showPrivateContribs = true,
    this.showHeatmapOnDashboard = true,
    this.defaultRepoSort = 'Last Updated',
    this.staleBranchDays = 30,
    this.themeVariant = 'GitHub Dark',
  });

  SettingsState copyWith({
    String? autoSyncInterval,
    bool? showPrivateContribs,
    bool? showHeatmapOnDashboard,
    String? defaultRepoSort,
    int? staleBranchDays,
    String? themeVariant,
  }) {
    return SettingsState(
      autoSyncInterval: autoSyncInterval ?? this.autoSyncInterval,
      showPrivateContribs: showPrivateContribs ?? this.showPrivateContribs,
      showHeatmapOnDashboard: showHeatmapOnDashboard ?? this.showHeatmapOnDashboard,
      defaultRepoSort: defaultRepoSort ?? this.defaultRepoSort,
      staleBranchDays: staleBranchDays ?? this.staleBranchDays,
      themeVariant: themeVariant ?? this.themeVariant,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void setAutoSyncInterval(String val) => state = state.copyWith(autoSyncInterval: val);
  void toggleShowPrivateContribs(bool val) => state = state.copyWith(showPrivateContribs: val);
  void toggleShowHeatmap(bool val) => state = state.copyWith(showHeatmapOnDashboard: val);
  void setDefaultRepoSort(String val) => state = state.copyWith(defaultRepoSort: val);
  void setStaleBranchDays(int val) => state = state.copyWith(staleBranchDays: val);
  void setThemeVariant(String val) => state = state.copyWith(themeVariant: val);
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

// API Status Provider
final apiStatusProvider = FutureProvider<bool>((ref) async {
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/');
    return response.statusCode == 200 && response.data['status'] == 'healthy';
  } catch (_) {
    return false;
  }
});

// ── Settings Screen ───────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shellNavIndexProvider.notifier).state = 3;
    });
  }

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    final dio = ref.read(dioProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await dio.post('/sync/all');
      final msg = response.data['message'] ?? 'Sync started successfully!';
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.successGreen.withValues(alpha: 0.15),
          content: Text(
            '⚡ $msg',
            style: GoogleFonts.inter(color: AppTheme.successGreen, fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.dangerRed.withValues(alpha: 0.15),
          content: Text('Sync failed: $e', style: GoogleFonts.inter(color: AppTheme.dangerRed)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final authState = ref.watch(authProvider);
    final apiHealthAsync = ref.watch(apiStatusProvider);

    final user = authState.firebaseUser;
    final username = user?.displayName ?? user?.email?.split('@').first ?? 'Developer';

    return Scaffold(
      backgroundColor: AppTheme.canvasDefault,
      body: Column(
        children: [
          // ── Top Header ──────────────────────────────────────────────────
          Builder(
            builder: (context) {
              final isMobile = MediaQuery.of(context).size.width < 600;
              return Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppTheme.canvasSubtle,
                  border: Border(bottom: BorderSide(color: AppTheme.borderDefault, width: 1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, size: 18, color: AppTheme.accentBlue),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Workspace Settings & Preferences',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 15 : 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.fgDefault,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // API Status Indicator
                    apiHealthAsync.when(
                      data: (isHealthy) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isHealthy
                              ? AppTheme.successGreen.withValues(alpha: 0.15)
                              : AppTheme.dangerRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isHealthy ? AppTheme.successGreen : AppTheme.dangerRed,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isHealthy ? AppTheme.successGreen : AppTheme.dangerRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isHealthy ? 'API Online' : 'API Offline',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isHealthy ? AppTheme.successGreen : AppTheme.dangerRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, s) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Settings Form View ──────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // ── Section 1: GitHub Connection & Sync ─────────────────
                _SectionHeader(title: 'GitHub Integration & Live Sync'),
                const SizedBox(height: 12),
                _SettingsCard(
                  child: Column(
                    children: [
                      // Connected Account Tile
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderDefault),
                          ),
                          child: const Icon(Icons.account_tree_rounded, size: 20, color: AppTheme.accentBlue),
                        ),
                        title: Text(
                          username,
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.fgDefault),
                        ),
                        subtitle: Text(
                          'OAuth Token encrypted with Fernet AES-256',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'CONNECTED',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.successGreen),
                          ),
                        ),
                      ),
                      const Divider(color: AppTheme.borderDefault, height: 24),

                      // Manual Sync Trigger Button
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Force GitHub Re-Sync Now',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.fgDefault),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Fetches latest repos, commits, branches, PRs & GraphQL contributions.',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: _isSyncing ? null : _triggerManualSync,
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.sync_rounded, size: 16),
                            label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                          ),
                        ],
                      ),
                      const Divider(color: AppTheme.borderDefault, height: 24),

                      // Auto-Sync Interval Dropdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Background Sync Frequency',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.fgDefault),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'How often Repo Dog polls GitHub for changes.',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.canvasDefault,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.borderDefault),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: settings.autoSyncInterval,
                                dropdownColor: AppTheme.canvasOverlay,
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgDefault),
                                items: ['Every 15 Mins', 'Every 1 Hour', 'Every 6 Hours', 'Manual Only']
                                    .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) settingsNotifier.setAutoSyncInterval(v);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Section 2: Dashboard & Heatmap Preferences ──────────
                _SectionHeader(title: 'Dashboard & Display Preferences'),
                const SizedBox(height: 12),
                _SettingsCard(
                  child: Column(
                    children: [
                      // Private Contributions Toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Include Private Contributions',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.fgDefault),
                        ),
                        subtitle: Text(
                          'Counts commits & activity from private repositories in the contribution heatmap.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted),
                        ),
                        activeTrackColor: AppTheme.accentBlue,
                        value: settings.showPrivateContribs,
                        onChanged: (val) => settingsNotifier.toggleShowPrivateContribs(val),
                      ),
                      const Divider(color: AppTheme.borderDefault, height: 16),

                      // Heatmap Visible Toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Show Contribution Heatmap',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.fgDefault),
                        ),
                        subtitle: Text(
                          'Display the 53-week GitHub green commit calendar on the main dashboard.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted),
                        ),
                        activeTrackColor: AppTheme.accentBlue,
                        value: settings.showHeatmapOnDashboard,
                        onChanged: (val) => settingsNotifier.toggleShowHeatmap(val),
                      ),
                      const Divider(color: AppTheme.borderDefault, height: 16),

                      // Default Repo Sort Dropdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Default Repository Sort Order',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.fgDefault),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Initial sorting for your repositories list.',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.canvasDefault,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.borderDefault),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: settings.defaultRepoSort,
                                dropdownColor: AppTheme.canvasOverlay,
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgDefault),
                                items: ['Last Updated', 'Stars Count', 'Name Alphabetical']
                                    .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) settingsNotifier.setDefaultRepoSort(v);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Section 3: Branch Intelligence Rules ────────────────
                _SectionHeader(title: 'Branch Intelligence Rules'),
                const SizedBox(height: 12),
                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Stale Branch Threshold',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.fgDefault),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Flag branches without commits for more than ${settings.staleBranchDays} days as STALE.',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.warningAmber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.warningAmber.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '${settings.staleBranchDays} Days',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.warningAmber),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: settings.staleBranchDays.toDouble(),
                        min: 7,
                        max: 90,
                        divisions: 8,
                        activeColor: AppTheme.warningAmber,
                        inactiveColor: AppTheme.borderDefault,
                        onChanged: (val) => settingsNotifier.setStaleBranchDays(val.toInt()),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Section 4: Account Session ─────────────────────────
                _SectionHeader(title: 'Account Session'),
                const SizedBox(height: 12),
                _SettingsCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sign Out',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.fgDefault),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sign out of your active Repo Dog workspace session.',
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.dangerRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppTheme.canvasSubtle,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: AppTheme.borderDefault),
                              ),
                              title: Row(
                                children: [
                                  const Icon(Icons.logout_rounded, color: AppTheme.dangerRed, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Sign Out Confirmation',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.fgDefault,
                                    ),
                                  ),
                                ],
                              ),
                              content: Text(
                                'Are you sure you want to sign out of Repo Dog?\nYour active workspace session will be closed.',
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
                                  child: Text(
                                    'Sign Out',
                                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── App Footer Info ─────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Repo Dog v1.0.0 (Build 2026.08)',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.fgMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'FastAPI Backend Base: ${ApiConstants.baseUrl}',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.fgSubtle),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-Widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.fgDefault,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.canvasSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDefault, width: 1),
      ),
      child: child,
    );
  }
}
