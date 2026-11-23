// lib/services/startup_tasks.dart
//
// مهام تُطلق مرة واحدة عند فتح التطبيق (كلها "أطلق وانسَ" ولا تؤخر ظهور الشاشة):
//   1) تسخين خادم Render المجاني (ينام بعد ~15 دقيقة، وأول طلب بعد النوم يأخذ ~50 ثانية).
//      بهذا يكون جاهزاً حين يطلب المستخدم رمز التحقق أو يسجّل أو ينسى كلمة المرور.
//   2) اشتراك الجهاز كزائر في موضوع الإشعارات إن لم يكن عليه حساب مسجَّل.
//
// الاستخدام في main.dart بعد Firebase.initializeApp:
//     unawaited(StartupTasks.run());

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'push_notification_service.dart';

class StartupTasks {
  static bool _ran = false;

  static Future<void> run() async {
    if (_ran) return;
    _ran = true;
    unawaited(warmUpServer());
    if (FirebaseAuth.instance.currentUser == null) {
      unawaited(PushNotificationService.ensureGuestTopic());
    }
  }

  /// يُستدعى أيضاً عند فتح شاشات الدخول/التسجيل/نسيت كلمة المرور.
  static Future<void> warmUpServer() async {
    try {
      await http
          .get(Uri.parse('${ApiClient.serverBaseUrl}/health'))
          .timeout(const Duration(seconds: 70));
    } catch (e) {
      debugPrint('[Startup] warm-up: $e');
    }
  }
}
