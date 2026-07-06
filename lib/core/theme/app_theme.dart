import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  PREMIUM ENTERPRISE COLOR SYSTEM
// ─────────────────────────────────────────────────────────────

class XiomiColors {
  const XiomiColors._();

  // ── Primary Palette ──────────────────────────────────────
  static const primaryPurple = Color(0xFF6B3FA0);
  static const primaryPurpleLight = Color(0xFF8B6BC4);
  static const primaryPurpleDark = Color(0xFF4A2D73);

  // ── Secondary / Accent ───────────────────────────────────
  static const aquaBlue = Color(0xFF3BA3C8);
  static const aquaLight = Color(0xFF5EC4E2);
  static const lightCyan = Color(0xFF93DBF5);

  // ── Surface tints ────────────────────────────────────────
  static const iceLilac = Color(0xFFEDE6F5);
  static const pinkLilac = Color(0xFFDDB8F0);
  static const coldWhite = Color(0xFFF7F8FA);
  static const surfaceCard = Color(0xFFFFFFFF);

  // ── Semantic ─────────────────────────────────────────────
  static const success = Color(0xFF16A085);
  static const successLight = Color(0xFFE8F8F5);
  static const warning = Color(0xFFE67E22);
  static const warningLight = Color(0xFFFDF2E9);
  static const error = Color(0xFFE74C3C);
  static const errorLight = Color(0xFFFDEDEC);
  static const info = Color(0xFF2980B9);
  static const infoLight = Color(0xFFEBF5FB);

  // ── Neutral ──────────────────────────────────────────────
  static const ink = Color(0xFF1A1D26);
  static const inkSecondary = Color(0xFF3D4355);
  static const muted = Color(0xFF6E7687);
  static const mutedLight = Color(0xFF9BA3B5);
  static const border = Color(0xFFE2E6EE);
  static const borderLight = Color(0xFFF0F2F7);
  static const divider = Color(0xFFEBEDF2);

  // ── Gradients ────────────────────────────────────────────
  static const splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6B3FA0), Color(0xFF3BA3C8)],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7B52B8), Color(0xFF4ABDE0)],
  );

  static const subtleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF7F8FA), Color(0xFFEDE6F5)],
  );

  // ── Shadows ──────────────────────────────────────────────
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF6B3FA0).withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: const Color(0xFF6B3FA0).withValues(alpha: 0.12),
      blurRadius: 28,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: const Color(0xFF6B3FA0).withValues(alpha: 0.30),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────
//  SPACING CONSTANTS
// ─────────────────────────────────────────────────────────────

class XiomiSpacing {
  const XiomiSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const double screenH = 20;
  static const double screenV = 20;

  static const EdgeInsets screenPadding = EdgeInsets.fromLTRB(20, 20, 20, 28);
}

// ─────────────────────────────────────────────────────────────
//  RADIUS CONSTANTS
// ─────────────────────────────────────────────────────────────

class XiomiRadius {
  const XiomiRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 999;
}

// ─────────────────────────────────────────────────────────────
//  THEME CONFIGURATION
// ─────────────────────────────────────────────────────────────

class XiomiTheme {
  const XiomiTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: XiomiColors.primaryPurple,
      primary: XiomiColors.primaryPurple,
      secondary: XiomiColors.aquaBlue,
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: XiomiColors.coldWhite,
      fontFamily: 'Inter',
      visualDensity: VisualDensity.standard,

      // ── Text Theme ─────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
          height: 1.1,
        ),
        displayMedium: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          height: 1.15,
        ),
        displaySmall: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineLarge: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          height: 1.25,
        ),
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.35,
        ),
        titleSmall: TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          height: 1.4,
        ),
        bodyLarge: TextStyle(
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.45,
          fontSize: 12,
        ),
        labelLarge: TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          height: 1.4,
        ),
        labelMedium: TextStyle(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          height: 1.4,
        ),
        labelSmall: TextStyle(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          height: 1.4,
          fontSize: 11,
        ),
      ),

      // ── AppBar ─────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: XiomiColors.coldWhite,
        foregroundColor: XiomiColors.ink,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: -0.2,
          color: XiomiColors.ink,
        ),
      ),

      // ── Card ───────────────────────────────────────────
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(XiomiRadius.md),
          side: const BorderSide(color: XiomiColors.border, width: 0.5),
        ),
      ),

      // ── Navigation Bar ─────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        indicatorColor: XiomiColors.iceLilac,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Inter',
            color: states.contains(WidgetState.selected)
                ? XiomiColors.primaryPurple
                : XiomiColors.muted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? XiomiColors.primaryPurple
                : XiomiColors.mutedLight,
          ),
        ),
      ),

      // ── Input Decoration ───────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          color: XiomiColors.mutedLight,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: XiomiColors.muted,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XiomiRadius.md),
          borderSide: const BorderSide(color: XiomiColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XiomiRadius.md),
          borderSide: const BorderSide(color: XiomiColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XiomiRadius.md),
          borderSide: const BorderSide(
            color: XiomiColors.primaryPurple,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XiomiRadius.md),
          borderSide: const BorderSide(color: XiomiColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XiomiRadius.md),
          borderSide: const BorderSide(color: XiomiColors.error, width: 1.5),
        ),
        prefixIconColor: XiomiColors.muted,
      ),

      // ── Filled Button ──────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: XiomiColors.primaryPurple,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XiomiRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
          elevation: 0,
        ),
      ),

      // ── Outlined Button ────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: XiomiColors.primaryPurple,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: XiomiColors.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XiomiRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Text Button ────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: XiomiColors.primaryPurple,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // ── Icon Button ────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: XiomiColors.inkSecondary),
      ),

      // ── Snackbar ───────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: XiomiColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(XiomiRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // ── Dialog ─────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(XiomiRadius.xl),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: XiomiColors.ink,
          letterSpacing: -0.2,
        ),
      ),

      // ── Divider ────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: XiomiColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ── Tooltip ────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: XiomiColors.ink,
          borderRadius: BorderRadius.circular(XiomiRadius.sm),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
