// lib/providers/onboarding_controller.dart
//
// ✅ نفس الاسمين تماماً (OnBoardingController المجرّد، وOnBoardingControllerImp)
// كما وردا في الرفعة — نُقل لمجلد lib/providers/ ليتوافق مع بنية المشروع
// (بجانب auth_provider.dart, cart_provider.dart...).
//
// ✅ إضافة (بدون حذف أو تغيير أي شيء موجود):
//   - isLastPage: لمعرفة هل نحن في آخر شريحة (يُستخدم لتغيير نص الزر).
//   - completeOnboarding(): يحفظ في SharedPreferences أن المستخدم شاهد
//     شاشة الترحيب، حتى لا تظهر مرة أخرى بعد اليوم الأول.
//   - hasSeenOnboarding(): تُستدعى مرة واحدة من main() لتحديد الشاشة الأولى
//     (Onboarding أول مرة فقط، ثم Wrapper مباشرة لاحقاً — تسجيل الدخول/التسجيل
//     يظهر تلقائياً بعدها لأن Wrapper يتولى تحديد الشاشة المناسبة أصلاً).
//
// لا حاجة لحزمة جديدة — shared_preferences مستخدمة أصلاً في المشروع
// (cart_provider.dart, auth_provider.dart, theme_service.dart...).
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/static.dart';

abstract class OnBoardingController extends ChangeNotifier {
  next();
  onPageChanged(int index);
}

class OnBoardingControllerImp extends OnBoardingController {
  static const String _seenKey = 'souga_seen_intro_onboarding';

  late PageController pageController;
  int currentPage = 0;

  OnBoardingControllerImp() {
    onInit();
  }

  bool get isLastPage => currentPage == onBoardingList.length - 1;

  @override
  next() {
    if (currentPage < onBoardingList.length - 1) {
      currentPage++;
      pageController.animateToPage(currentPage,
          duration: const Duration(milliseconds: 900), curve: Curves.easeInOut);
    }
    notifyListeners();
  }

  @override
  onPageChanged(int index) {
    currentPage = index;
    notifyListeners();
  }

  void onInit() {
    pageController = PageController();
  }

  /// يُحفظ عند الضغط على "ابدأ الآن" في آخر شريحة، أو عند "تخطي".
  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
    } catch (_) {
      // فشل الحفظ لا يمنع المتابعة — فقط قد تظهر الشاشة مرة أخرى لاحقاً
    }
  }

  /// يُستدعى مرة واحدة من main() قبل تشغيل التطبيق لتحديد الشاشة الأولى.
  static Future<bool> hasSeenOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_seenKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
