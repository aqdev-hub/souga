// lib/screens/onboarding.dart
//
// ✅ نفس اسم الكلاس تماماً (OnBoarding) — نُقل لمجلد lib/screens/ (بجانب
// wrapper.dart، لأنها شاشة توجيه على نفس المستوى: تظهر مرة واحدة قبل
// Wrapper، وليست تابعة لدور عميل/بائع/إدارة محدد).
//
// ✅ إضافات:
//   - زر "تخطي" أعلى الشاشة (نفس مكان وأسلوب زر التخطي في
//     widgets/onboarding_overlay.dart الموجود مسبقاً في المشروع — لضمان
//     تناسق تجربة المستخدم بين نظامَي Onboarding في التطبيق).
//   - خلفية الشاشة تعتمد على context.colors.background (متوافقة مع
//     الوضع الداكن) بدل الاعتماد على لون Scaffold الافتراضي فقط.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/onboarding_controller.dart';
import '../utils/app_colors.dart';
import '../widgets/custombutton.dart';
import '../widgets/customdotcontroller.dart';
import '../widgets/customslideronboarding.dart';
import 'wrapper.dart';

class OnBoarding extends StatelessWidget {
  const OnBoarding({super.key});

  Future<void> _skip(BuildContext context) async {
    final controller = context.read<OnBoardingControllerImp>();
    await controller.completeOnboarding();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const Wrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: TextButton(
                onPressed: () => _skip(context),
                child: Text('تخطي',
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 14)),
              ),
            ),
            const Expanded(flex: 3, child: CustomSliderOnBoarding()),
            const Expanded(
                flex: 1,
                child: Column(
                  children: [
                    CustomDotControllerOnBoarding(),
                    Spacer(flex: 2),
                    CustomButtonOnBoarding(),
                  ],
                ))
          ],
        ),
      ),
    );
  }
}
