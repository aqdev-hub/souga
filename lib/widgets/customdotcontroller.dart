// lib/widgets/customdotcontroller.dart
//
// ✅ نفس اسم الكلاس تماماً (CustomDotControllerOnBoarding) — نُقل لمجلد
// lib/widgets/ ليتوافق مع بنية المشروع (بجانب product_card.dart,
// onboarding_overlay.dart...).
//
// ✅ تغيير: الألوان الثابتة (AppColor.primaryColor / AppColor.grey) استُبدلت
// بـ context.colors (نظام SougaColors الديناميكي المستخدم في كل شاشات
// المشروع) — لتتفاعل النقاط تلقائياً مع الوضع الفاتح/الداكن.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/onboarding_controller.dart';
import '../utils/app_colors.dart';
import '../utils/static.dart';

class CustomDotControllerOnBoarding extends StatelessWidget {
  const CustomDotControllerOnBoarding({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OnBoardingControllerImp>();
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(
            onBoardingList.length,
            (index) => AnimatedContainer(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  duration: const Duration(milliseconds: 900),
                  width: controller.currentPage == index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: controller.currentPage == index
                          ? colors.primary
                          : colors.border,
                      borderRadius: BorderRadius.circular(10)),
                ))
      ],
    );
  }
}
