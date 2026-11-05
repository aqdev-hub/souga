// lib/services/deep_link_service.dart
//
// ✅ خدمة Deep Link — بدون أي حزمة خارجية (uni_links / app_links)
//
// تستقبل الرابط من الجهة الأصلية (MainActivity.kt) عبر MethodChannel باسم
// "souga/deeplink"، وتدعم صيغتين:
//   1) souga://product/PRODUCT_ID          (Deep Link من داخل التطبيق)
//   2) https://souga-5fdb3.web.app/product/PRODUCT_ID  (رابط الويب نفسه لو فُتح كـ App Link)
//
// آلية العمل:
//   - عند بدء التطبيق (main): DeepLinkService.init() تُستدعى مرة واحدة.
//   - تسجّل مستمع onNewLink (للروابط أثناء عمل التطبيق بالخلفية).
//   - تطلب getInitialLink من الجهة الأصلية (لحالة فتح التطبيق حديثاً من الرابط).
//   - عند وجود رابط صالح: تُحمّل بيانات المنتج من Firestore ثم تفتح
//     ProductDetailScreen فوق الشاشة الحالية عبر navigatorKey العام.
//
// ✅ جديد — openProductByIdWhenReady(): دالة عامة مُستخرَجة من نفس منطق
// فتح المنتج (fetch من Firestore + انتظار جاهزية الـ Navigator)، بدون أي
// تغيير في السلوك الأصلي، لإعادة استخدامها من push_notification_service.dart
// عند الضغط على إشعار Push يحمل معرّف منتج مباشرة (وليس رابطاً نصياً).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product_model.dart';
import '../screens/customer/product_detail_screen.dart';

class DeepLinkService {
  DeepLinkService._();

  static const MethodChannel _channel = MethodChannel('souga/deeplink');

  /// يُستخدم في MaterialApp(navigatorKey: DeepLinkService.navigatorKey)
  /// حتى نتمكن من فتح شاشات جديدة دون الحاجة لـ BuildContext من مكان محدد.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _initialized = false;

  /// يُستدعى مرة واحدة فقط من main() بعد تهيئة Firebase وقبل runApp.
  static void init() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler(_handleNativeCall);
    _fetchInitialLink();
  }

  static Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onNewLink') {
      final link = call.arguments as String?;
      if (link != null && link.isNotEmpty) {
        _openProductWhenReady(link);
      }
    }
    return null;
  }

  static Future<void> _fetchInitialLink() async {
    try {
      final link = await _channel.invokeMethod<String>('getInitialLink');
      if (link != null && link.isNotEmpty) {
        _openProductWhenReady(link);
      }
    } catch (e) {
      debugPrint('[DeepLink] getInitialLink error: $e');
    }
  }

  /// ينتظر حتى يصبح الـ Navigator جاهزاً (بعد أول إطار) ثم يفتح المنتج
  /// من رابط نصي (souga://product/ID أو رابط الويب).
  static void _openProductWhenReady(String link, {int attempt = 0}) {
    const maxAttempts = 40; // ~12 ثانية كحد أقصى
    if (navigatorKey.currentState != null) {
      _openProduct(link);
      return;
    }
    if (attempt >= maxAttempts) {
      debugPrint('[DeepLink] navigator not ready, giving up: $link');
      return;
    }
    Future.delayed(const Duration(milliseconds: 300),
        () => _openProductWhenReady(link, attempt: attempt + 1));
  }

  static String? _extractProductId(String rawLink) {
    try {
      final uri = Uri.parse(rawLink);
      final segments =
          uri.pathSegments.where((s) => s.trim().isNotEmpty).toList();

      // souga://product/ID  → host = "product", pathSegments = ["ID"]
      if (uri.scheme == 'souga' && uri.host == 'product' && segments.isNotEmpty) {
        return segments.first;
      }

      // https://souga-5fdb3.web.app/product/ID → pathSegments = ["product","ID"]
      final idx = segments.indexOf('product');
      if (idx != -1 && idx + 1 < segments.length) {
        return segments[idx + 1];
      }

      // احتياطي: ?product=ID
      final qp = uri.queryParameters['product'];
      if (qp != null && qp.trim().isNotEmpty) return qp;

      return null;
    } catch (e) {
      debugPrint('[DeepLink] parse error: $e for $rawLink');
      return null;
    }
  }

  static Future<void> _openProduct(String rawLink) async {
    final productId = _extractProductId(rawLink);
    if (productId == null || productId.isEmpty) {
      debugPrint('[DeepLink] no productId found in: $rawLink');
      return;
    }
    await _openProductById(productId);
  }

  // ✅ جديد — نقطة دخول عامة: انتظار جاهزية الـ Navigator ثم فتح منتج
  // مباشرة بمعرّفه (بدون الحاجة لرابط نصي كامل). تُستخدم من إشعارات Push
  // التي تحمل productId في حمولة البيانات مباشرة.
  static void openProductByIdWhenReady(String productId, {int attempt = 0}) {
    const maxAttempts = 40; // ~12 ثانية كحد أقصى
    if (navigatorKey.currentState != null) {
      _openProductById(productId);
      return;
    }
    if (attempt >= maxAttempts) {
      debugPrint('[DeepLink] navigator not ready, giving up product: $productId');
      return;
    }
    Future.delayed(const Duration(milliseconds: 300),
        () => openProductByIdWhenReady(productId, attempt: attempt + 1));
  }

  // ✅ جديد — الجزء المشترك (جلب من Firestore + التنقّل) المُستخرَج من
  // المنطق الأصلي لـ _openProduct، بدون أي تغيير سلوكي.
  static Future<void> _openProductById(String productId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      if (!doc.exists || doc.data() == null) {
        debugPrint('[DeepLink] product not found: $productId');
        return;
      }

      final product = ProductModel.fromMap(doc.data()!, doc.id);

      final nav = navigatorKey.currentState;
      if (nav == null) return;

      nav.push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
      );
    } catch (e) {
      debugPrint('[DeepLink] fetch product error: $e');
    }
  }
}
