import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'auth_provider.dart';

class SyncLoadingScreen extends ConsumerStatefulWidget {
  const SyncLoadingScreen({super.key});

  @override
  ConsumerState<SyncLoadingScreen> createState() => _SyncLoadingScreenState();
}

class _SyncLoadingScreenState extends ConsumerState<SyncLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnim;
  late Animation<double> _rotateAnim;
  late Animation<double> _fadeAnim;

  final List<_SyncStep> _steps = [
    _SyncStep(icon: Icons.lock_rounded, label: 'Authenticating with GitHub'),
    _SyncStep(icon: Icons.cloud_download_rounded, label: 'Fetching repositories'),
    _SyncStep(icon: Icons.call_split_rounded, label: 'Syncing branches'),
    _SyncStep(icon: Icons.commit_rounded, label: 'Importing commits'),
    _SyncStep(icon: Icons.merge_type_rounded, label: 'Loading pull requests'),
    _SyncStep(icon: Icons.play_circle_rounded, label: 'Syncing CI/CD workflows'),
  ];

  int _currentStep = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _rotateAnim = Tween<double>(begin: 0, end: 1).animate(_rotateController);
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    // Animate through steps to match the backend sync phases
    _animateSteps();
  }

  void _animateSteps() async {
    final delays = [800, 1200, 2000, 2800, 3600, 4200];
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(Duration(milliseconds: delays[i]));
      if (mounted) {
        setState(() => _currentStep = i);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final username = authState.firebaseUser?.displayName ?? 'Developer';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E1B4B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing logo with rotating ring
                  _buildAnimatedLogo(),
                  const SizedBox(height: 40),

                  // Title
                  Text(
                    'Setting up your workspace',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Syncing GitHub activity for $username',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Step list
                  _buildStepList(),
                  const SizedBox(height: 40),

                  // Status message from backend
                  if (authState.syncMessage != null)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Container(
                        key: ValueKey(authState.syncMessage),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryColor.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              authState.syncMessage!,
                              style: GoogleFonts.inter(
                                color: AppTheme.primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating gradient ring
          RotationTransition(
            turns: _rotateAnim,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.0),
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                    AppTheme.secondaryColor.withValues(alpha: 0.6),
                    AppTheme.primaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Pulsing inner logo
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(41),
                child: Image.asset(
                  'assets/logo.png',
                  width: 82,
                  height: 82,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkCardBackground.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        children: List.generate(_steps.length, (index) {
          final isDone = index < _currentStep;
          final isActive = index == _currentStep;

          return Padding(
            padding: EdgeInsets.only(
                bottom: index < _steps.length - 1 ? 16 : 0),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: isDone || isActive ? 1.0 : 0.3,
              child: Row(
                children: [
                  // Status icon
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? AppTheme.secondaryColor.withValues(alpha: 0.2)
                          : isActive
                              ? AppTheme.primaryColor.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: isDone
                            ? AppTheme.secondaryColor
                            : isActive
                                ? AppTheme.primaryColor
                                : AppTheme.surfaceBorder,
                        width: 1.5,
                      ),
                    ),
                    child: isDone
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: AppTheme.secondaryColor)
                        : isActive
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              )
                            : Icon(_steps[index].icon,
                                size: 14, color: AppTheme.surfaceBorder),
                  ),
                  const SizedBox(width: 14),
                  // Label
                  Expanded(
                    child: Text(
                      _steps[index].label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDone
                            ? AppTheme.secondaryColor
                            : isActive
                                ? Colors.white
                                : Colors.grey.shade600,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  // Done badge
                  if (isDone)
                    Text(
                      'Done',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SyncStep {
  final IconData icon;
  final String label;
  const _SyncStep({required this.icon, required this.label});
}
