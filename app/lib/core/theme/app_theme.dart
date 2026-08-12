import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── GitHub Dark Palette ───────────────────────────────────────────────────
  /// Canvas default — main background
  static const Color canvasDefault = Color(0xFF0D1117);

  /// Canvas subtle — sidebar & header background
  static const Color canvasSubtle = Color(0xFF161B22);

  /// Canvas overlay — cards / elevated surfaces
  static const Color canvasOverlay = Color(0xFF1C2128);

  /// Border default
  static const Color borderDefault = Color(0xFF30363D);

  /// Border muted
  static const Color borderMuted = Color(0xFF21262D);

  /// Foreground default — primary text
  static const Color fgDefault = Color(0xFFE6EDF3);

  /// Foreground muted — secondary / hint text
  static const Color fgMuted = Color(0xFF8B949E);

  /// Foreground subtle
  static const Color fgSubtle = Color(0xFF6E7681);

  /// Accent blue (links, active states)
  static const Color accentBlue = Color(0xFF58A6FF);

  /// Success green (contributions, success CI)
  static const Color successGreen = Color(0xFF3FB950);

  /// Danger red (failing CI)
  static const Color dangerRed = Color(0xFFF85149);

  /// Warning amber (branches)
  static const Color warningAmber = Color(0xFFD29922);

  /// Open PR purple
  static const Color openPrColor = Color(0xFF8957E5);

  /// Welcome banner gradient
  static const Color bannerStart = Color(0xFF6E40C9);
  static const Color bannerEnd = Color(0xFF4F3BA8);

  // ─── Legacy aliases (used in other screens) ────────────────────────────────
  static const Color primaryColor = accentBlue;
  static const Color secondaryColor = successGreen;
  static const Color accentColor = warningAmber;
  static const Color darkBackground = canvasDefault;
  static const Color darkCardBackground = canvasSubtle;
  static const Color surfaceBorder = borderDefault;

  // ─── Contribution Heatmap greens ──────────────────────────────────────────
  static const List<Color> heatmapLevels = [
    Color(0xFF161B22), // level 0 — no contribution
    Color(0xFF0E4429), // level 1
    Color(0xFF006D32), // level 2
    Color(0xFF26A641), // level 3
    Color(0xFF39D353), // level 4
  ];

  // ─── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: canvasDefault,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: successGreen,
        tertiary: warningAmber,
        surface: canvasSubtle,
        onSurface: fgDefault,
        outline: borderDefault,
      ),
      cardTheme: CardThemeData(
        color: canvasSubtle,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: borderDefault, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderDefault,
        thickness: 1,
        space: 0,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineMedium: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: fgDefault,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: fgDefault,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: fgDefault,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: fgMuted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvasSubtle,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: fgDefault,
        ),
        iconTheme: const IconThemeData(color: fgMuted),
        shape: const Border(
          bottom: BorderSide(color: borderDefault, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF238636),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: Color(0xFF2EA043), width: 1),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fgDefault,
          side: const BorderSide(color: borderDefault, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: fgMuted,
        textColor: fgDefault,
      ),
      iconTheme: const IconThemeData(color: fgMuted, size: 16),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: canvasDefault,
        hintStyle: const TextStyle(color: fgSubtle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: accentBlue, width: 2),
        ),
      ),
    );
  }
}
