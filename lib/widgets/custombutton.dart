// lib/widgets/custombutton.dart
//
// ✅ نفس اسم الكلاس تماماً (CustomButtonOnBoarding) — نُقل لمجلد lib/widgets/.
//
// ✅ تحسينات جوهرية (موثّقة بالتفصيل في README المرفق):
//   1. الزر أصبح ElevatedButton عادي بدل MaterialButton (المتوقف/legacy) —
//      بهذا يرث تلقائياً تصميم أزرار التطبيق (اللون، الحواف الدائرية،
//      العرض الكامل) من AppTheme.lightTheme/darkTheme، ويتوافق تلقائياً
//      مع الوضع الفاتح والداكن دون أي كود إضافي.
//   2. نص الزر يتغيّر ديناميكياً: "التالي" في الشرائح العادية،
//      و"ابدأ الآن 🎉" في آخر شريحة.
//   3. **الأهم**: عند الضغط في آخر شريحة، الزر الآن فعلياً يحفظ أن المستخدم
//      شاهد الشاشة (عبر completeOnboarding) وينتقل لصفحة Wrapper — وهي
//      الحلقة المفقودة في الكود الأصلي (كان `next()` لا يفعل شيئاً في آخر
//      شريحة).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/onboarding_controller.dart';
import '../screens/wrapper.dart';

class CustomButtonOnBoarding extends StatelessWidget {
  const CustomButtonOnBoarding({super.key});

  Future<void> _finish(BuildContext context) async {
    final controller = context.read<OnBoardingControllerImp>();
    await controller.completeOnboarding();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const Wrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OnBoardingControllerImp>();
    final isLast = controller.isLastPage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () =>
              isLast ? _finish(context) : context.read<OnBoardingControllerImp>().next(),
          child: Text(isLast ? 'ابدأ الآن 🎉' : 'التالي'),
        ),
      ),
    );
  }
}
