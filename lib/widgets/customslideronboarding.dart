// lib/widgets/customslideronboarding.dart
//
// ✅ نفس اسم الكلاس تماماً (CustomSliderOnBoarding) — نُقل لمجلد lib/widgets/.
//
// ✅ تحسينات:
//   - الألوان الثابتة استُبدلت بـ context.colors (توافق كامل مع الوضع الداكن).
//   - المسافات الثابتة (SizedBox height:80 مرتين) استُبدلت بمسافات مرنة
//     (Expanded/Spacer) لتفادي أي فيضان (overflow) على الشاشات الصغيرة.
//   - إزالة علامات `!` لأن حقول OnBoardingModel أصبحت required (غير قابلة للـ null).
//   - الصورة الآن داخل Expanded مع BoxFit.contain لتظهر كاملة ومتناسقة الحجم
//     مهما اختلفت أبعاد كل صورة من الصور الأربع.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/onboarding_controller.dart';
import '../utils/app_colors.dart';
import '../utils/static.dart';

class CustomSliderOnBoarding extends StatelessWidget {
  const CustomSliderOnBoarding({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = context.read<OnBoardingControllerImp>();
    final colors = context.colors;

    return PageView.builder(
      controller: controller.pageController,
      itemCount: onBoardingList.length,
      onPageChanged: controller.onPageChanged,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(onBoardingList[i].title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: colors.textPrimary)),
            const SizedBox(height: 16),
            Expanded(
              child: Image.asset(
                onBoardingList[i].image,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              child: Text(
                onBoardingList[i].body,
                textAlign: TextAlign.center,
                style: TextStyle(
                    height: 1.6,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
