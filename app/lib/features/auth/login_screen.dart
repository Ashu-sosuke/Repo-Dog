import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_provider.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _btnHovered = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.canvasDefault,
      body: Stack(
        children: [
          // ── Background Ambient Glow & Radial Lighting ──────────────────────
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentBlue.withValues(alpha: 0.08),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.successGreen.withValues(alpha: 0.06),
                    blurRadius: 120,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          // ── Main Card Centered View ────────────────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(36),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: AppTheme.canvasSubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderDefault, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentBlue.withValues(alpha: 0.08),
                      blurRadius: 40,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logo Container ─────────────────────────────────────
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.accentBlue, AppTheme.successGreen],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentBlue.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.source_rounded,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title & Description
                    Text(
                      'Repo Dog',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.fgDefault,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Unified GitHub Activity Dashboard & Developer Workspace',
                      style: GoogleFonts.inter(
                        color: AppTheme.fgMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Error Notification if any
                    if (authState.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.dangerRed),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authState.errorMessage!,
                                style: GoogleFonts.inter(color: AppTheme.dangerRed, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── GitHub Sign-In Button ──────────────────────────────
                    MouseRegion(
                      onEnter: (_) => setState(() => _btnHovered = true),
                      onExit: (_) => setState(() => _btnHovered = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _btnHovered
                              ? [
                                  BoxShadow(
                                    color: AppTheme.accentBlue.withValues(alpha: 0.25),
                                    blurRadius: 14,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: authState.isLoading
                              ? null
                              : () => ref.read(authProvider.notifier).signInWithGitHub(),
                          icon: authState.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.code_rounded, color: Colors.white, size: 20),
                          label: Text(
                            authState.isLoading ? 'Authenticating with GitHub...' : 'Sign in with GitHub',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF24292E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: _btnHovered ? AppTheme.accentBlue : AppTheme.borderDefault,
                                width: 1,
                              ),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Divider ────────────────────────────────────────────
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppTheme.borderDefault)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'HOW TO GET STARTED',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.fgSubtle,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: AppTheme.borderDefault)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Directions & Usage Guide Section ───────────────────
                    _DirectionStep(
                      stepNumber: '1',
                      icon: Icons.vpn_key_outlined,
                      title: '1-Click OAuth Sign-In',
                      description: 'Authenticate securely using your GitHub account via Firebase OAuth 2.0.',
                    ),
                    const SizedBox(height: 14),
                    _DirectionStep(
                      stepNumber: '2',
                      icon: Icons.sync_rounded,
                      title: 'Automated GitHub Sync',
                      description: 'Repo Dog imports your repos, PRs, CI runs, and 53-week GraphQL contribution heatmap.',
                    ),
                    const SizedBox(height: 14),
                    _DirectionStep(
                      stepNumber: '3',
                      icon: Icons.dashboard_customize_outlined,
                      title: 'Explore Workspace Intelligence',
                      description: 'View formatted repository READMEs, stale branch warnings, and custom project goals.',
                    ),

                    const SizedBox(height: 28),
                    const Divider(color: AppTheme.borderMuted),
                    const SizedBox(height: 16),

                    // ── Security Trust Chips ───────────────────────────────
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: const [
                        _TrustChip(icon: Icons.lock_outline_rounded, label: 'Fernet AES-256 Encrypted'),
                        _TrustChip(icon: Icons.flash_on_rounded, label: '<3ms In-Memory Cache'),
                        _TrustChip(icon: Icons.verified_user_outlined, label: 'Read-Only Token Access'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Direction Step Item Widget ───────────────────────────────────────────────

class _DirectionStep extends StatelessWidget {
  final String stepNumber;
  final IconData icon;
  final String title;
  final String description;

  const _DirectionStep({
    required this.stepNumber,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.canvasOverlay,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderDefault),
          ),
          child: Center(
            child: Icon(icon, size: 16, color: AppTheme.accentBlue),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.fgDefault,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.fgMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Trust Chip Widget ────────────────────────────────────────────────────────

class _TrustChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.fgSubtle),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.fgSubtle),
        ),
      ],
    );
  }
}
