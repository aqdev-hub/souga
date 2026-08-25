// lib/services/imagekit_service.dart
//
//  ملاحظة على خطأ 400 "invalid signature":
//  هذا الخطأ سببه الجذري في خادم Render (التوقيع المحسوب هناك).
//  ما نفعله هنا: timeout أطول للـ cold start (50s)، retry، وعدم الحجب.
//  إذا استمر الخطأ 400 بعد هذه الإصلاحات، فالمشكلة في إعداد الخادم
//  وتحتاج لمراجعة كود الخادم على Render مباشرةً.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'api_client.dart';

class ImageKitService {
  static const String _authServerUrl = ApiClient.serverBaseUrl;
  static const String _uploadUrl     = 'https://upload.imagekit.io/api/v1/files/upload';
  static const String _urlEndpoint   = 'https://ik.imagekit.io/souga';
  static const String _fallbackKey   = 'public_tPZTO4fYiAymT+gU8S1231DtvMo=';
  static const Uuid   _uuid          = Uuid();

  // ─────────────────────────────────────────────────────────────────────────────
  //  اختيار صورة
  // ─────────────────────────────────────────────────────────────────────────────
  static Future<File?> pickImage({bool fromCamera = false}) async {
    try {
      final XFile? xFile = await ImagePicker().pickImage(
        source:       fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth:     1080,
        maxHeight:    1080,
        imageQuality: 80,
      );
      if (xFile != null) return File(xFile.path);
    } catch (e) {
      debugPrint('[ImageKit] pickImage error: $e');
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  جلب بيانات التوقيع من خادم Render
  //
  //  خادم Render Free يدخل في سُبات بعد 15 دقيقة من عدم الاستخدام.
  //  Cold start يستغرق 30–50 ثانية. لذلك timeout = 55s.
  // ─────────────────────────────────────────────────────────────────────────────
  static Future<Map<String, String>?> _getAuth() async {
    try {
      debugPrint('[ImageKit] Fetching auth token (may take time if server is sleeping)...');

      final response = await http
          .get(Uri.parse('$_authServerUrl/auth'))
          .timeout(const Duration(seconds: 55));

      debugPrint('[ImageKit] Auth status: ${response.statusCode}');
      debugPrint('[ImageKit] Auth body: ${response.body}');

      if (response.statusCode != 200) {
        debugPrint('[ImageKit] ❌ Auth HTTP error: ${response.statusCode}');
        return null;
      }

      final data      = jsonDecode(response.body) as Map<String, dynamic>;
      final token     = data['token']?.toString()     ?? '';
      final expire    = data['expire']?.toString()    ?? '';
      final signature = data['signature']?.toString() ?? '';
      // publicKey: قد لا يُرسله الخادم — نستخدم الـ fallback من الحساب
      final publicKey = data['publicKey']?.toString() ?? _fallbackKey;

      if (token.isEmpty || expire.isEmpty || signature.isEmpty) {
        debugPrint('[ImageKit] ❌ Auth fields missing: $data');
        return null;
      }

      debugPrint('[ImageKit] ✅ Auth token received. expire=$expire');
      return {
        'token':     token,
        'expire':    expire,
        'signature': signature,
        'publicKey': publicKey,
      };
    } catch (e) {
      debugPrint('[ImageKit] ❌ Auth exception: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  رفع الصورة
  //
  //  شريط التقدم (highWater — لا يتراجع أبداً حتى بين المحاولات):
  //    0–10%:  جلب التوقيع
  //    10–15%: قراءة الملف
  //    15–20%: بناء الطلب
  //    20–88%: محاكاة تدريجية أثناء انتظار الرد
  //    88–100%: رد ناجح
  //
  //  useUniqueFileName=true: ImageKit يُولّد اسماً فريداً بنفسه.
  //  هذا يتجنب أي mismatch محتمل بين الاسم في الطلب والتوقيع.
  //
  //  على خطأ 400: نُعيد المحاولة (لا نوقف فوراً) لأن:
  //    - المحاولة الأولى قد تكون انتهت بـ timeout
  //    - المحاولة الثانية قد تحصل على توقيع صحيح بعد استيقاظ الخادم
  //  إذا فشلت جميع المحاولات: نُعيد null — التسجيل لا يتأثر.
  // ─────────────────────────────────────────────────────────────────────────────
  static Future<String?> uploadImage(
    File imageFile,
    String folder, {
    void Function(double progress)? onProgress,
    int maxRetries = 3,
  }) async {
    double highWater = 0.0;

    void report(double p) {
      final clamped = p.clamp(0.0, 1.0);
      if (clamped > highWater) {
        highWater = clamped;
        onProgress?.call(highWater);
      }
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      Timer? progressTimer;
      try {
        debugPrint('[ImageKit] Attempt $attempt/$maxRetries — folder: $folder');
        report(0.02);

        // ── جلب التوقيع ──────────────────────────────────────────────────────
        final auth = await _getAuth();
        if (auth == null) {
          debugPrint('[ImageKit] ❌ Auth null — attempt $attempt');
          if (attempt < maxRetries) await Future.delayed(Duration(seconds: attempt * 3));
          continue;
        }
        report(0.10);

        // ── قراءة الملف ──────────────────────────────────────────────────────
        final bytes    = await imageFile.readAsBytes();
        final fileSize = bytes.length;
        final fileName = '${folder}_${_uuid.v4()}';
        debugPrint('[ImageKit] File: ${(fileSize / 1024).toStringAsFixed(1)} KB, name: $fileName');
        report(0.15);

        // ── بناء الطلب ───────────────────────────────────────────────────────
        final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
        request.fields['fileName']          = fileName;
        request.fields['folder']            = '/$folder';
        request.fields['token']             = auth['token']!;
        request.fields['expire']            = auth['expire']!;
        request.fields['signature']         = auth['signature']!;
        request.fields['publicKey']         = auth['publicKey']!;
        request.fields['useUniqueFileName'] = 'true';

        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: '$fileName.jpg'),
        );
        report(0.20);

        // ── محاكاة تقدم أثناء الإرسال ────────────────────────────────────────
        var simProgress = 0.20;
        final increment = fileSize < 300000 ? 0.06 : 0.03;
        progressTimer = Timer.periodic(const Duration(milliseconds: 400), (t) {
          if (simProgress < 0.86) {
            simProgress = (simProgress + increment).clamp(0.0, 0.86);
            report(simProgress);
          } else {
            t.cancel();
          }
        });

        // ── الإرسال ──────────────────────────────────────────────────────────
        final streamed = await request.send().timeout(const Duration(seconds: 120));
        final response = await http.Response.fromStream(streamed);
        progressTimer.cancel();
        progressTimer = null;

        debugPrint('[ImageKit] HTTP ${response.statusCode}: ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final url  = data['url']?.toString() ?? '';
          if (url.isNotEmpty) {
            report(1.0);
            debugPrint('[ImageKit] ✅ Uploaded: $url');
            return url;
          }
          debugPrint('[ImageKit] ❌ 200 but no url field');

        } else if (response.statusCode == 400) {
          // خطأ توقيع — نُعيد المحاولة للحصول على توقيع جديد
          debugPrint('[ImageKit] ❌ 400 signature error — will retry with fresh auth');

        } else if (response.statusCode == 401) {
          debugPrint('[ImageKit] ❌ 401 — retrying with new token');

        } else {
          debugPrint('[ImageKit] ❌ HTTP ${response.statusCode}');
        }

        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 3));
          // highWater لا يُعاد للخلف — يبقى عند آخر قيمة
        }

      } catch (e) {
        progressTimer?.cancel();
        progressTimer = null;
        debugPrint('[ImageKit] ❌ Exception attempt $attempt: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 3));
        }
      }
    }

    onProgress?.call(0.0);
    debugPrint('[ImageKit] ❌ All $maxRetries attempts failed');
    return null; // فشل الرفع — لا يمنع التسجيل
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  تحويلات CDN
  // ─────────────────────────────────────────────────────────────────────────────
  static String _tr(String url, String params) {
    if (url.isEmpty || !url.contains('ik.imagekit.io')) return url;
    return url.replaceFirst(_urlEndpoint, '$_urlEndpoint/$params');
  }

  static String thumbnailUrl(String url)   => _tr(url, 'tr:w-150,h-150,q-70,f-auto');
  static String productUrl(String url)     => _tr(url, 'tr:w-400,h-400,q-80,f-auto');
  static String productFullUrl(String url) => _tr(url, 'tr:w-800,h-800,q-85,f-auto');
  static String productAdminUrl(String url)   => _tr(url, 'tr:w-400,h-400,q-95,f-auto,e-sharpen-3');
  static String productWhiteBgUrl(String url) => _tr(url, 'tr:w-600,h-600,q-90,f-auto,bg-FFFFFF,cm-pad_resize,e-sharpen-2');
  static String avatarUrl(String url)         => _tr(url, 'tr:w-200,h-200,q-80,f-auto');
  static bool   isImageKitUrl(String url)  => url.isNotEmpty && url.contains('ik.imagekit.io');

  static String buildOptimizedUrl(String url,
          {int width = 400, int height = 400, int quality = 80}) =>
      _tr(url, 'tr:w-$width,h-$height,q-$quality,f-auto');
}
