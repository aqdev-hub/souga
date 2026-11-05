// lib/models/onboarding_model.dart
//
// ✅ نفس الكلاس والاسم كما وردا في الملف المرفوع — فقط نُقل لمجلد
// lib/models/ ليتوافق مع بنية المشروع (بجانب product_model.dart, user_model.dart...).
//
// تحسين بسيط: الحقول أصبحت required (بدل nullable) لأنها دائماً مُمرَّرة في
// static.dart، فلا حاجة لعلامة `!` عند القراءة في customslideronboarding.dart.
class OnBoardingModel {
  final String title;
  final String image;
  final String body;
  const OnBoardingModel({
    required this.title,
    required this.image,
    required this.body,
  });
}
