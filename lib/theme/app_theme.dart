import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// EyeCatch 디자인 시스템 (Blue & White Theme)
class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────────────────────────
  // ThemeData: 라이트 / 다크
  // ─────────────────────────────────────────────────────────────────
  static ThemeData light() => _build(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          brightness: Brightness.light,
          primary: AppColors.accent, // 메인 블루
          onPrimary: AppColors.lightSurfaceLow, // 흰색
          primaryContainer: AppColors.accentSubtleLight,
          onPrimaryContainer: AppColors.accentDeep,
          secondary: AppColors.accent,
          onSecondary: AppColors.lightSurfaceLow,
          surface: AppColors.lightSurface,
          onSurface: AppColors.lightTextPrimary,
          surfaceContainerLowest: AppColors.lightSurfaceLow,
          surfaceContainerLow: AppColors.lightSurfaceMid,
          surfaceContainer: AppColors.lightSurfaceHigh,
          surfaceContainerHigh: AppColors.lightSurfaceHighest,
          surfaceContainerHighest: AppColors.lightBorderSubtle,
          onSurfaceVariant: AppColors.lightTextSecondary,
          outline: AppColors.lightBorder,
          outlineVariant: AppColors.lightBorderSubtle,
          error: AppColors.danger,
          onError: Colors.white,
          shadow: Color(0x14000000), // 가벼운 그림자
        ),
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          brightness: Brightness.dark,
          primary: AppColors.accentLight, // 다크모드에선 살짝 밝은 블루
          onPrimary: AppColors.darkSurfaceLow,
          primaryContainer: AppColors.accentSubtleDark,
          onPrimaryContainer: AppColors.accentLight,
          secondary: AppColors.accentLight,
          onSecondary: AppColors.darkSurfaceLow,
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkTextPrimary,
          surfaceContainerLowest: AppColors.darkSurfaceLow,
          surfaceContainerLow: AppColors.darkSurfaceMid,
          surfaceContainer: AppColors.darkSurfaceHigh,
          surfaceContainerHigh: AppColors.darkSurfaceHighest,
          surfaceContainerHighest: AppColors.darkBorderSubtle,
          onSurfaceVariant: AppColors.darkTextSecondary,
          outline: AppColors.darkBorder,
          outlineVariant: AppColors.darkBorderSubtle,
          error: AppColors.danger,
          onError: Colors.white,
          shadow: Color(0x66000000),
        ),
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme colorScheme,
  }) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      brightness: brightness,
      textTheme: _textTheme(GoogleFonts.notoSansKrTextTheme(base.textTheme)),

      // 컴포넌트 기본 스타일
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.notoSansKr(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.notoSansKr(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(0, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.notoSansKr(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: colorScheme.outline, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.notoSansKr(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        labelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),

      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
  behavior: SnackBarBehavior.floating,
  backgroundColor: colorScheme.surfaceContainerHigh,
  contentTextStyle: GoogleFonts.notoSansKr(
    fontSize: 14,
    color: colorScheme.onSurface,
    fontWeight: FontWeight.w500,
  ),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  ),
  elevation: 2,
  // 플로팅 네비바(높이 70 + 하단 24 마진)를 피해서 표시
  insetPadding: const EdgeInsets.fromLTRB(
      AppSpacing.lg, 0, AppSpacing.lg, 110),
),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),

      iconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
        size: 22,
      ),

      splashFactory: InkRipple.splashFactory,
      splashColor: colorScheme.primary.withOpacity(0.08),
      highlightColor: colorScheme.primary.withOpacity(0.04),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.25,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.3,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
    );
  }
}

/// 색상 토큰
class AppColors {
  AppColors._();

  // ─── 포인트 컬러 (제공해주신 Tailwind 기반의 블루톤) ───
  static const Color accent = Color(0xFF004ECB); // Tailwind 'primary'
  static const Color accentLight = Color(0xFF0064FF); // Tailwind 'primary-container'
  static const Color accentDeep = Color(0xFF003EA6); // Tailwind 'on-primary-fixed-variant'
  static const Color accentSubtleLight = Color(0xFFDBE1FF); // Tailwind 'primary-fixed'
  static const Color accentSubtleDark = Color(0xFF00174A); // Tailwind 'on-primary-fixed'

  // ─── 라이트 모드 (화이트/쿨그레이톤) ───
  static const Color lightSurface = Color(0xFFFAF8FF); // 바탕 배경
  static const Color lightSurfaceLow = Color(0xFFFFFFFF); // 카드 배경
  static const Color lightSurfaceMid = Color(0xFFF2F3FF); // 입력 필드, 리스트
  static const Color lightSurfaceHigh = Color(0xFFE6E7F4);
  static const Color lightSurfaceHighest = Color(0xFFE1E2EE);
  static const Color lightTextPrimary = Color(0xFF191B24); // 짙은 글씨
  static const Color lightTextSecondary = Color(0xFF424656); // 보조 글씨
  static const Color lightBorder = Color(0xFF737687); // 윤곽선
  static const Color lightBorderSubtle = Color(0xFFC2C6D8); // 옅은 윤곽선

  // ─── 다크 모드 (딥 네이비/쿨그레이톤) ───
  // 블루톤에 어울리는 차가운 블랙/네이비 계열로 조정
  static const Color darkSurface = Color(0xFF0E0F14); 
  static const Color darkSurfaceLow = Color(0xFF15161D); 
  static const Color darkSurfaceMid = Color(0xFF1E202A); 
  static const Color darkSurfaceHigh = Color(0xFF282A36);
  static const Color darkSurfaceHighest = Color(0xFF323544);
  static const Color darkTextPrimary = Color(0xFFF5F5FF); 
  static const Color darkTextSecondary = Color(0xFFA1A4B5);
  static const Color darkBorder = Color(0x30FFFFFF);
  static const Color darkBorderSubtle = Color(0x15FFFFFF);

  // ─── 시맨틱 컬러 (경고, 성공 등) ───
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFBA1A1A); // Tailwind 'error'
  static const Color info = Color(0xFF0064FF); 

  static Color successSoft(BuildContext context) =>
      success.withOpacity(_isDark(context) ? 0.15 : 0.10);
  static Color warningSoft(BuildContext context) =>
      warning.withOpacity(_isDark(context) ? 0.15 : 0.10);
  static Color dangerSoft(BuildContext context) =>
      danger.withOpacity(_isDark(context) ? 0.15 : 0.10);
  static Color accentSoft(BuildContext context) =>
      accent.withOpacity(_isDark(context) ? 0.15 : 0.10);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}

/// 간격 토큰
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// 모서리 radius 토큰
class AppRadius {
  AppRadius._();
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
}

/// 그림자 토큰
class AppShadows {
  AppShadows._();

  static List<BoxShadow> card(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: AppColors.accent.withOpacity(isDark ? 0.0 : 0.04), // 파란빛이 아주 살짝 도는 그림자
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> floating(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: AppColors.accent.withOpacity(isDark ? 0.2 : 0.08),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static List<BoxShadow> accentGlow() => [
        BoxShadow(
          color: AppColors.accent.withOpacity(0.3),
          blurRadius: 16,
          spreadRadius: 0,
        ),
      ];
}