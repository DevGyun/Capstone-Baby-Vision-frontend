import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// EyeCatch 디자인 시스템.
///
/// 사용 원칙:
/// 1. 색상은 `Theme.of(context).colorScheme.xxx`로 접근하면 라이트/다크 자동 전환됨
/// 2. 강조색(테라코타)은 `colorScheme.primary` 또는 [AppColors.accent] 사용
/// 3. 간격은 [AppSpacing], 모서리는 [AppRadius], 타이포는 [Theme.of(context).textTheme]
/// 4. 그림자는 [AppShadows] (다크모드에서는 거의 안 씀)
class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────────────────────────
  // ThemeData: 라이트 / 다크
  // main.dart에서 theme/darkTheme로 사용
  // ─────────────────────────────────────────────────────────────────
  static ThemeData light() => _build(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          brightness: Brightness.light,
          primary: AppColors.accent, // 테라코타
          onPrimary: AppColors.lightSurface, // 따뜻한 화이트
          primaryContainer: AppColors.accentSubtleLight,
          onPrimaryContainer: AppColors.accentDeep,
          secondary: AppColors.accent,
          onSecondary: AppColors.lightSurface,
          surface: AppColors.lightSurface,
          onSurface: AppColors.lightTextPrimary,
          surfaceContainerLowest: AppColors.lightSurface,
          surfaceContainerLow: AppColors.lightSurfaceLow,
          surfaceContainer: AppColors.lightSurfaceMid,
          surfaceContainerHigh: AppColors.lightSurfaceHigh,
          surfaceContainerHighest: AppColors.lightSurfaceHighest,
          onSurfaceVariant: AppColors.lightTextSecondary,
          outline: AppColors.lightBorder,
          outlineVariant: AppColors.lightBorderSubtle,
          error: AppColors.danger,
          onError: Colors.white,
          shadow: Color(0x14000000),
        ),
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          brightness: Brightness.dark,
          primary: AppColors.accent, // 테라코타 (다크에서도 동일)
          onPrimary: AppColors.darkSurface,
          primaryContainer: AppColors.accentSubtleDark,
          onPrimaryContainer: AppColors.accentLight,
          secondary: AppColors.accent,
          onSecondary: AppColors.darkSurface,
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkTextPrimary,
          surfaceContainerLowest: AppColors.darkSurface,
          surfaceContainerLow: AppColors.darkSurfaceLow,
          surfaceContainer: AppColors.darkSurfaceMid,
          surfaceContainerHigh: AppColors.darkSurfaceHigh,
          surfaceContainerHighest: AppColors.darkSurfaceHighest,
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

      // 컴포넌트 기본 스타일 — 모든 화면에서 일관된 느낌
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

      // splash 효과 톤 다운
      splashFactory: InkRipple.splashFactory,
      splashColor: colorScheme.primary.withOpacity(0.08),
      highlightColor: colorScheme.primary.withOpacity(0.04),
    );
  }

  /// 5단계 텍스트 위계.
  /// 사용처:
  /// - displayLarge: 인사말, 화면 최상단 헤드라인 (1개만)
  /// - headlineMedium: 섹션 타이틀
  /// - titleMedium: 카드 제목, 리스트 헤더
  /// - bodyMedium: 본문
  /// - labelMedium: 메타데이터, 타임스탬프
  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      // Display — 인사말급 헤드라인 (한 화면에 1개)
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.25,
      ),
      // Headline — 화면 타이틀
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.3,
      ),
      // Title — 섹션 / 카드 제목
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
      // Body — 본문
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
      // Label — 메타데이터, 칩
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

/// 색상 토큰. 직접 사용보다는 [Theme.of(context).colorScheme]을 우선하세요.
/// 시맨틱 컬러(success, warning 등)는 ColorScheme에 없어서 여기서 직접 가져갑니다.
class AppColors {
  AppColors._();

  // ─── 라이트 모드 ───
  static const Color lightSurface = Color(0xFFFAFAF7); // 따뜻한 크림 배경
  static const Color lightSurfaceLow = Color(0xFFFFFFFF);
  static const Color lightSurfaceMid = Color(0xFFF5F4EE);
  static const Color lightSurfaceHigh = Color(0xFFEDECE5);
  static const Color lightSurfaceHighest = Color(0xFFE5E3DA);
  static const Color lightTextPrimary = Color(0xFF1F1E1A); // 따뜻한 블랙
  static const Color lightTextSecondary = Color(0xFF6B6967);
  static const Color lightBorder = Color(0x14000000);
  static const Color lightBorderSubtle = Color(0x0A000000);

  // ─── 다크 모드 ───
  static const Color darkSurface = Color(0xFF0E0E10); // 따뜻한 near-black
  static const Color darkSurfaceLow = Color(0xFF1A1A1D); // 카드
  static const Color darkSurfaceMid = Color(0xFF242427); // 입력 필드
  static const Color darkSurfaceHigh = Color(0xFF2C2C30);
  static const Color darkSurfaceHighest = Color(0xFF35353A);
  static const Color darkTextPrimary = Color(0xFFFAFAF7); // 따뜻한 화이트
  static const Color darkTextSecondary = Color(0xFFA8A6A0);
  static const Color darkBorder = Color(0x1AFFFFFF);
  static const Color darkBorderSubtle = Color(0x0FFFFFFF);

  // ─── 포인트 컬러 (테라코타) — 양쪽 모드 공통 ───
  static const Color accent = Color(0xFFE97B5A); // 메인
  static const Color accentLight = Color(0xFFF08F70); // hover/glow용
  static const Color accentDeep = Color(0xFFB85936); // 진한 강조
  static const Color accentSubtleLight = Color(0xFFFCE4DC); // 라이트 배지 배경
  static const Color accentSubtleDark = Color(0xFF3D241D); // 다크 배지 배경

  // ─── 시맨틱 컬러 (모드 무관 사용 가능) ───
  static const Color success = Color(0xFF4ADE80); // 온라인, 안전
  static const Color warning = Color(0xFFF59E0B); // 위험구역 진입, 경고
  static const Color danger = Color(0xFFEF4444); // 에러, 삭제
  static const Color info = Color(0xFF60A5FA); // 정보

  /// 시맨틱 컬러의 옅은 배경 (배지/아이콘 박스용).
  /// 다크 모드와 라이트 모드 모두에서 자연스럽게 쓰일 수 있도록 alpha 적용.
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

/// 간격 토큰. 5단계로 통일.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// 모서리 radius 토큰. 3단계로 통일.
class AppRadius {
  AppRadius._();
  static const double sm = 10; // 배지, 작은 칩
  static const double md = 16; // 카드, 입력, 기본 버튼
  static const double lg = 24; // 메인 비디오, 네비, 큰 컨테이너
}

/// 그림자 토큰. 다크 모드에선 거의 안 씀.
class AppShadows {
  AppShadows._();

  /// 살짝 떠 있는 카드용
  static List<BoxShadow> card(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// 플로팅 요소 (네비게이션 바, 모달)
  static List<BoxShadow> floating(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];
  }

  /// 액센트 요소의 부드러운 글로우 (라이브 인디케이터 등). 매우 절제해서 사용.
  static List<BoxShadow> accentGlow() => [
        BoxShadow(
          color: AppColors.accent.withOpacity(0.3),
          blurRadius: 16,
          spreadRadius: 0,
        ),
      ];
}