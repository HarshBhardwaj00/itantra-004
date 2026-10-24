import 'package:flutter/material.dart';

/// iTantra v2.0 — "Light Neural" design tokens.
///
/// Source of truth: `design.md` (v2.0). The legacy dark tactical OLED
/// palette is kept in `design_v1_dark.md` for reference only; the app now
/// ships the light neural system with Forest Emerald accents.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Background & Surfaces
  // ---------------------------------------------------------------------------

  /// Scaffold background — pure white.
  static const Color background = Color(0xFFFFFFFF);

  /// Secondary fill — search inputs, composer bar, subtle card fills.
  static const Color surfaceSecondary = Color(0xFFF8FAFC);

  /// Card surface — pure white cards on the white scaffold.
  static const Color surfaceCard = Color(0xFFFFFFFF);

  /// 1px border for unselected cards, search bars and message inputs.
  static const Color surfaceBorder = Color(0xFFE2E8F0);

  /// Subtle dividers, dock top border, feed card outline.
  static const Color surfaceBorderSubtle = Color(0xFFF1F5F9);

  // ---------------------------------------------------------------------------
  // Hero brand — Forest Emerald
  // ---------------------------------------------------------------------------

  /// Signature brand color: primary CTA, PTT circle, active tab indicator.
  static const Color primaryEmerald = Color(0xFF00875A);

  /// Vibrant emerald: active checkmarks, active badges, live node icons.
  static const Color primaryEmeraldVibrant = Color(0xFF059669);

  /// Deep emerald used for pressed states and high contrast on mint surfaces.
  static const Color primaryEmeraldDark = Color(0xFF065F46);

  /// Soft diffused emerald glow (`rgba(0,135,90,0.18)`).
  static const Color emeraldGlow = Color(0x2E00875A);

  /// Mint tint background for `• Mesh Active`, `• Node Live` and pill chips.
  static const Color emeraldMintTint = Color(0xFFECFDF5);

  /// Mint border for active language cards and replay buttons.
  static const Color emeraldMintBorder = Color(0xFFA7F3D0);

  /// Soft emerald avatar background for play buttons and `HI` badges.
  static const Color emeraldAvatarBg = Color(0xFFDCFCE7);

  /// Live recording waveform bars.
  static const Color waveformActive = Color(0xFF00875A);

  /// Recorded / feed waveform preview bars.
  static const Color waveformPreview = Color(0xFFA7F3D0);

  // ---------------------------------------------------------------------------
  // Emergency alert palette
  // ---------------------------------------------------------------------------

  /// `⚠️ CRITICAL ALERT` headline and high priority button text.
  static const Color alertRed = Color(0xFFDC2626);

  /// Warning icons and urgent badge pulses.
  static const Color alertRedAccent = Color(0xFFEF4444);

  /// Soft rose critical alert card background.
  static const Color alertRedBg = Color(0xFFFEF2F2);

  /// 1px border around critical alert cards.
  static const Color alertRedBorder = Color(0xFFFECACA);

  /// Background of the "High-Priority Audio" button.
  static const Color alertBtnBg = Color(0xFFFFF5F5);

  /// Border of the "High-Priority Audio" button.
  static const Color alertBtnBorder = Color(0xFFFCA5A5);

  /// Soft alert glow used behind the emergency strobe.
  static const Color alertRedGlow = Color(0x1FDC2626);

  // ---------------------------------------------------------------------------
  // Typography & neutral grays
  // ---------------------------------------------------------------------------

  /// Screen titles, app name, native Indic script text.
  static const Color textPrimary = Color(0xFF0F172A);

  /// Subtitles, translations, helper copy.
  static const Color textSecondary = Color(0xFF64748B);

  /// Inactive icons, timestamps, search hints.
  static const Color textMuted = Color(0xFF94A3B8);

  /// Pure white text on emerald buttons and the mic icon.
  static const Color textWhite = Color(0xFFFFFFFF);

  /// Slightly stronger slate for secondary button labels.
  static const Color textSlate = Color(0xFF475569);

  // ---------------------------------------------------------------------------
  // Misc surfaces
  // ---------------------------------------------------------------------------

  /// Dark slate squircle base of the iTantra launcher icon.
  static const Color iconSquircleBg = Color(0xFF1E232E);

  /// Soft neutral chip background (grey-100) used by unselected markers.
  static const Color chipNeutral = Color(0xFFD1D5DB);

  /// Unselected radio marker ring.
  static const Color radioUnselected = Color(0xFFD1D5DB);

  /// Selected language card background (mint).
  static const Color selectedSurface = Color(0xFFF0FDF4);

  /// Selected language card border.
  static const Color selectedBorder = Color(0xFF86EFAC);

  // ---------------------------------------------------------------------------
  // Indic language avatar pastels
  // ---------------------------------------------------------------------------

  static const Color langHindiBg = Color(0xFFDCFCE7);
  static const Color langHindiText = Color(0xFF059669);

  static const Color langGujaratiBg = Color(0xFFDBEAFE);
  static const Color langGujaratiText = Color(0xFF1D4ED8);

  static const Color langMarathiBg = Color(0xFFFCE7F3);
  static const Color langMarathiText = Color(0xFFBE185D);

  static const Color langKannadaBg = Color(0xFFFEF3C7);
  static const Color langKannadaText = Color(0xFFB45309);

  static const Color langMalayalamBg = Color(0xFFEDE9FE);
  static const Color langMalayalamText = Color(0xFF6D28D9);

  static const Color langTamilBg = Color(0xFFFFEDD5);
  static const Color langTamilText = Color(0xFFC2410C);

  static const Color langTeluguBg = Color(0xFFCCFBF1);
  static const Color langTeluguText = Color(0xFF0F766E);

  static const Color langOdiaBg = Color(0xFFEDE9FE);
  static const Color langOdiaText = Color(0xFF5B21B6);

  static const Color langBengaliBg = Color(0xFFFEF3C7);
  static const Color langBengaliText = Color(0xFF92400E);

  static const Color langPunjabiBg = Color(0xFFDBEAFE);
  static const Color langPunjabiText = Color(0xFF1E40AF);

  /// Sky blue speaker / audio preview icon.
  static const Color audioPreviewIcon = Color(0xFF60A5FA);

  /// Soft sky blue fill behind the speaker preview button.
  static const Color audioPreviewBg = Color(0xFFDBEAFE);
}

/// Pastel identity of a language chip (design.md §2).
///
/// Every Indian language owns a pastel background and a matching, readable
/// text colour so the catalogue stays colourful without losing contrast.
class LanguagePalette {
  LanguagePalette._();

  /// Pastel background + foreground of a language code.
  static ({Color background, Color foreground}) of(String code) {
    switch (code.toLowerCase().split('_').first) {
      case 'hi':
        return (
          background: AppColors.langHindiBg,
          foreground: AppColors.langHindiText,
        );
      case 'gu':
        return (
          background: AppColors.langGujaratiBg,
          foreground: AppColors.langGujaratiText,
        );
      case 'mr':
        return (
          background: AppColors.langMarathiBg,
          foreground: AppColors.langMarathiText,
        );
      case 'kn':
        return (
          background: AppColors.langKannadaBg,
          foreground: AppColors.langKannadaText,
        );
      case 'ml':
        return (
          background: AppColors.langMalayalamBg,
          foreground: AppColors.langMalayalamText,
        );
      case 'ta':
        return (
          background: AppColors.langTamilBg,
          foreground: AppColors.langTamilText,
        );
      case 'te':
        return (
          background: AppColors.langTeluguBg,
          foreground: AppColors.langTeluguText,
        );
      case 'or':
      case 'od':
        return (
          background: AppColors.langOdiaBg,
          foreground: AppColors.langOdiaText,
        );
      case 'bn':
        return (
          background: AppColors.langBengaliBg,
          foreground: AppColors.langBengaliText,
        );
      case 'pa':
        return (
          background: AppColors.langPunjabiBg,
          foreground: AppColors.langPunjabiText,
        );
      default:
        return (
          background: AppColors.emeraldMintTint,
          foreground: AppColors.primaryEmeraldVibrant,
        );
    }
  }
}

/// Font families bundled with the app (see `pubspec.yaml`).
///
/// The Latin/UI face is Plus Jakarta Sans. Every Indian script has its own
/// Noto Sans family so `fontFamilyFallback` can hand a native string over to
/// a font that actually owns the glyphs — no tofu boxes, no clipped matras.
class AppFonts {
  AppFonts._();

  /// Primary Latin & UI family.
  static const String primary = 'PlusJakartaSans';

  /// Ordered script fallbacks used by the global theme.
  static const List<String> fallback = <String>[
    'NotoSansDevanagari',
    'NotoSansGujarati',
    'NotoSansKannada',
    'NotoSansMalayalam',
    'NotoSansTamil',
    'NotoSansTelugu',
    'NotoSansOriya',
    'NotoSansBengali',
    'NotoSansGurmukhi',
  ];

  /// Resolves the script specific family for a language code.
  ///
  /// Unknown codes fall back to the primary family so the caller always gets
  /// a usable, bundled family name.
  static String forLanguageCode(String code) {
    switch (code.toLowerCase()) {
      case 'hi':
      case 'mr':
        return 'NotoSansDevanagari';
      case 'gu':
        return 'NotoSansGujarati';
      case 'kn':
        return 'NotoSansKannada';
      case 'ml':
        return 'NotoSansMalayalam';
      case 'ta':
        return 'NotoSansTamil';
      case 'te':
        return 'NotoSansTelugu';
      case 'or':
      case 'od':
        return 'NotoSansOriya';
      case 'bn':
        return 'NotoSansBengali';
      case 'pa':
        return 'NotoSansGurmukhi';
      default:
        return primary;
    }
  }
}

/// Typography scale of the Light Neural system (design.md §3).
class AppTypography {
  AppTypography._();

  /// Display brand title — "iTantra" on splash & onboarding.
  static const TextStyle brand = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  /// Screen headline — "Select Working Language", "Incoming Feed".
  static const TextStyle headline = TextStyle(
    fontSize: 23,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  /// Hero action caption — "PUSH TO TALK".
  static const TextStyle heroCaption = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 1.5,
    color: AppColors.textSecondary,
  );

  /// Card primary title.
  static const TextStyle cardTitle = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  /// Card subtitle / body copy.
  static const TextStyle cardBody = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// English translation / meta copy.
  static const TextStyle translation = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.1,
    color: AppColors.textSecondary,
  );

  /// Pill / status badge.
  static const TextStyle badge = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    height: 1.0,
    letterSpacing: 0.2,
    color: AppColors.primaryEmeraldVibrant,
  );

  /// Primary CTA label.
  static const TextStyle buttonCta = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.2,
    color: AppColors.textWhite,
  );

  /// Secondary button label.
  static const TextStyle buttonSecondary = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.1,
    color: AppColors.textSlate,
  );

  /// Timestamp / micro copy.
  static const TextStyle micro = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.2,
    color: AppColors.textMuted,
  );
}

/// iTantra Material 3 Light Theme — "Light Neural" (design.md §6).
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    const ColorScheme scheme = ColorScheme.light(
      surface: AppColors.background,
      primary: AppColors.primaryEmerald,
      secondary: AppColors.primaryEmeraldVibrant,
      tertiary: AppColors.audioPreviewIcon,
      error: AppColors.alertRed,
      onPrimary: AppColors.textWhite,
      onSecondary: AppColors.textWhite,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      onError: AppColors.textWhite,
      outline: AppColors.surfaceBorder,
      outlineVariant: AppColors.surfaceBorderSubtle,
      surfaceContainerHighest: AppColors.surfaceSecondary,
      surfaceContainerLow: AppColors.surfaceSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      fontFamily: AppFonts.primary,
      fontFamilyFallback: AppFonts.fallback,
      colorScheme: scheme,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceBorderSubtle,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
      textTheme: const TextTheme(
        displaySmall: AppTypography.brand,
        headlineSmall: AppTypography.headline,
        titleLarge: AppTypography.cardTitle,
        titleMedium: AppTypography.cardTitle,
        bodyLarge: AppTypography.cardBody,
        bodyMedium: AppTypography.cardBody,
        bodySmall: AppTypography.translation,
        labelLarge: AppTypography.buttonCta,
        labelMedium: AppTypography.badge,
        labelSmall: AppTypography.micro,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.0),
          side: const BorderSide(color: AppColors.surfaceBorder, width: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.primary,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSecondary,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 14.0,
        ),
        hintStyle: const TextStyle(
          fontFamily: AppFonts.primary,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
        labelStyle: const TextStyle(
          fontFamily: AppFonts.primary,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(
            color: AppColors.primaryEmerald,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.alertRedAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(
            color: AppColors.alertRedAccent,
            width: 1.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryEmerald,
          foregroundColor: AppColors.textWhite,
          disabledBackgroundColor: AppColors.surfaceSecondary,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size(double.infinity, 54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
          ),
          textStyle: const TextStyle(
            fontFamily: AppFonts.primary,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSlate,
          backgroundColor: AppColors.surfaceCard,
          side: const BorderSide(color: AppColors.surfaceBorder),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          textStyle: const TextStyle(
            fontFamily: AppFonts.primary,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryEmerald,
          textStyle: const TextStyle(
            fontFamily: AppFonts.primary,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceSecondary,
        selectedColor: AppColors.emeraldMintTint,
        side: const BorderSide(color: AppColors.surfaceBorder),
        labelStyle: const TextStyle(
          fontFamily: AppFonts.primary,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: AppFonts.primary,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textWhite,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primaryEmerald,
        inactiveTrackColor: AppColors.surfaceBorder,
        thumbColor: AppColors.primaryEmerald,
        overlayColor: AppColors.emeraldGlow,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryEmerald,
        linearTrackColor: AppColors.surfaceBorderSubtle,
        circularTrackColor: AppColors.surfaceBorderSubtle,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.textWhite;
          }
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryEmerald;
          }
          return AppColors.surfaceBorder;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: TextStyle(
          fontFamily: AppFonts.primary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textWhite,
        ),
      ),
    );
  }
}
