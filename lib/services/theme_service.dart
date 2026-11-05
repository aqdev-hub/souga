// lib/services/theme_service.dart
//
// ✅ إدارة الوضع الليلي (ThemeMode.system / light / dark) مع حفظ التفضيل
// في SharedPreferences (بدون أي حزمة جديدة — نفس الحزمة المستخدمة بالفعل
// في cart_provider و auth_provider و onboarding_overlay).

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _prefsKey = 'souga_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  ThemeService() {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      switch (raw) {
        case 'light':
          _mode = ThemeMode.light;
          break;
        case 'dark':
          _mode = ThemeMode.dark;
          break;
        default:
          _mode = ThemeMode.system;
      }
      notifyListeners();
    } catch (_) {
      // تجاهل — يبقى الوضع الافتراضي ThemeMode.system
    }
  }

  Future<void> setMode(ThemeMode newMode) async {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, newMode.name);
    } catch (_) {
      // فشل الحفظ لا يمنع تغيير المظهر الحالي، فقط لن يُستعاد بعد إعادة الفتح
    }
  }
}
