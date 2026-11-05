// lib/services/push_notification_service.dart
//
// ✅ خدمة الإشعارات الحقيقية (Push) عبر Firebase Cloud Messaging.
//
// المسؤوليات:
//   1. طلب إذن الإشعارات وتسجيل رمز الجهاز (FCM Token) في مستند المستخدم
//      (users/{uid}.fcmToken) فور تسجيل الدخول.
//   2. تحديث الرمز تلقائياً إن تغيّر (onTokenRefresh).
//   3. عند الضغط على إشعار (والتطبيق بالخلفية أو مغلق تماماً)، فتح صفحة
//      المنتج المقصود مباشرة — بإعادة استخدام آلية DeepLinkService نفسها.
//   4. حذف الرمز عند تسجيل الخروج، حتى لا تصل إشعارات حساب سابق لمستخدم
//      لاحق يستخدم نفس الجهاز.
//   5. استدعاء endpoint الإرسال الفعلي على السيرفر (souga-server) —
//      يُستخدم تلقائياً عند نشر منتج جديد، أو يدوياً من لوحة الإدارة.
//
// ⚠️ ملاحظة تقنية مهمة: هذا المشروع لا يستخدم حزمة إشعارات محلية
// (flutter_local_notifications) — فقط firebase_messaging كما اتُّفق عليه
// صراحة. النتيجة العملية:
//   - التطبيق بالخلفية أو مغلق: يعرض نظام أندرويد/iOS الإشعار تلقائياً في
//     شريط الإشعارات (بما فيها صورة المنتج) — سلوك FCM افتراضي، لا كود
//     إضافي مطلوب له.
//   - التطبيق مفتوح (foreground): الإشعار يصل عبر onMessage لكن لا يظهر
//     تلقائياً في شريط النظام (قيد معروف لعدم وجود حزمة محلية) — نكتفي
//     بتسجيله في السجل هنا؛ يمكن إضافة flutter_local_notifications لاحقاً
//     إن رغبت لعرضه كإشعار نظام حتى أثناء الاستخدام.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'deep_link_service.dart';
import 'api_client.dart';

class PushNotificationService {
  static const String _serverUrl = ApiClient.serverBaseUrl;
  static bool _listenersAttached = false;

  // ─────────────────────────────────────────────────────────────────────────
  //  التهيئة — تُستدعى فور توفّر مستخدم مسجَّل (وليس زائراً)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> init({required String uid}) async {
    if (uid.isEmpty || uid == 'guest') { return; }

    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );

      await _refreshAndSaveToken(uid);

      if (!_listenersAttached) {
        _listenersAttached = true;

        // تحديث الرمز تلقائياً إن تغيّر (نادر لكن يحدث)
        messaging.onTokenRefresh.listen((newToken) {
          _saveToken(uid, newToken);
        });

        // إشعار وصل والتطبيق مفتوح — نسجّله فقط (راجع الملاحظة أعلى الملف)
        FirebaseMessaging.onMessage.listen((message) {
          debugPrint('[Push] foreground message: ${message.data}');
        });

        // الضغط على الإشعار والتطبيق كان بالخلفية
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

        // التطبيق كان مغلقاً تماماً وفُتح عبر الضغط على الإشعار
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageTap(initialMessage);
        }
      }
    } catch (e) {
      debugPrint('[Push] init error: $e');
    }
  }

  static Future<void> _refreshAndSaveToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(uid, token);
      }
    } catch (e) {
      debugPrint('[Push] getToken error: $e');
    }
  }

  static Future<void> _saveToken(String uid, String token) async {
    if (uid.isEmpty || uid == 'guest') { return; }
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
      debugPrint('[Push] token saved for $uid');
    } catch (e) {
      debugPrint('[Push] saveToken error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  حذف الرمز عند تسجيل الخروج — يمنع وصول إشعارات الحساب القديم لأي
  //  مستخدم لاحق يستخدم نفس الجهاز الفعلي.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> clearToken(String? uid) async {
    if (uid == null || uid.isEmpty || uid == 'guest') { return; }
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid)
          .set({'fcmToken': FieldValue.delete()}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Push] clearToken error: $e');
    }
  }

  static void _handleMessageTap(RemoteMessage message) {
    final productId = message.data['productId'];
    if (productId != null && productId.toString().trim().isNotEmpty) {
      DeepLinkService.openProductByIdWhenReady(productId.toString());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  إرسال إشعار عن منتج عبر السيرفر — يُستدعى:
  //   - تلقائياً من add_product_screen.dart فور نشر منتج جديد (بدون
  //     title/body، يُبنى نص افتراضي من بيانات المنتج على السيرفر)
  //   - يدوياً من admin_products_screen.dart كحملة تسويقية بعنوان ونص
  //     مخصّصين لمنتج موجود
  // ─────────────────────────────────────────────────────────────────────────
  static Future<PushSendResult> sendProductNotification({
    required String productId,
    String? title,
    String? body,
  }) async {
    try {
      debugPrint('[Push] send-product-notification for: $productId');
      final res = await http.post(
        Uri.parse('$_serverUrl/send-product-notification'),
        headers: await ApiClient.authHeaders(),
        body: jsonEncode({
          'productId': productId,
          if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
          if (body  != null && body.trim().isNotEmpty)  'body': body.trim(),
        }),
      ).timeout(const Duration(seconds: 55)); // ⚠️ الخادم المجاني قد يكون نائماً (cold start)

      if (res.statusCode == 401 || res.statusCode == 403) {
        return PushSendResult.error(ApiClient.friendlyAuthError(res.statusCode));
      }
      if (res.statusCode != 200) {
        return PushSendResult.error('HTTP ${res.statusCode}');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return PushSendResult.success(
        sent:        (data['sent']        as num?)?.toInt() ?? 0,
        totalTokens: (data['totalTokens'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('[Push] sendProductNotification error: $e');
      return PushSendResult.error(e.toString());
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class PushSendResult {
  final bool isSuccess;
  final int sent;
  final int totalTokens;
  final String? errorMessage;

  const PushSendResult._({
    required this.isSuccess,
    this.sent = 0,
    this.totalTokens = 0,
    this.errorMessage,
  });

  factory PushSendResult.success({required int sent, required int totalTokens}) =>
      PushSendResult._(isSuccess: true, sent: sent, totalTokens: totalTokens);

  factory PushSendResult.error(String msg) =>
      PushSendResult._(isSuccess: false, errorMessage: msg);
}
