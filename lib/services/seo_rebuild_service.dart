// lib/services/seo_rebuild_service.dart
//
// ✅ جديد — يُستدعى بعد أي إضافة/تعديل/حذف منتج لتحديث صفحات SEO الثابتة
// على Firebase Hosting (souga-server يُولِّدها وينشرها فعلياً — راجع
// souga-server/ssg/). الاستدعاء دائماً "أطلق ولا تنتظر" (Fire-and-forget)
// عبر unawaited() من نقاط الاستدعاء، حتى لا يشعر البائع/الأدمن بأي تأخير
// إضافي عند حفظ منتج — تماماً كما طلبت ("بدون انتظار المستخدم").
//
// الفشل هنا صامت تماماً وغير حرج بتصميم مقصود: فشل استدعاء /rebuild لا
// يعني فشل حفظ المنتج نفسه (الذي تم بنجاح بالفعل في Firestore)، فقط يعني
// أن صفحة SEO الثابتة له لن تتحدَّث فوراً — والخادم مُصمَّم أصلاً لتجميع
// عدة طلبات متقاربة في عملية نشر واحدة، فلا داعٍ لإعادة محاولة معقّدة هنا.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class SeoRebuildService {
  static Future<void> triggerRebuild({String reason = ''}) async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.post(
        Uri.parse('${ApiClient.serverBaseUrl}/rebuild'),
        headers: headers,
        body: jsonEncode({'reason': reason}),
      ).timeout(const Duration(seconds: 20));
      debugPrint('[SeoRebuild] status=${res.statusCode} body=${res.body}');
    } catch (e) {
      // صامت عمداً — راجع الشرح أعلى الملف.
      debugPrint('[SeoRebuild] فشل استدعاء /rebuild (غير حرج): $e');
    }
  }
}
