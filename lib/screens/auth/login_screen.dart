// lib/screens/auth/login_screen.dart
//
// شاشة الدخول — الهوية الجديدة (AuthShell: حرير متموّج + بطاقة بحدّ ذهبي) مع:
//  • دخول جوجل سريع: المؤشر على الزر فقط، والشاشة تبقى معروضة (لا شاشة تحميل كاملة)
//  • بقاء نتيجة العملية (نافذة اختيار الدور / رسالة الخطأ) لأن الـState لا يُهدم
//  • تعبئة تلقائية، زر Enter يرسل، إخفاء لوحة المفاتيح بالسحب، وضع داكن عبر context.colors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:souga/screens/auth/register_screen.dart';

import '../../providers/auth_provider.dart';
import '../../services/startup_tasks.dart';
import '../../utils/app_colors.dart';
import '../../widgets/auth_shell.dart';
import '../../screens/auth/forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? prefillEmail;
  final String? prefillPassword;

  const LoginScreen({super.key, this.prefillEmail, this.prefillPassword});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  final _passFocus = FocusNode();
  bool _obscure = true;
  bool _emailBusy = false;
  bool _googleBusy = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.prefillEmail   ?? '');
    _passCtrl  = TextEditingController(text: widget.prefillPassword ?? '');
    // تسخين خادم Render (ينام): يكون جاهزاً حين يطلب المستخدم رمز التحقق
    StartupTasks.warmUpServer();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: context.colors.error,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _login() async {
    if (_emailBusy || _googleBusy) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    setState(() => _emailBusy = true);
    final success = await auth.login(
      email:    _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _emailBusy = false);
    if (!success) _toast(auth.errorMessage);
  }

  // ── تسجيل الدخول بجوجل ────────────────────────────────────────────────────
  Future<void> _loginWithGoogle() async {
    if (_emailBusy || _googleBusy) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    final auth = context.read<AuthProvider>();
    setState(() => _googleBusy = true);
    final result = await auth.loginWithGoogle();
    if (!mounted) return;
    setState(() => _googleBusy = false);

    switch (result) {
      case GoogleSignInResult.success:
      case GoogleSignInResult.cancelled:
        break; // Wrapper يعيد التوجيه / المستخدم ألغى
      case GoogleSignInResult.newUserNeedsRole:
        await _showRolePickerDialog();
        break;
      case GoogleSignInResult.error:
        _toast(auth.errorMessage);
        break;
    }
  }

  // ── نافذة اختيار الدور لمستخدم جوجل الجديد ──────────────────────────────
  Future<void> _showRolePickerDialog() async {
    String selectedRole        = 'customer';
    final  storeNameCtrl       = TextEditingController();
    final  storeDescCtrl       = TextEditingController();
    bool   isSubmitting        = false;
    final  colors              = context.colors;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_outline, color: colors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('اختر نوع حسابك',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'مرحباً! كيف تريد استخدام سوجا؟',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // ── خيار مشتري ──────────────────────────────────────────────
                _RoleOption(
                  selected:    selectedRole == 'customer',
                  icon:        Icons.shopping_bag_outlined,
                  title:       'مشتري',
                  subtitle:    'تصفح وشراء المنتجات',
                  onTap:       () => setDialogState(() => selectedRole = 'customer'),
                ),
                const SizedBox(height: 8),

                // ── خيار بائع ───────────────────────────────────────────────
                _RoleOption(
                  selected:    selectedRole == 'seller',
                  icon:        Icons.storefront_outlined,
                  title:       'بائع',
                  subtitle:    'أنشئ متجرك وبع منتجاتك',
                  onTap:       () => setDialogState(() => selectedRole = 'seller'),
                ),

                // ── حقول المتجر (تظهر فقط عند اختيار بائع) ─────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: selectedRole == 'seller'
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(children: [
                          TextField(
                            controller: storeNameCtrl,
                            decoration: const InputDecoration(
                              labelText:  'اسم المتجر',
                              prefixIcon: Icon(Icons.store_outlined),
                              isDense:    true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: storeDescCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText:  'وصف المتجر (اختياري)',
                              prefixIcon: Icon(Icons.description_outlined),
                              isDense:    true,
                              alignLabelWithHint: true,
                            ),
                          ),
                        ]),
                      )
                    : const SizedBox.shrink(),
                ),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () async {
                  Navigator.pop(ctx);
                  await context.read<AuthProvider>().cancelGoogleSignIn();
                },
                child: Text('إلغاء', style: TextStyle(color: colors.textSecondary)),
              ),
              Consumer<AuthProvider>(
                builder: (_, auth, __) => ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    if (selectedRole == 'seller' && storeNameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: const Text('يرجى إدخال اسم المتجر'),
                          backgroundColor: colors.error,
                        ),
                      );
                      return;
                    }
                    setDialogState(() => isSubmitting = true);
                    final ok = await auth.completeGoogleSignIn(
                      role:             selectedRole,
                      storeName:        storeNameCtrl.text.trim(),
                      storeDescription: storeDescCtrl.text.trim(),
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!ok && context.mounted) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:         Text(auth.errorMessage),
                          backgroundColor: colors.error,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size(100, 40)),
                  child: isSubmitting
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('ابدأ'),
                ),
              ),
            ],
          );
        },
      ),
    );

    storeNameCtrl.dispose();
    storeDescCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final anyBusy = _emailBusy || _googleBusy;

    return AuthShell(
      bottomWave: true,
      footer: AuthFooterLink(
        question: 'ليس لديك حساب؟',
        action: 'إنشاء حساب',
        onTap: anyBusy ? null : () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('مرحباً بعودتك 👋',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: colors.textPrimary)),
            const SizedBox(height: 4),
            Text('سجّل دخولك لمتابعة طلباتك والتسوق',
                style: TextStyle(fontSize: 14, color: colors.textSecondary)),
            const SizedBox(height: 22),

            TextFormField(
              controller: _emailCtrl,
              enabled: !anyBusy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              textDirection: TextDirection.ltr,
              onFieldSubmitted: (_) => _passFocus.requestFocus(),
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isEmpty) return 'أدخل البريد الإلكتروني';
                if (!val.contains('@') || !val.contains('.')) return 'بريد إلكتروني غير صحيح';
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _passCtrl,
              focusNode: _passFocus,
              enabled: !anyBusy,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              textDirection: TextDirection.ltr,
              onFieldSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'أدخل كلمة المرور';
                if (v.length < 6) return 'كلمة المرور قصيرة جداً';
                return null;
              },
            ),

            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: anyBusy ? null : () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                child: const Text('نسيت كلمة المرور؟'),
              ),
            ),
            const SizedBox(height: 2),

            AuthPrimaryButton(
              label: 'تسجيل الدخول',
              busy: _emailBusy,
              onPressed: anyBusy ? null : _login,
            ),
            const SizedBox(height: 18),
            const AuthOrDivider(),
            const SizedBox(height: 18),

            AuthOutlineButton(
              busy: _googleBusy,
              onPressed: anyBusy ? null : _loginWithGoogle,
              leading: const SizedBox(width: 24, height: 24, child: CustomPaint(painter: _GoogleLogoPainter())),
              label: _googleBusy ? 'جاري الاتصال بجوجل…' : 'المتابعة بحساب جوجل',
            ),
            const SizedBox(height: 6),

            TextButton.icon(
              onPressed: anyBusy ? null : () => context.read<AuthProvider>().loginAsGuest(),
              icon: Icon(Icons.person_rounded, size: 22, color: colors.primaryLight),
              label: const Text('تصفّح بدون تسجيل', style: TextStyle(fontSize: 15)),
              style: TextButton.styleFrom(foregroundColor: colors.textPrimary, overlayColor: colors.primary, side: BorderSide.none),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── خيار الدور ────────────────────────────────────────────────────────────────
class _RoleOption extends StatelessWidget {
  final bool     selected;
  final IconData icon;
  final String   title;
  final String   subtitle;
  final VoidCallback onTap;

  const _RoleOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.07)
              : Colors.transparent,
          border: Border.all(
            color: selected ? colors.primary : colors.border,
            width: selected ? 1.8 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: selected
                  ? colors.primary.withValues(alpha: 0.12)
                  : colors.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: selected ? colors.primary : colors.textSecondary,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? colors.primary : colors.textPrimary,
                  fontSize: 14,
                )),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11, color: colors.textSecondary)),
          ])),
          if (selected)
            Icon(Icons.check_circle_rounded,
                color: colors.primary, size: 20),
        ]),
      ),
    );
  }
}

// ── شعار جوجل (حرف G بألوانه الرسمية، بلا صورة خارجية) ───────────────────────
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 * 0.72;
    final sw = size.width * 0.2;
    final rect = Rect.fromCircle(center: c, radius: r);
    double rad(double d) => d * 3.1415926535 / 180;
    Paint p(Color col) => Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, rad(137), rad(90), false, p(const Color(0xFFFBBC05))); // أصفر (يسار)
    canvas.drawArc(rect, rad(227), rad(95), false, p(const Color(0xFFEA4335))); // أحمر (أعلى)
    canvas.drawArc(rect, rad(47),  rad(90), false, p(const Color(0xFF34A853))); // أخضر (أسفل)
    canvas.drawArc(rect, rad(0),   rad(47), false, p(const Color(0xFF4285F4))); // أزرق (يمين)
    // الشريط الأفقي الأزرق
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - sw / 2, r + sw / 2, sw),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
