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
// ✅ سلوك الإشعارات (نمط فيسبوك):
//   - التطبيق مغلق/بالخلفية: قناة souga_high (أهمية عالية، تُنشأ في MainActivity.kt)
//     تجعل الإشعار منبثقاً فوق الشاشة بصوت واهتزاز ثم يبقى في شريط الإشعارات.
//   - التطبيق مفتوح: بانر منبثق داخلي (InAppBanner) لأن النظام لا يعرض إشعار FCM حينها.
//   - النقر في كل الحالات: NotificationRouter يفتح المحتوى (منتج/طلبات/محادثة).

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../widgets/in_app_banner.dart';
import 'api_client.dart';
import 'notification_router.dart';

class PushNotificationService {
  static const String _serverUrl = ApiClient.serverBaseUrl;
  static bool _listenersAttached = false;
  static String? _initializedUid;
  static final Map<String, DateTime> _chatThrottle = {};
  static const String _guestTopic = 'guests';

  // ─────────────────────────────────────────────────────────────────────────
  //  موضوع 'guests': كل جهاز ليس عليه حساب مسجَّل (زائر / خرج من حسابه) يشترك فيه،
  //  فتصله حملات المنتجات الجديدة حتى لو لم يسجّل دخوله أبداً.
  //  عند تسجيل الدخول يُلغى الاشتراك (رمزه يُحفظ على حسابه) فلا يصله الإشعار مرتين.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> ensureGuestTopic() async {
    try {
      final m = FirebaseMessaging.instance;
      await m.requestPermission(alert: true, badge: true, sound: true);
      await m.subscribeToTopic(_guestTopic);
    } catch (e) {
      debugPrint('[Push] guest topic error: $e');
    }
  }

  static Future<void> _leaveGuestTopic() async {
    try { await FirebaseMessaging.instance.unsubscribeFromTopic(_guestTopic); } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  التهيئة — تُستدعى فور توفّر مستخدم مسجَّل (وليس زائراً)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> init({required String uid}) async {
    if (uid.isEmpty || uid == 'guest') { return; }
    if (_initializedUid == uid) { return; } // Wrapper يُعيد البناء كثيراً — نهيّئ مرة واحدة لكل حساب
    _initializedUid = uid;

    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );

      await _refreshAndSaveToken(uid);
      unawaited(_leaveGuestTopic());

      if (!_listenersAttached) {
        _listenersAttached = true;

        // تحديث الرمز تلقائياً إن تغيّر (نادر لكن يحدث)
        messaging.onTokenRefresh.listen((newToken) {
          _saveToken(uid, newToken);
        });

        // إشعار وصل والتطبيق مفتوح — نسجّله فقط (راجع الملاحظة أعلى الملف)
        FirebaseMessaging.onMessage.listen(_handleForeground);

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
    reset();
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid)
          .set({'fcmToken': FieldValue.delete()}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Push] clearToken error: $e');
    }
    // بعد الخروج يبقى الجهاز يستقبل حملات المنتجات كزائر
    unawaited(ensureGuestTopic());
  }

  static void _handleMessageTap(RemoteMessage message) {
    final d = message.data;
    NotificationRouter.open(
      type: (d['type'] ?? '').toString(),
      referenceId: (d['referenceId'] ?? '').toString(),
      productId: (d['productId'] ?? '').toString(),
    );
  }

  /// التطبيق مفتوح: بانر منبثق بدل الإشعار الصامت
  static void _handleForeground(RemoteMessage message) {
    final n = message.notification;
    final d = message.data;
    final title = (n?.title ?? d['title'] ?? '').toString();
    final body  = (n?.body  ?? d['body']  ?? '').toString();
    if (title.isEmpty && body.isEmpty) return;
    InAppBanner.show(
      title: title.isEmpty ? 'سوجا' : title,
      body: body,
      imageUrl: n?.android?.imageUrl ?? n?.apple?.imageUrl,
      onTap: () => _handleMessageTap(message),
    );
  }

  /// يُعاد ضبطه عند تسجيل الخروج ليُهيَّأ الحساب التالي.
  static void reset() { _initializedUid = null; }

  /// إشعار نظام لمستخدم محدد (طلب جديد / تحديث حالة) عبر /notify-user.
  /// "أطلق وانسَ": أي فشل لا يعطّل العملية الأصلية.
  static Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    required String referenceId,
    String imageUrl = '',
  }) async {
    try {
      await http.post(
        Uri.parse('$_serverUrl/notify-user'),
        headers: await ApiClient.authHeaders(),
        body: jsonEncode({
          'userId': userId,
          'title': title,
          'body': body,
          'type': type,
          'referenceId': referenceId,
          if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        }),
      ).timeout(const Duration(seconds: 55));
    } catch (e) {
      debugPrint('[Push] sendToUser error: $e');
    }
  }

  /// إشعار رسالة محادثة للطرف الآخر (السيرفر يتحقق أن الطرفين في الغرفة).
  /// مُخنَّق (لكل غرفة مرة كل 15ث) حتى لا تُغرق المستلم ولا تستهلك حد الإرسال.
  static Future<void> notifyChat({
    required String receiverId,
    required String roomId,
    required String senderName,
    required String text,
  }) async {
    final last = _chatThrottle[roomId];
    if (last != null && DateTime.now().difference(last).inSeconds < 15) return;
    _chatThrottle[roomId] = DateTime.now();
    try {
      await http.post(
        Uri.parse('$_serverUrl/notify-user'),
        headers: await ApiClient.authHeaders(),
        body: jsonEncode({
          'userId': receiverId,
          'title': '💬 $senderName',
          'body': text.length > 120 ? '${text.substring(0, 120)}…' : text,
          'type': 'chat',
          'referenceId': roomId,
        }),
      ).timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('[Push] notifyChat error: $e');
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
