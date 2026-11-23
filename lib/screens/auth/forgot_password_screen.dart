// lib/screens/auth/forgot_password_screen.dart
//
// استعادة كلمة المرور برمز من 6 خانات:
//   1) البريد  →  2) الرمز  →  3) كلمة مرور جديدة  →  4) نجاح (مع دخول مباشر)
// لا يكشف التطبيق ولا السيرفر هل البريد مسجَّل (نفس الرد دائماً).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/otp_api.dart';
import '../../services/startup_tasks.dart';
import '../../utils/app_colors.dart';
import '../../widgets/auth_shell.dart';
import '../../widgets/otp_widgets.dart';

enum _Step { email, code, password, done }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _passForm = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _otpKey = GlobalKey<OtpInputState>();
  final _timerKey = GlobalKey<OtpTimerRowState>();

  _Step _step = _Step.email;
  bool _busy = false;
  bool _showPass = false;
  String _error = '';
  String _masked = '';
  String _email = '';
  String _resetToken = '';
  String _newPassword = '';
  int _cooldown = 60;
  int _expiry = 600;
  bool _codeReady = false;

  @override
  void initState() {
    super.initState();
    StartupTasks.warmUpServer(); // تسخين الخادم قبل طلب الرمز
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  void _snack(String m, {bool err = true}) {
    final c = context.colors;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), backgroundColor: err ? c.error : c.success));
  }

  // ── 1) طلب الرمز ───────────────────────────────────────────────────────
  Future<OtpSendResult?> _sendCode({bool fromResend = false}) async {
    if (!fromResend) {
      if (!_emailForm.currentState!.validate()) return null;
      FocusScope.of(context).unfocus();
      setState(() => _busy = true);
    }
    final email = fromResend ? _email : _emailCtrl.text.trim().toLowerCase();
    try {
      final r = await OtpApi.forgotPassword(email);
      if (!mounted) return r;
      setState(() {
        _busy = false;
        _email = email;
        _masked = r.maskedEmail.isNotEmpty ? r.maskedEmail : maskEmail(email);
        _cooldown = r.cooldownSeconds;
        _expiry = r.expiresInSeconds;
        _error = '';
        _step = _Step.code;
      });
      if (fromResend) {
        _timerKey.currentState?.reset(cooldown: r.cooldownSeconds, expiry: r.expiresInSeconds);
        _otpKey.currentState?.clear();
        _snack('أرسلنا رمزاً جديداً', err: false);
      }
      return r;
    } on OtpException catch (e) {
      if (!mounted) return null;
      setState(() => _busy = false);
      if (e.isCooldown && !fromResend) {
        // رمز أُرسل قبل لحظات: ننتقل لإدخاله
        setState(() {
          _email = email;
          _masked = maskEmail(email);
          _cooldown = e.retryAfter ?? 60;
          _step = _Step.code;
        });
      } else {
        _snack(e.message);
        if (fromResend && e.retryAfter != null) {
          _timerKey.currentState?.reset(cooldown: e.retryAfter!, expiry: _expiry);
        }
      }
      return null;
    }
  }

  // ── 2) التحقق من الرمز ─────────────────────────────────────────────────
  Future<void> _verifyCode(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final token = await OtpApi.verifyReset(_email, code);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _resetToken = token;
        _step = _Step.password;
      });
    } on OtpException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
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

  // ── 3) كلمة المرور الجديدة ─────────────────────────────────────────────
  Future<void> _savePassword() async {
    if (!_passForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await OtpApi.resetPassword(
          email: _email, resetToken: _resetToken, newPassword: _passCtrl.text);
      if (!mounted) return;
      _newPassword = _passCtrl.text;
      setState(() {
        _busy = false;
        _step = _Step.done;
      });
    } on OtpException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
      if (e.code == 'invalid_token') {
        setState(() {
          _step = _Step.email;
          _resetToken = '';
        });
      }
    }
  }

  // ── 4) دخول مباشر بعد النجاح ───────────────────────────────────────────
  Future<void> _loginNow() async {
    final auth = context.read<AuthProvider>();
    setState(() => _busy = true);
    final ok = await auth.login(email: _email, password: _newPassword);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      _snack(auth.errorMessage.isEmpty ? 'تعذّر الدخول، جرّب من شاشة الدخول.' : auth.errorMessage);
      Navigator.of(context).pop();
    }
  }

  // ── قوة كلمة المرور (0..4) ─────────────────────────────────────────────
  int _strength(String p) {
    var s = 0;
    if (p.length >= 6) s++;
    if (p.length >= 9) s++;
    if (RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p) || (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p))) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AuthShell(
      compact: true,
      title: 'استعادة كلمة المرور',
      showBack: _step != _Step.done,
      onBack: () {
        if (_step == _Step.code) {
          setState(() {
            _step = _Step.email;
            _error = '';
          });
        } else {
          Navigator.pop(context);
        }
      },
      child: Column(
        children: [
          if (_step != _Step.done) _dots(c),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: switch (_step) {
              _Step.email => _emailStep(c),
              _Step.code => _codeStep(c),
              _Step.password => _passwordStep(c),
              _Step.done => _doneStep(c),
            },
          ),
        ],
      ),
    );
  }

  Widget _dots(SougaColors c) {
    final idx = _step.index;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == idx;
        final done = i < idx;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: (active || done) ? (done ? c.accent : c.primary) : c.border,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }

  Widget _title(SougaColors c, String t, String sub) => Column(children: [
        Text(t,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary)),
        const SizedBox(height: 8),
        Text(sub,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.6)),
      ]);

  Widget _bigButton(String label, VoidCallback? onTap) => AuthPrimaryButton(
        label: label,
        busy: _busy,
        icon: null,
        onPressed: _busy ? null : onTap,
      );

  // ── الخطوة 1 ───────────────────────────────────────────────────────────
  Widget _emailStep(SougaColors c) => Form(
        key: _emailForm,
        child: Column(
          key: const ValueKey('email'),
          children: [
            const OtpHero(icon: Icons.lock_reset_rounded, size: 92),
            _title(c, 'نسيت كلمة المرور؟',
                'أدخل بريدك الإلكتروني وسنرسل لك رمزاً من 6 خانات لإعادة تعيين كلمة المرور.'),
            const SizedBox(height: 26),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendCode(),
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'أدخل البريد الإلكتروني';
                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s)) return 'بريد إلكتروني غير صحيح';
                return null;
              },
            ),
            const SizedBox(height: 22),
            _bigButton('إرسال الرمز', _sendCode),
          ],
        ),
      );

  // ── الخطوة 2 ───────────────────────────────────────────────────────────
  Widget _codeStep(SougaColors c) => Column(
        key: const ValueKey('code'),
        children: [
          const OtpHero(icon: Icons.mark_email_unread_outlined, size: 92),
          _title(c, 'أدخل رمز التحقق', 'إن كان هذا البريد مسجَّلاً لدينا فقد أرسلنا إليه رمزاً مكوّناً من 6 خانات:'),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(_masked,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: c.textPrimary)),
          ),
          const SizedBox(height: 24),
          OtpInput(
            key: _otpKey,
            enabled: !_busy,
            onChanged: (v) => setState(() => _codeReady = v.length == 6),
            onCompleted: _verifyCode,
          ),
          OtpPasteButton(otpKey: _otpKey),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _error.isEmpty
                  ? const SizedBox(height: 18)
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.error_outline, size: 18, color: c.error),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(_error,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.error, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ]),
            ),
          ),
          const SizedBox(height: 20),
          _bigButton('تأكيد الرمز', _codeReady ? () => _verifyCode(_otpKey.currentState?.value ?? '') : null),
          const SizedBox(height: 12),
          OtpTimerRow(
            key: _timerKey,
            initialCooldown: _cooldown,
            initialExpiry: _expiry,
            onResend: () => _sendCode(fromResend: true),
          ),
          TextButton(
            onPressed: () => setState(() {
              _step = _Step.email;
              _error = '';
            }),
            child: const Text('تغيير البريد الإلكتروني'),
          ),
        ],
      );

  // ── الخطوة 3 ───────────────────────────────────────────────────────────
  Widget _passwordStep(SougaColors c) {
    final s = _strength(_passCtrl.text);
    final labels = ['ضعيفة جداً', 'ضعيفة', 'متوسطة', 'جيدة', 'قوية'];
    final colors = [c.error, c.error, c.warning, c.info, c.success];
    return Form(
      key: _passForm,
      child: Column(
        key: const ValueKey('password'),
        children: [
          const OtpHero(icon: Icons.password_rounded, size: 92),
          _title(c, 'كلمة مرور جديدة', 'تم التحقق من الرمز. اختر كلمة مرور قوية لحسابك.'),
          const SizedBox(height: 24),
          TextFormField(
            controller: _passCtrl,
            obscureText: !_showPass,
            textDirection: TextDirection.ltr,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'أدخل كلمة المرور';
              if (v.length < 6) return 'يجب ألا تقل عن 6 أحرف';
              return null;
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(4, (i) {
              final on = _passCtrl.text.isNotEmpty && i < s;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: on ? colors[s] : c.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _passCtrl.text.isEmpty ? 'استخدم 9 أحرف أو أكثر مع أرقام وحروف' : 'القوة: ${labels[s]}',
                style: TextStyle(fontSize: 12, color: _passCtrl.text.isEmpty ? c.textHint : colors[s]),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _pass2Ctrl,
            obscureText: !_showPass,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'تأكيد كلمة المرور',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
            validator: (v) => v != _passCtrl.text ? 'كلمتا المرور غير متطابقتين' : null,
          ),
          const SizedBox(height: 22),
          _bigButton('حفظ كلمة المرور', _savePassword),
        ],
      ),
    );
  }

  // ── الخطوة 4 ───────────────────────────────────────────────────────────
  Widget _doneStep(SougaColors c) => Column(
        key: const ValueKey('done'),
        children: [
          const SizedBox(height: 30),
          const OtpSuccessBurst(size: 130),
          _title(c, 'تم تغيير كلمة المرور', 'يمكنك الآن الدخول إلى حسابك بكلمة المرور الجديدة.\nتم إنهاء الجلسات القديمة على الأجهزة الأخرى حفاظاً على أمانك.'),
          const SizedBox(height: 32),
          _bigButton('الدخول إلى حسابي', _loginNow),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('العودة لشاشة الدخول'),
          ),
        ],
      );
}
