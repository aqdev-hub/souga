// lib/utils/app_theme.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme =>
      _buildTheme(SougaColors.light, Brightness.light);

  static ThemeData get darkTheme =>
      _buildTheme(SougaColors.dark, Brightness.dark);

  static ThemeData _buildTheme(SougaColors c, Brightness brightness) {
    // نستخدم ThemeData افتراضي فقط لاستخراج textTheme الأساسي المناسب
    // للسطوع الحالي (فاتح/داكن) ثم نُطبّق ألواننا فوقه.
    final baseTextTheme = ThemeData(brightness: brightness).textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.primary,
        brightness: brightness,
        primary: c.primary,
        secondary: c.accent,
        surface: c.surface,
        error: c.error,
      ),
      scaffoldBackgroundColor: c.background,
      textTheme: baseTextTheme.apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      dividerColor: c.divider,
      // لا يصبح النص بلون الخلفية عند الضغط/التحديد: طبقة الضغط شفافة
      // (alpha منخفض) فيبقى لون النص ظاهراً دائماً.
      splashColor: c.primary.withValues(alpha: 0.12),
      highlightColor: c.primary.withValues(alpha: 0.08),
      hoverColor: c.primary.withValues(alpha: 0.06),
      focusColor: c.primary.withValues(alpha: 0.10),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.accent.withValues(alpha: 0.35),
        selectionHandleColor: c.accent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        // المحدّد: لون النص يبقى واضحاً فوق خلفية primary الخفيفة
        selectedColor: brightness == Brightness.dark ? Colors.white : c.primaryDark,
        selectedTileColor: c.primary.withValues(alpha: 0.12),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        textStyle: TextStyle(color: c.textPrimary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.dark ? c.primaryDark : c.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actionsIconTheme: const IconThemeData(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          overlayColor: Colors.white,
          minimumSize: const Size(64, 52),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          overlayColor: c.primary,
          side: BorderSide(
            color: c.border,
            width: 1.4,
          ),
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          overlayColor: c.primary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        hintStyle: TextStyle(
          color: c.textHint,
          fontSize: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: c.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: c.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: c.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: c.error,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: c.error,
            width: 2,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        elevation: 0,
        indicatorColor: c.primary.withValues(alpha: 0.10),
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: c.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }

          return TextStyle(
            color: c.textSecondary,
            fontSize: 12,
          );
        }),
      ),
      iconTheme: IconThemeData(
        color: c.textPrimary,
        size: 24,
      ),
      dividerTheme: DividerThemeData(
        color: c.divider,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primary,
        disabledColor: c.border,
        labelStyle: TextStyle(
          color: c.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      // ✅ يتيح لأي شاشة الوصول لألواننا المخصّصة عبر:
      // Theme.of(context).extension<SougaColors>() أو اختصار context.colors
      extensions: [c],
    );
  }
}
