// lib/services/api_client.dart
//
// ✅ جديد — طبقة موحّدة لإرفاق Firebase ID Token في طلبات الخادم المحمية.
// يُستخدم بدل بناء الهيدرز يدوياً في كل خدمة على حدة، لضمان أن كل نقطة
// نهاية تتطلب Authorization ترسله بشكل متسق من كل مكان في التطبيق.
import 'package:firebase_auth/firebase_auth.dart';

class ApiClient {
  ApiClient._();

  /// ✅ مصدر واحد لرابط خادم سوجا بدل تكراره حرفياً في أكثر من ملف خدمة
  /// (كان مكرراً سابقاً في ai_assistant_service/imagekit_service/
  /// marketing_service/push_notification_service — مصدر أخطاء عند تغيير
  /// البيئة). لتبديل البيئة (dev/staging/prod) مستقبلاً، عدّل هذا السطر
  /// فقط، أو حوّله لاحقاً إلى قراءة من `--dart-define`.
  static const String serverBaseUrl = 'https://souga-server.onrender.com';

  /// يُعيد هيدرز JSON قياسية، مع إضافة Authorization: Bearer <idToken>
  /// إن كان هناك مستخدم Firebase حقيقي مسجَّل دخوله حالياً.
  /// ملاحظة: وضع "الزائر" المحلي (uid == 'guest') ليس جلسة Firebase Auth
  /// فعلية، لذا لن يحصل على توكن — نقاط النهاية المحمية بـ requireAuth على
  /// الخادم ستُعيد 401 لطلبات الزوار عمداً (قرار أمني واضح: ميزات الذكاء
  /// الاصطناعي تتطلب تسجيل دخول حقيقي).
  static Future<Map<String, String>> authHeaders({
    Map<String, String>? extra,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      ...?extra,
    };
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (_) {
      // فشل جلب التوكن لا يجب أن يوقف الطلب — سيُرفض من الخادم بـ 401
      // برسالة عربية واضحة تُعرض للمستخدم بدل عطل صامت.
    }
    return headers;
  }

  /// رسالة عربية موحّدة عند فشل التفويض (401/403)، لاستخدامها في كل خدمة.
  static String friendlyAuthError(int statusCode) {
    if (statusCode == 401) {
      return 'يجب تسجيل الدخول لاستخدام هذه الميزة.';
    }
    if (statusCode == 403) {
      return 'لا تملك صلاحية القيام بهذه العملية.';
    }
    if (statusCode == 429) {
      return 'عدد الطلبات تجاوز الحد المسموح، يرجى المحاولة لاحقاً.';
    }
    return 'حدث خطأ غير متوقع. حاول مجدداً.';
  }
}
