// lib/services/ai_assistant_service.dart
//
// ✅ خدمة الذكاء الاصطناعي المدمج — تتواصل مع endpoints الجديدة على
// souga-server (v2.9.0): /ask-product, /smart-search, /enhance-description,
// /summarize-reviews, /generate-seed-reviews.
//
// نفس نمط marketing_service.dart تماماً: timeout طويل لتحمّل cold start
// لخادم Render المجاني (حتى 55 ثانية)، retry تلقائي، ولا يُوقف أي عملية
// أخرى في التطبيق عند الفشل — كل دالة تُعيد نتيجة واضحة (نجاح/خطأ) بدل
// رمي استثناء يكسر الواجهة.
//
// الدوال المُنفَّذة (خمس دوال):
//   ✅ enhanceDescription()   — add_product_screen.dart
//   ✅ askProduct()           — product_detail_screen.dart ("اسأل سوجا")
//   ✅ summarizeReviews()     — product_detail_screen.dart ("ملخص Souga AI")
//   ✅ smartSearch()          — search_screen.dart (البحث الذكي)
//   ✅ generateSeedReviews()  — استدعاء صامت في الخلفية عند إضافة منتج جديد
//      أو عند فتح منتج قديم بلا تقييمات؛ يُولّد 10 تقييمات واقعية عبر
//      الخادم (Gemini)، والخادم نفسه يضمن عدم التكرار.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

// ✅ تحديث أمني (v3): كل دالة تستدعي endpoint محمي بـ requireAuth على
// الخادم أصبحت ترفق Firebase ID Token عبر ApiClient.authHeaders()، وتعرض
// رسالة عربية واضحة عند 401/403/429 بدل رسالة الخادم العامة فقط.
class AiAssistantService {
  static const String _serverUrl = ApiClient.serverBaseUrl;

  // ─────────────────────────────────────────────────────────────────────────
  //  تحسين وصف المنتج بأسلوب تسويقي احترافي
  // ─────────────────────────────────────────────────────────────────────────
  static Future<EnhanceDescriptionResult> enhanceDescription({
    required String productName,
    required String category,
    required String rawDescription,
    String price = '',
    String currencySymbol = '',
    int maxRetries = 2,
  }) async {
    Exception? lastErr;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('[AiAssistant] enhance-description attempt $attempt for: $productName');
        final res = await http.post(
          Uri.parse('$_serverUrl/enhance-description'),
          headers: await ApiClient.authHeaders(),
          body: jsonEncode({
            'productName':    productName,
            'category':       category,
            'rawDescription': rawDescription,
            'price':          price,
            'currencySymbol': currencySymbol,
          }),
        ).timeout(const Duration(seconds: 55));

        if (res.statusCode == 401 || res.statusCode == 403) {
          return EnhanceDescriptionResult.error(
              'auth', ApiClient.friendlyAuthError(res.statusCode));
        }
        if (res.statusCode == 429) {
          return EnhanceDescriptionResult.error(
              'rate_limit', ApiClient.friendlyAuthError(429));
        }
        if (res.statusCode == 503 && attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 6));
          continue;
        }
        if (res.statusCode != 200) {
          lastErr = Exception('HTTP ${res.statusCode}');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: attempt * 3));
            continue;
          }
          return EnhanceDescriptionResult.error('server_error', 'خطأ في الخادم. تحقق من الاتصال.');
        }

        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final enhanced = (body['enhanced'] ?? '').toString().trim();

        if (enhanced.isEmpty) {
          return EnhanceDescriptionResult.error('empty_response', 'لم يتمكن الذكاء الاصطناعي من تحسين الوصف. حاول مجدداً.');
        }

        return EnhanceDescriptionResult.success(
          enhanced,
          isFallback: body['note'] == 'fallback_template',
        );

      } on Exception catch (e) {
        lastErr = e;
        debugPrint('[AiAssistant] enhance-description attempt $attempt error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 5));
        }
      }
    }

    final msg = lastErr?.toString() ?? '';
    if (msg.contains('TimeoutException') || msg.contains('timeout')) {
      return EnhanceDescriptionResult.error(
          'timeout', 'انتهت مهلة الاتصال. الخادم قد يكون نائماً، أعد المحاولة.');
    }
    return EnhanceDescriptionResult.error('unknown', 'تعذر التواصل مع الخادم. تحقق من الاتصال.');
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  "اسأل سوجا"
  // ─────────────────────────────────────────────────────────────────────────
  static Future<AskProductResult> askProduct({
    required String productId,
    required String productName,
    String productDescription = '',
    String productPrice = '',
    String currencySymbol = '',
    String category = '',
    double rating = 0,
    int reviewCount = 0,
    String sellerName = '',
    required String question,
    int maxRetries = 2,
  }) async {
    Exception? lastErr;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('[AiAssistant] ask-product attempt $attempt for: $productName');
        final res = await http.post(
          Uri.parse('$_serverUrl/ask-product'),
          headers: await ApiClient.authHeaders(),
          body: jsonEncode({
            'productId':          productId,
            'productName':        productName,
            'productDescription': productDescription,
            'productPrice':       productPrice,
            'currencySymbol':     currencySymbol,
            'category':           category,
            'rating':             rating,
            'reviewCount':        reviewCount,
            'sellerName':         sellerName,
            'question':           question,
          }),
        ).timeout(const Duration(seconds: 55));

        if (res.statusCode == 401 || res.statusCode == 403) {
          return AskProductResult.error('auth', ApiClient.friendlyAuthError(res.statusCode));
        }
        if (res.statusCode == 429) {
          return AskProductResult.error('rate_limit', ApiClient.friendlyAuthError(429));
        }
        if (res.statusCode == 503 && attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 6));
          continue;
        }
        if (res.statusCode != 200) {
          lastErr = Exception('HTTP ${res.statusCode}');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: attempt * 3));
            continue;
          }
          return AskProductResult.error('server_error', 'خطأ في الخادم. تحقق من الاتصال.');
        }

        final body   = jsonDecode(res.body) as Map<String, dynamic>;
        final answer = (body['answer'] ?? '').toString().trim();

        if (answer.isEmpty) {
          return AskProductResult.error('empty_response', 'لم يتمكن سوجا من الإجابة الآن. حاول مجدداً.');
        }

        return AskProductResult.success(answer);

      } on Exception catch (e) {
        lastErr = e;
        debugPrint('[AiAssistant] ask-product attempt $attempt error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 5));
        }
      }
    }

    final msg = lastErr?.toString() ?? '';
    if (msg.contains('TimeoutException') || msg.contains('timeout')) {
      return AskProductResult.error(
          'timeout', 'انتهت مهلة الاتصال. الخادم قد يكون نائماً، أعد المحاولة.');
    }
    return AskProductResult.error('unknown', 'تعذر التواصل مع الخادم. تحقق من الاتصال.');
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ملخص التقييمات الذكي — كاش دائم في Firestore على السيرفر
  // ─────────────────────────────────────────────────────────────────────────
  static Future<ReviewSummaryResult> summarizeReviews({
    required String productId,
    int maxRetries = 2,
  }) async {
    Exception? lastErr;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('[AiAssistant] summarize-reviews attempt $attempt for: $productId');
        final res = await http.post(
          Uri.parse('$_serverUrl/summarize-reviews'),
          headers: await ApiClient.authHeaders(),
          body: jsonEncode({'productId': productId}),
        ).timeout(const Duration(seconds: 55));

        if (res.statusCode == 401 || res.statusCode == 403) {
          return ReviewSummaryResult.error('auth', ApiClient.friendlyAuthError(res.statusCode));
        }
        if (res.statusCode == 404) {
          return ReviewSummaryResult.error('not_found', 'المنتج غير موجود.');
        }
        if (res.statusCode == 503 && attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 6));
          continue;
        }
        if (res.statusCode != 200) {
          lastErr = Exception('HTTP ${res.statusCode}');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: attempt * 3));
            continue;
          }
          return ReviewSummaryResult.error('server_error', 'خطأ في الخادم.');
        }

        final body = jsonDecode(res.body) as Map<String, dynamic>;

        if (body['message'] == 'no_reviews' || body['summary'] == null) {
          return ReviewSummaryResult.noData();
        }

        final data = ReviewSummaryData.fromJson(
          body['summary'] as Map<String, dynamic>,
          fromCache: body['fromCache'] == true,
        );
        return ReviewSummaryResult.success(data);

      } on Exception catch (e) {
        lastErr = e;
        debugPrint('[AiAssistant] summarize-reviews attempt $attempt error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 5));
        }
      }
    }

    final msg = lastErr?.toString() ?? '';
    if (msg.contains('TimeoutException') || msg.contains('timeout')) {
      return ReviewSummaryResult.error('timeout', 'انتهت مهلة الاتصال.');
    }
    return ReviewSummaryResult.error('unknown', 'تعذر التواصل مع الخادم.');
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  البحث الذكي
  // ─────────────────────────────────────────────────────────────────────────
  static Future<SmartSearchResult> smartSearch({
    required String query,
    required List<Map<String, dynamic>> products,
    int maxRetries = 2,
  }) async {
    if (query.trim().isEmpty || products.isEmpty) {
      return SmartSearchResult.success(const []);
    }

    Exception? lastErr;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('[AiAssistant] smart-search attempt $attempt for: "$query" (${products.length} منتج)');
        final res = await http.post(
          Uri.parse('$_serverUrl/smart-search'),
          headers: await ApiClient.authHeaders(),
          body: jsonEncode({'query': query, 'products': products}),
        ).timeout(const Duration(seconds: 55));

        if (res.statusCode == 401 || res.statusCode == 403) {
          // البحث الذكي ميزة إضافية فقط — عند فشل التفويض (مثلاً زائر غير
          // مسجَّل) نُعيد فشلاً هادئاً بدل رسالة خطأ مزعجة، لأن الشاشة
          // تستمر بعرض نتائج البحث النصي الأساسي بأي حال.
          return SmartSearchResult.error('auth', ApiClient.friendlyAuthError(res.statusCode));
        }
        if (res.statusCode == 429) {
          return SmartSearchResult.error('rate_limit', ApiClient.friendlyAuthError(429));
        }
        if (res.statusCode == 503 && attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 6));
          continue;
        }
        if (res.statusCode != 200) {
          lastErr = Exception('HTTP ${res.statusCode}');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: attempt * 3));
            continue;
          }
          return SmartSearchResult.error('server_error', 'خطأ في الخادم.');
        }

        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (body['results'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map((e) => SmartSearchItem.fromJson(e))
            .where((item) => item.id.isNotEmpty)
            .toList();

        return SmartSearchResult.success(list);

      } on Exception catch (e) {
        lastErr = e;
        debugPrint('[AiAssistant] smart-search attempt $attempt error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 5));
        }
      }
    }

    final msg = lastErr?.toString() ?? '';
    if (msg.contains('TimeoutException') || msg.contains('timeout')) {
      return SmartSearchResult.error('timeout', 'انتهت مهلة الاتصال.');
    }
    return SmartSearchResult.error('unknown', 'تعذر التواصل مع الخادم.');
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  توليد 10 تقييمات تمهيدية ذكية لمنتج (استدعاء صامت في الخلفية).
  //  محاولة واحدة فقط عمداً — عملية غير تفاعلية وغير حرجة، والخادم مضمون
  //  الأمان من التكرار، فحتى فشلها لا يضر: ستُحاول تلقائياً لاحقاً عند
  //  أي زيارة أخرى للمنتج طالما لا يزال بلا تقييمات.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<SeedReviewsResult> generateSeedReviews({
    required String productId,
  }) async {
    try {
      debugPrint('[AiAssistant] generate-seed-reviews for: $productId');
      final res = await http.post(
        Uri.parse('$_serverUrl/generate-seed-reviews'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'productId': productId}),
      ).timeout(const Duration(seconds: 55));

      if (res.statusCode != 200) {
        return SeedReviewsResult.error('server_error', 'HTTP ${res.statusCode}');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return SeedReviewsResult.success(
        seeded: body['seeded'] == true,
        reason: body['reason']?.toString(),
      );
    } catch (e) {
      debugPrint('[AiAssistant] generate-seed-reviews error: $e');
      return SeedReviewsResult.error('unknown', e.toString());
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class EnhanceDescriptionResult {
  final String? enhanced;
  final String? errorCode;
  final String? errorMessage;
  final bool isFallback;

  bool get isSuccess => enhanced != null;

  const EnhanceDescriptionResult._({
    this.enhanced,
    this.errorCode,
    this.errorMessage,
    this.isFallback = false,
  });

  factory EnhanceDescriptionResult.success(String text, {bool isFallback = false}) =>
      EnhanceDescriptionResult._(enhanced: text, isFallback: isFallback);

  factory EnhanceDescriptionResult.error(String code, String msg) =>
      EnhanceDescriptionResult._(errorCode: code, errorMessage: msg);
}

// ─────────────────────────────────────────────────────────────────────────────
class AskProductResult {
  final String? answer;
  final String? errorCode;
  final String? errorMessage;

  bool get isSuccess => answer != null;

  const AskProductResult._({this.answer, this.errorCode, this.errorMessage});

  factory AskProductResult.success(String text) => AskProductResult._(answer: text);

  factory AskProductResult.error(String code, String msg) =>
      AskProductResult._(errorCode: code, errorMessage: msg);
}

// ─────────────────────────────────────────────────────────────────────────────
class ReviewSummaryData {
  final List<String> positives;
  final List<String> negatives;
  final int satisfactionPercent;
  final String summary;
  final bool fromCache;

  const ReviewSummaryData({
    required this.positives,
    required this.negatives,
    required this.satisfactionPercent,
    required this.summary,
    this.fromCache = false,
  });

  factory ReviewSummaryData.fromJson(Map<String, dynamic> json, {bool fromCache = false}) {
    final rawPercent = (json['satisfactionPercent'] as num?)?.round() ?? 0;
    return ReviewSummaryData(
      positives: (json['positives'] as List<dynamic>? ?? [])
          .map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(),
      negatives: (json['negatives'] as List<dynamic>? ?? [])
          .map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(),
      satisfactionPercent: rawPercent.clamp(0, 100).toInt(),
      summary: (json['summary'] ?? '').toString(),
      fromCache: fromCache,
    );
  }
}

class ReviewSummaryResult {
  final ReviewSummaryData? summary;
  final bool noData;
  final String? errorCode;
  final String? errorMessage;

  bool get isSuccess => errorCode == null && summary != null;

  const ReviewSummaryResult._({
    this.summary,
    this.noData = false,
    this.errorCode,
    this.errorMessage,
  });

  factory ReviewSummaryResult.success(ReviewSummaryData data) =>
      ReviewSummaryResult._(summary: data);

  factory ReviewSummaryResult.noData() => const ReviewSummaryResult._(noData: true);

  factory ReviewSummaryResult.error(String code, String msg) =>
      ReviewSummaryResult._(errorCode: code, errorMessage: msg);
}

// ─────────────────────────────────────────────────────────────────────────────
class SmartSearchItem {
  final String id;
  final String reason;

  const SmartSearchItem({required this.id, required this.reason});

  factory SmartSearchItem.fromJson(Map<String, dynamic> json) => SmartSearchItem(
        id:     (json['id']     ?? '').toString(),
        reason: (json['reason'] ?? '').toString(),
      );
}

class SmartSearchResult {
  final List<SmartSearchItem> results;
  final String? errorCode;
  final String? errorMessage;

  bool get isSuccess => errorCode == null;

  const SmartSearchResult._({this.results = const [], this.errorCode, this.errorMessage});

  factory SmartSearchResult.success(List<SmartSearchItem> results) =>
      SmartSearchResult._(results: results);

  factory SmartSearchResult.error(String code, String msg) =>
      SmartSearchResult._(errorCode: code, errorMessage: msg);
}

// ─────────────────────────────────────────────────────────────────────────────
class SeedReviewsResult {
  final bool seeded;
  final String? reason;
  final String? errorCode;
  final String? errorMessage;

  bool get isSuccess => errorCode == null;

  const SeedReviewsResult._({
    this.seeded = false,
    this.reason,
    this.errorCode,
    this.errorMessage,
  });

  factory SeedReviewsResult.success({required bool seeded, String? reason}) =>
      SeedReviewsResult._(seeded: seeded, reason: reason);

  factory SeedReviewsResult.error(String code, String msg) =>
      SeedReviewsResult._(errorCode: code, errorMessage: msg);
}
