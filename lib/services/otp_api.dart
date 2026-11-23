// lib/services/otp_api.dart
//
// واجهة التطبيق مع وحدة auth_otp.js في السيرفر:
//   تأكيد البريد:   /auth/otp/send  ·  /auth/otp/verify       (يتطلب تسجيل دخول)
//   نسيت كلمة السر: /auth/password/forgot · /verify · /reset  (بلا تسجيل دخول)

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class OtpException implements Exception {
  final String code;
  final String message;
  final int? attemptsLeft;
  final int? retryAfter;
  const OtpException(this.code, this.message, {this.attemptsLeft, this.retryAfter});

  /// رمز خاطئ (يمكن المحاولة ثانية)
  bool get isWrongCode => code == 'wrong_code';

  /// الرمز لم يعد صالحاً: يجب طلب رمز جديد
  bool get needsNewCode => const {'expired', 'locked', 'no_code'}.contains(code);

  /// تم الإرسال قبل قليل (فاصل 60 ثانية)
  bool get isCooldown => code == 'cooldown';

  @override
  String toString() => message;
}

class OtpSendResult {
  final String maskedEmail;
  final int expiresInSeconds;
  final int cooldownSeconds;
  final bool alreadyVerified;
  const OtpSendResult({
    this.maskedEmail = '',
    this.expiresInSeconds = 600,
    this.cooldownSeconds = 60,
    this.alreadyVerified = false,
  });
}

class OtpApi {
  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    required bool auth,
  }) async {
    final headers = auth
        ? await ApiClient.authHeaders()
        : <String, String>{'Content-Type': 'application/json; charset=utf-8'};
    http.Response res;
    try {
      // مهلة طويلة: خادم Render المجاني قد يحتاج ~40 ثانية للاستيقاظ
      res = await http
          .post(Uri.parse('${ApiClient.serverBaseUrl}$path'),
              headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const OtpException('timeout', 'الخادم يستغرق وقتاً أطول من المعتاد. حاول مرة أخرى.');
    } catch (_) {
      throw const OtpException('network', 'تعذّر الاتصال. تحقق من الإنترنت وأعد المحاولة.');
    }

    Map<String, dynamic> data = {};
    try {
      final d = jsonDecode(utf8.decode(res.bodyBytes));
      if (d is Map<String, dynamic>) data = d;
    } catch (_) {}

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    final code = (data['error'] ?? 'error').toString();
    var msg = (data['message'] ?? '').toString();
    if (msg.isEmpty) msg = ApiClient.friendlyAuthError(res.statusCode);
    throw OtpException(
      code,
      msg,
      attemptsLeft: data['attemptsLeft'] is num ? (data['attemptsLeft'] as num).toInt() : null,
      retryAfter: data['retryAfterSeconds'] is num ? (data['retryAfterSeconds'] as num).toInt() : null,
    );
  }

  static OtpSendResult _sendResult(Map<String, dynamic> d) => OtpSendResult(
        maskedEmail: (d['maskedEmail'] ?? '').toString(),
        expiresInSeconds: (d['expiresInSeconds'] as num?)?.toInt() ?? 600,
        cooldownSeconds: (d['cooldownSeconds'] as num?)?.toInt() ?? 60,
        alreadyVerified: d['alreadyVerified'] == true,
      );

  // ── تأكيد البريد ───────────────────────────────────────────────────────
  static Future<OtpSendResult> sendVerification() async =>
      _sendResult(await _post('/auth/otp/send', {}, auth: true));

  static Future<void> verifyEmail(String code) async {
    await _post('/auth/otp/verify', {'code': code}, auth: true);
  }

  // ── تشخيص البريد (مشرف) ────────────────────────────────────────────────
  /// يرسل رسالة تجريبية ويُرجع رد السيرفر كاملاً: success/config.problems/detail
  static Future<Map<String, dynamic>> adminMailTest(String to) async {
    final headers = await ApiClient.authHeaders();
    try {
      final res = await http
          .post(Uri.parse('${ApiClient.serverBaseUrl}/admin/mail-test'),
              headers: headers, body: jsonEncode({'to': to}))
          .timeout(const Duration(seconds: 60));
      final d = jsonDecode(utf8.decode(res.bodyBytes));
      if (d is Map<String, dynamic>) {
        return {'httpStatus': res.statusCode, ...d};
      }
      return {'httpStatus': res.statusCode, 'success': false, 'message': 'رد غير متوقع'};
    } catch (e) {
      return {'httpStatus': 0, 'success': false, 'message': 'تعذّر الاتصال بالخادم: $e'};
    }
  }

  // ── استعادة كلمة المرور ────────────────────────────────────────────────
  static Future<OtpSendResult> forgotPassword(String email) async =>
      _sendResult(await _post('/auth/password/forgot', {'email': email}, auth: false));

  /// يُرجع resetToken قصير العمر
  static Future<String> verifyReset(String email, String code) async {
    final d = await _post('/auth/password/verify', {'email': email, 'code': code}, auth: false);
    return (d['resetToken'] ?? '').toString();
  }

  static Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    await _post('/auth/password/reset',
        {'email': email, 'resetToken': resetToken, 'newPassword': newPassword},
        auth: false);
  }
}
