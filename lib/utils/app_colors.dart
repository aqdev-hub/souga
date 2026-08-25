// lib/utils/app_colors.dart

import 'package:flutter/material.dart';

/// ⚠️ ثوابت قديمة (Light Mode فقط) — تبقى كما هي دون أي تغيير حتى لا تنكسر
/// أي شاشة لم تُحوَّل بعد لنظام [SougaColors] الديناميكي أدناه.
/// الشاشات المُحوَّلة تستخدم `context.colors.xxx` بدلاً من `AppColors.xxx`.
class AppColors {
  // اللون القرمزي الدقيق #DC143C
  static const Color primary = Color(0xFFC8102E);
  static const Color primaryDark = Color(0xFF8B0E1A);
  static const Color primaryLight = Color(0xFFE53955);

  // الذهبي الثانوي
  static const Color accent = Color(0xFFD4AF37);
  static const Color accentDark = Color(0xFFB8860B);

  // الخلفية
  static const Color background = Color(0xFFF8F7F5);
  static const Color surface = Color(0xFFFFFFFF);

  // النصوص
  static const Color textPrimary = Color(0xFF1B1B1B);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF9E9E9E);

  // الحالات
  static const Color success = Color(0xFF2E8B57);
  static const Color warning = Color(0xFFF5A623);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF1976D2);

  // الحدود
  static const Color border = Color(0xFFE8E3DB);
  static const Color divider = Color(0xFFF2F2F2);

  // تدرج قرمزي يتلاشى للأسفل
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryDark, primary,primaryLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // تدرج شفاف للهيدر
  static const LinearGradient headerFadeGradient = LinearGradient(
    colors: [primaryDark, primary, Color(0x00FAFAFA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.70, 1.0],
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  SougaColors — نظام الألوان الديناميكي (يدعم الوضع الفاتح والداكن)
// ════════════════════════════════════════════════════════════════════════════
//
//  الاستخدام في الشاشات المُحوَّلة:
//    Container(color: context.colors.background)
//    Text('..', style: TextStyle(color: context.colors.textPrimary))
//
//  ملاحظة: لا يمكن استخدام `const` مع context.colors.xxx (لأنها قيمة تُحسب
//  وقت التشغيل بحسب الثيم الحالي)، على عكس AppColors.xxx القديمة.
// ════════════════════════════════════════════════════════════════════════════

@immutable
class SougaColors extends ThemeExtension<SougaColors> {
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color accent;
  final Color accentDark;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color border;
  final Color divider;

  const SougaColors({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accent,
    required this.accentDark,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.border,
    required this.divider,
  });

  /// تدرّج أساسي يتلاشى للأسفل — بديل ديناميكي لـ AppColors.primaryGradient
  LinearGradient get primaryGradient => LinearGradient(
        colors: [primaryDark, primary,primaryLight],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  /// تدرّج شفاف للهيدر — بديل ديناميكي لـ AppColors.headerFadeGradient
  LinearGradient get headerFadeGradient => LinearGradient(
        colors: [primaryDark, primary, background.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.70, 1.0],
      );

  // ── الوضع الفاتح — نفس ألوان AppColors القديمة تماماً ──────────────────
  static const light = SougaColors(
    primary: Color(0xFFC8102E),
    primaryDark: Color(0xFF8B0E1A),
    primaryLight: Color(0xFFE53955),

    // الذهبي
    accent: Color(0xFFD4AF37),
    accentDark: Color(0xFFB8860B),

    // الخلفيات
    background: Color(0xFFF8F7F5),
    surface: Color(0xFFFFFFFF),

    // النصوص
    textPrimary: Color(0xFF1B1B1B),
    textSecondary: Color(0xFF666666),
    textHint: Color(0xFF9E9E9E),

    // الحالات
    success: Color(0xFF2E8B57),
    warning: Color(0xFFF5A623),
    error: Color(0xFFD32F2F),
    info: Color(0xFF1976D2),

    // الحدود
    border: Color(0xFFE8E3DB),
    divider: Color(0xFFF2F2F2),
  );

  // ── الوضع الداكن — الأزرق السماوي #1E90FF بدل القرمزي ──────────────────
  static const dark = SougaColors(
    primary: Color(0xFF1E90FF),
    primaryDark: Color(0xFF0D5FBF),
    primaryLight: Color(0xFF5CACFF),
    accent: Color(0xFFFFB300),
    accentDark: Color(0xFFF57F17),
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    textPrimary: Color(0xFFECECEC),
    textSecondary: Color(0xFFB0B0B0),
    textHint: Color(0xFF6E6E6E),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFFA726),
    error: Color(0xFFEF5350),
    info: Color(0xFF42A5F5),
    border: Color(0xFF3A3A3A),
    divider: Color(0xFF2A2A2A),
  );

  @override
  SougaColors copyWith({
    Color? primary,
    Color? primaryDark,
    Color? primaryLight,
    Color? accent,
    Color? accentDark,
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? border,
    Color? divider,
  }) {
    return SougaColors(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      accent: accent ?? this.accent,
      accentDark: accentDark ?? this.accentDark,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      border: border ?? this.border,
      divider: divider ?? this.divider,
    );
  }

  @override
  SougaColors lerp(ThemeExtension<SougaColors>? other, double t) {
    if (other is! SougaColors) return this;
    return SougaColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

/// وصول سريع: `context.colors.primary` بدل `Theme.of(context).extension<SougaColors>()!.primary`
extension SougaColorsX on BuildContext {
  SougaColors get colors =>
      Theme.of(this).extension<SougaColors>() ?? SougaColors.light;
}
