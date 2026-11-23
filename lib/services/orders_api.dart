// lib/services/orders_api.dart
//
// ✅ واجهة التطبيق مع وحدة الطلبات في السيرفر (orders.js).
// كل عمليات الطلب (إنشاء/إلغاء/قبول/شحن/تسليم/دفع/نزاع) تمر من هنا فقط —
// قواعد Firestore لا تسمح للعميل بكتابة مستندات الطلبات مباشرة.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

class OrdersApiResult {
  final bool ok;
  final Map<String, dynamic> data;
  final String code;
  final String message;
  const OrdersApiResult._(this.ok, this.data, this.code, this.message);
  factory OrdersApiResult.success(Map<String, dynamic> d) =>
      OrdersApiResult._(true, d, '', '');
  factory OrdersApiResult.failure(String code, String message,
          [Map<String, dynamic> data = const {}]) =>
      OrdersApiResult._(false, data, code, message);
}

class OrdersApi {
  OrdersApi._();

  static const String _base = ApiClient.serverBaseUrl;

  /// مفتاح عدم تكرار: يُولَّد مرة لكل محاولة شراء، فإعادة الإرسال بعد انقطاع
  /// الشبكة لا تُنشئ طلباً ثانياً (السيرفر يعيد الطلب نفسه).
  static String newIdempotencyKey() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    return b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<OrdersApiResult> _post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      if (!headers.containsKey('Authorization')) {
        return OrdersApiResult.failure('unauthorized', 'يجب تسجيل الدخول أولاً.');
      }
      final res = await http
          .post(Uri.parse('$_base$path'), headers: headers, body: jsonEncode(body))
          .timeout(timeout);
      Map<String, dynamic> json = {};
      try {
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d is Map<String, dynamic>) json = d;
      } catch (_) {}
      if (res.statusCode >= 200 && res.statusCode < 300 && json['success'] == true) {
        return OrdersApiResult.success(json);
      }
      if (res.statusCode == 404 && json['error'] == null) {
        return OrdersApiResult.failure(
            'server_outdated', 'الخادم لم يُحدَّث بعد. حاول لاحقاً.');
      }
      final msg = (json['message'] ?? ApiClient.friendlyAuthError(res.statusCode)).toString();
      return OrdersApiResult.failure((json['error'] ?? 'error').toString(), msg, json);
    } on TimeoutException {
      return OrdersApiResult.failure(
          'timeout', 'انتهت مهلة الاتصال بالخادم. تحقق من الشبكة وأعد المحاولة.');
    } catch (e) {
      debugPrint('[OrdersApi] $path error: $e');
      return OrdersApiResult.failure('network', 'تعذّر الاتصال بالخادم. تحقق من الشبكة.');
    }
  }

  // ── المشتري ──────────────────────────────────────────────────────────────
  static Future<OrdersApiResult> create({
    required String idempotencyKey,
    required String paymentMethod,
    required Map<String, dynamic> address,
    required List<Map<String, dynamic>> items,
  }) =>
      _post('/orders/create', {
        'idempotencyKey': idempotencyKey,
        'paymentMethod': paymentMethod,
        'address': address,
        'items': items,
      }, timeout: const Duration(seconds: 70)); // استيقاظ الخادم المجاني قد يطول

  static Future<OrdersApiResult> cancel(String orderId, {String reason = ''}) =>
      _post('/orders/$orderId/cancel', {'reason': reason});

  /// البائع/المشرف: إزالة أصناف غير متوفرة من طلب قبل الشحن (indexes = مواضع الأصناف في الطلب)
  static Future<OrdersApiResult> removeLines(String orderId,
          {required List<int> indexes, required String reason}) =>
      _post('/orders/$orderId/remove-lines', {'indexes': indexes, 'reason': reason});

  static Future<OrdersApiResult> adminMarkPartialRefunded(String orderId, {String reference = ''}) =>
      _post('/admin/orders/$orderId/mark-partial-refunded', {'reference': reference});

  static Future<OrdersApiResult> confirmReceipt(String orderId) =>
      _post('/orders/$orderId/confirm-receipt', {});

  static Future<OrdersApiResult> submitProof({
    required String paymentId,
    required String transactionRef,
    String proofUrl = '',
    String payerPhone = '',
  }) =>
      _post('/payments/$paymentId/proof', {
        'transactionRef': transactionRef,
        'proofUrl': proofUrl,
        'payerPhone': payerPhone,
      });

  static Future<OrdersApiResult> openDispute({
    required String orderId,
    required String reason,
    required String details,
    String wanted = 'refund_full',
    List<String> evidence = const [],
  }) =>
      _post('/orders/$orderId/dispute', {
        'reason': reason,
        'details': details,
        'wanted': wanted,
        'evidence': evidence,
      });

  // ── البائع ───────────────────────────────────────────────────────────────
  static Future<OrdersApiResult> accept(String orderId) =>
      _post('/orders/$orderId/status', {'status': 'confirmed'});

  static Future<OrdersApiResult> ship(
    String orderId, {
    String deliveryMethod = 'seller',
    String trackingNumber = '',
    String carrierName = '',
  }) =>
      _post('/orders/$orderId/status', {
        'status': 'shipped',
        'deliveryMethod': deliveryMethod,
        'trackingNumber': trackingNumber,
        'carrierName': carrierName,
      });

  static Future<OrdersApiResult> deliver(String orderId, String code) =>
      _post('/orders/$orderId/deliver', {'code': code});

  static Future<OrdersApiResult> failDelivery(String orderId,
          {required String reason, bool isFinal = false}) =>
      _post('/orders/$orderId/fail-delivery', {'reason': reason, 'final': isFinal});

  static Future<OrdersApiResult> replyDispute(String orderId, String message) =>
      _post('/disputes/$orderId/reply', {'message': message});

  // ── المشرف ───────────────────────────────────────────────────────────────
  static Future<OrdersApiResult> adminVerifyPayment(String paymentId,
          {required bool approve, String reason = ''}) =>
      _post('/admin/payments/$paymentId/verify', {'approve': approve, 'reason': reason});

  static Future<OrdersApiResult> adminResolveDispute(String orderId,
          {required String decision, double? amount, String note = ''}) =>
      _post('/admin/disputes/$orderId/resolve', {
        'decision': decision,
        if (amount != null) 'amount': amount,
        'note': note,
      });

  static Future<OrdersApiResult> adminMarkRefunded(String orderId, {String reference = ''}) =>
      _post('/admin/orders/$orderId/mark-refunded', {'reference': reference});

  /// استئناف بائع أُوقف تلقائياً بسبب تجاوز مهل القبول
  static Future<OrdersApiResult> adminResumeSeller(String sellerId) =>
      _post('/admin/sellers/$sellerId/resume', {});

  /// تسجيل دفعة مستحقات لبائع (بعد تحويل المبلغ فعلياً خارج التطبيق)
  static Future<OrdersApiResult> adminPayout({
    required String sellerId,
    required String currency,
    required double amount,
    String reference = '',
  }) =>
      _post('/admin/payouts', {
        'sellerId': sellerId,
        'currency': currency,
        'amount': amount,
        'reference': reference,
      });

  /// تسوية عمولة الدفع عند الاستلام: cash = سدّدها البائع، offset = تُخصم من رصيده المتاح
  static Future<OrdersApiResult> adminSettleCommission({
    required String sellerId,
    required String currency,
    required double amount,
    required bool offset,
    String reference = '',
  }) =>
      _post('/admin/commissions/settle', {
        'sellerId': sellerId,
        'currency': currency,
        'amount': amount,
        'mode': offset ? 'offset' : 'cash',
        'reference': reference,
      });

  static Future<OrdersApiResult> adminResetDelivery(String orderId) =>
      _post('/admin/orders/$orderId/reset-delivery', {});

  // ── مهام المهل ───────────────────────────────────────────────────────────
  /// يُستدعى عند فتح شاشات الطلبات (بصمت) ليُنفّذ السيرفر المهل المنتهية
  /// حتى لو كان نائماً أثناء انتهائها.
  static Future<void> sweep() async {
    await _post('/orders/sweep', {}, timeout: const Duration(seconds: 15));
  }
}

/// إعدادات الطلبات (مستند app_config/orders) — قراءة عامة، والتعديل للمشرف
/// من لوحة Firebase أو Console بلا نشر تطبيق جديد.
class OrdersConfig {
  final bool codEnabled;
  final bool hasabEnabled;
  final int payHoldMinutes;
  final int protectionDays;
  final int codMaxSellers;
  final Map<String, double> shippingFee;
  final String hasabName;
  final String hasabNumber;
  final String hasabNote;

  const OrdersConfig({
    this.codEnabled = true,
    this.hasabEnabled = true,
    this.payHoldMinutes = 30,
    this.protectionDays = 3,
    this.codMaxSellers = 3,
    this.shippingFee = const {},
    this.hasabName = '',
    this.hasabNumber = '',
    this.hasabNote = '',
  });

  /// هل بيانات حساب حاسب مضبوطة؟ (بدونها لا نعرض الخيار للمشتري)
  bool get hasabReady => hasabEnabled && hasabNumber.trim().isNotEmpty;

  static OrdersConfig? _cache;
  static DateTime _cacheAt = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<OrdersConfig> load({bool force = false}) async {
    if (!force && _cache != null && DateTime.now().difference(_cacheAt).inMinutes < 5) {
      return _cache!;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('orders')
          .get();
      final m = snap.data() ?? {};
      final methods = Map<String, dynamic>.from(m['methods'] as Map? ?? {});
      final acc = Map<String, dynamic>.from(m['hasabAccount'] as Map? ?? {});
      final fee = <String, double>{};
      (m['shippingFee'] as Map? ?? {}).forEach((k, v) {
        if (v is num) fee[k.toString()] = v.toDouble();
      });
      _cache = OrdersConfig(
        codEnabled: methods['cash_on_delivery'] != false,
        hasabEnabled: methods['hasab'] != false,
        payHoldMinutes: (m['payHoldMinutes'] as num?)?.toInt() ?? 30,
        protectionDays: (m['protectionDays'] as num?)?.toInt() ?? 3,
        codMaxSellers: (m['codMaxSellers'] as num?)?.toInt() ?? 3,
        shippingFee: fee,
        hasabName: (acc['name'] ?? '').toString(),
        hasabNumber: (acc['number'] ?? '').toString(),
        hasabNote: (acc['note'] ?? '').toString(),
      );
      _cacheAt = DateTime.now();
    } catch (e) {
      debugPrint('[OrdersConfig] load failed: $e');
      _cache ??= const OrdersConfig();
    }
    return _cache!;
  }
}
