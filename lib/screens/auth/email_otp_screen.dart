// lib/screens/auth/email_otp_screen.dart
//
// شاشة تأكيد البريد بعد إنشاء الحساب (رمز من 6 أرقام/أحرف).
// يعرضها Wrapper تلقائياً لأي مستخدم علمه needsEmailVerification = true،
// فتعمل أيضاً لو أغلق التطبيق أو سجّل الدخول لاحقاً قبل التأكيد.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/otp_api.dart';
import '../../utils/app_colors.dart';
import '../../widgets/auth_shell.dart';
import '../../widgets/otp_widgets.dart';

enum _Phase { booting, entering, verifying, success }

class EmailOtpScreen extends StatefulWidget {
  const EmailOtpScreen({super.key});

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> with SingleTickerProviderStateMixin {
  final _otpKey = GlobalKey<OtpInputState>();
  final _timerKey = GlobalKey<OtpTimerRowState>();
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  _Phase _phase = _Phase.booting;
  String _masked = '';
  String _error = '';
  String _info = '';
  int _cooldown = 0;
  int _expiry = 600;
  bool _codeReady = false; // 6 خانات مكتملة
  Timer? _autoContinue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _autoContinue?.cancel();
    _enter.dispose();
    super.dispose();
  }

  String get _email => context.read<AuthProvider>().currentUser?.email ?? '';

  /// 1) هل أُكِّد البريد مسبقاً (من جهاز آخر مثلاً)؟ 2) وإلا أرسل رمزاً.
  Future<void> _boot() async {
    final auth = context.read<AuthProvider>();
    if (await auth.checkEmailVerified()) {
      await auth.completeEmailVerification();
      return;
    }
    if (!mounted) return;
    _masked = maskEmail(_email);
    await _send(auto: true);
  }

  /// إرسال/إعادة إرسال. يُرجع النتيجة أو null عند الفشل.
  Future<OtpSendResult?> _send({bool auto = false}) async {
    setState(() {
      _error = '';
      if (!auto) _info = '';
    });
    try {
      final r = await OtpApi.sendVerification();
      if (!mounted) return r;
      if (r.alreadyVerified) {
        await context.read<AuthProvider>().completeEmailVerification();
        return r;
      }
      setState(() {
        _phase = _Phase.entering;
        _masked = r.maskedEmail.isNotEmpty ? r.maskedEmail : _masked;
        _cooldown = r.cooldownSeconds;
        _expiry = r.expiresInSeconds;
        _info = 'أرسلنا رمزاً جديداً إلى بريدك';
      });
      _timerKey.currentState?.reset(cooldown: r.cooldownSeconds, expiry: r.expiresInSeconds);
      _otpKey.currentState?.clear();
      return r;
    } on OtpException catch (e) {
      if (!mounted) return null;
      if (e.isCooldown) {
        // أُرسل رمز قبل لحظات (مثلاً أعاد المستخدم فتح التطبيق): نكمل بالرمز الموجود
        setState(() {
          _phase = _Phase.entering;
          _cooldown = e.retryAfter ?? 60;
          _info = 'سبق أن أرسلنا رمزاً إلى بريدك قبل قليل — أدخله أدناه';
        });
        _timerKey.currentState?.reset(cooldown: _cooldown, expiry: _expiry);
      } else {
        setState(() {
          _phase = _Phase.entering;
          _error = e.message;
          if (e.retryAfter != null) _cooldown = e.retryAfter!;
        });
        _timerKey.currentState?.reset(cooldown: _cooldown, expiry: 0);
      }
      return null;
    }
  }

  Future<void> _verify(String code) async {
    if (_phase == _Phase.verifying || _phase == _Phase.success) return;
    setState(() {
      _phase = _Phase.verifying;
      _error = '';
    });
    try {
      await OtpApi.verifyEmail(code);
      if (!mounted) return;
      // نتأكد من Firebase Auth نفسه قبل عرض النجاح
      await context.read<AuthProvider>().checkEmailVerified();
      if (!mounted) return;
      setState(() => _phase = _Phase.success);
      _autoContinue = Timer(const Duration(milliseconds: 3800), _continue);
    } on OtpException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.entering;
        _error = e.message;
      });
      _otpKey.currentState?.shake();
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      _otpKey.currentState?.clear();
      setState(() => _codeReady = false);
      if (e.needsNewCode) _timerKey.currentState?.reset(cooldown: 0, expiry: 0);
    }
  }

  Future<void> _continue() async {
    _autoContinue?.cancel();
    if (!mounted) return;
    await context.read<AuthProvider>().completeEmailVerification();
    // Wrapper يستبدل الشاشة تلقائياً
  }

  Future<void> _switchAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج؟'),
        content: const Text('يمكنك العودة لاحقاً وتأكيد بريدك بتسجيل الدخول إلى نفس الحساب.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('خروج')),
        ],
      ),
    );
    if (ok == true && mounted) await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.background,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(anim), child: child),
          ),
          child: _phase == _Phase.success ? _successView(c) : _formView(c),
        ),
      ),
    );
  }

  // ── نموذج الإدخال ──────────────────────────────────────────────────────
  Widget _formView(SougaColors c) {
    final busy = _phase == _Phase.verifying;
    return AuthShell(
      key: const ValueKey('form'),
      compact: true,
      title: 'تأكيد البريد الإلكتروني',
      headerAction: TextButton.icon(
        onPressed: _switchAccount,
        icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white),
        label: const Text('خروج', style: TextStyle(color: Colors.white)),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _enter, curve: const Interval(0.3, 1.0)),
        child: Column(
          children: [
            const OtpHero(icon: Icons.mark_email_unread_outlined, size: 64),
                    Text('أرسلنا رمزاً من 6 خانات (أرقام وحروف) إلى',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.textSecondary, fontSize: 14)),
                    const SizedBox(height: 6),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(_masked.isEmpty ? '...' : _masked,
                          style: TextStyle(
                              color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 26),
                    if (_phase == _Phase.booting)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Column(children: [
                          CircularProgressIndicator(color: c.primary),
                          const SizedBox(height: 14),
                          Text('جاري إرسال الرمز...', style: TextStyle(color: c.textSecondary)),
                        ]),
                      )
                    else ...[
                      OtpInput(
                        key: _otpKey,
                        enabled: !busy,
                        onChanged: (v) => setState(() => _codeReady = v.length == 6),
                        onCompleted: _verify,
                      ),
                      OtpPasteButton(otpKey: _otpKey),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: _error.isNotEmpty
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline, size: 18, color: c.error),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(_error,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: c.error, fontSize: 13, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                )
                              : _info.isNotEmpty
                                  ? Text(_info,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: c.success, fontSize: 13))
                                  : const SizedBox(height: 18),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_codeReady && !busy)
                              ? () => _verify(_otpKey.currentState?.value ?? '')
                              : null,
                          child: busy
                              ? const SizedBox(
                                  height: 22, width: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('تأكيد'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OtpTimerRow(
                        key: _timerKey,
                        initialCooldown: _cooldown,
                        initialExpiry: _expiry,
                        onResend: _send,
                      ),
                    ],
          ],
        ),
      ),
    );
  }

  // ── شاشة النجاح ────────────────────────────────────────────────────────
  Widget _successView(SougaColors c) {
    final name = context.read<AuthProvider>().currentUser?.name ?? '';
    final first = name.trim().isEmpty ? '' : name.trim().split(' ').first;
    return SafeArea(
      key: const ValueKey('success'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const OtpSuccessBurst(size: 130),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
              ),
              child: Column(children: [
                Text('تم تأكيد بريدك بنجاح',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.textPrimary)),
                const SizedBox(height: 10),
                Text(
                  first.isEmpty
                      ? 'حسابك جاهز الآن. ابدأ رحلتك في سوجا!'
                      : 'أهلاً بك يا $first، حسابك جاهز الآن.\nابدأ رحلتك في سوجا!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: c.textSecondary, height: 1.6),
                ),
              ]),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _continue,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('ابدأ الآن'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
