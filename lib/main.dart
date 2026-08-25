// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/product_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/onboarding_controller.dart';
import 'screens/onboarding.dart';
import 'screens/wrapper.dart';
import 'services/deep_link_service.dart';
import 'services/theme_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ تفعيل استقبال روابط Deep Link (souga://product/ID)
  // يجب استدعاؤها بعد تهيئة Firebase لأن معالجة الرابط تحتاج Firestore.
  DeepLinkService.init();

  // ✅ هل شاهد المستخدم شاشة الترحيب (Onboarding) من قبل؟
  // تُفحص مرة واحدة فقط عند الإقلاع لتحديد الشاشة الأولى للتطبيق.
  final seenOnboarding = await OnBoardingControllerImp.hasSeenOnboarding();

  runApp(SougaApp(seenOnboarding: seenOnboarding));
}

class SougaApp extends StatelessWidget {
  final bool seenOnboarding;
  const SougaApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        // ✅ الوضع الليلي — يُحمَّل تلقائياً من SharedPreferences عند الإقلاع
        ChangeNotifierProvider(create: (_) => ThemeService()),
        // ✅ شاشة الترحيب (Onboarding) — تُعرض مرة واحدة فقط قبل تسجيل الدخول
        ChangeNotifierProvider(create: (_) => OnBoardingControllerImp()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) => MaterialApp(
          navigatorKey: DeepLinkService.navigatorKey,
          title: 'Souga',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.mode,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          // ✅ أول مرة يُفتح التطبيق فيها: شاشة الترحيب أولاً.
          // بعدها (وفي كل تشغيل لاحق): Wrapper مباشرة كما كان.
          home: seenOnboarding ? const Wrapper() : const OnBoarding(),
        ),
      ),
    );
  }
}
