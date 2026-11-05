// lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:souga/screens/auth/register_screen.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
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
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.prefillEmail   ?? '');
    _passCtrl  = TextEditingController(text: widget.prefillPassword ?? '');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final auth    = context.read<AuthProvider>();
    final colors  = context.colors;
    final success = await auth.login(
      email:    _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text(auth.errorMessage),
          backgroundColor: colors.error,
        ),
      );
    }
  }

  // ── تسجيل الدخول بجوجل ────────────────────────────────────────────────────
  Future<void> _loginWithGoogle() async {
    final auth   = context.read<AuthProvider>();
    final colors = context.colors;
    final result = await auth.loginWithGoogle();

    if (!mounted) return;

    switch (result) {
      case GoogleSignInResult.success:
        // Wrapper سيُعيد التوجيه تلقائياً
        break;

      case GoogleSignInResult.newUserNeedsRole:
        // مستخدم جديد — نعرض نافذة اختيار الدور
        await _showRolePickerDialog();
        break;

      case GoogleSignInResult.cancelled:
        // لا شيء — المستخدم ألغى
        break;

      case GoogleSignInResult.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text(auth.errorMessage),
            backgroundColor: colors.error,
          ),
        );
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
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Container(
                width:   double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48),
                decoration: BoxDecoration(
                  gradient: colors.headerFadeGradient,
                ),
                child: Column(children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color:      Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset:     const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/app_icon1.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: colors.primaryDark,
                          child: const Icon(Icons.storefront_rounded,
                              size: 60, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Souga',
                    style: TextStyle(
                      fontSize: 36, fontWeight: FontWeight.bold,
                      color: Colors.white, letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your Local Marketplace',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ]),
              ),

              // ── Form ────────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      TextFormField(
                        controller:    _emailCtrl,
                        keyboardType:  TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText:  'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          final val = v?.trim() ?? '';
                          if (val.isEmpty)        return 'أدخل البريد الإلكتروني';
                          if (!val.contains('@')) return 'بريد إلكتروني غير صحيح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller:    _passCtrl,
                        obscureText:   _obscure,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText:  'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            {return 'أدخل كلمة المرور';}
                          if (v.length < 6) { return 'كلمة المرور قصيرة جداً'; }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen()),
                          ),
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Consumer<AuthProvider>(
                        builder: (_, auth, __) => ElevatedButton(
                          onPressed: auth.isLoading ? null : _login,
                          child: auth.isLoading
                              ? const SizedBox(
                                  height: 22, width: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('دخول'),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── فاصل ────────────────────────────────────────────────
                      Row(children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('أو',
                              style:
                                  TextStyle(color: colors.textSecondary)),
                        ),
                        const Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: 16),

                      // ── زر Google ────────────────────────────────────────────
                      Consumer<AuthProvider>(
                        builder: (_, auth, __) => OutlinedButton(
                          onPressed: auth.isLoading ? null : _loginWithGoogle,
                          style: OutlinedButton.styleFrom(
                            side:         const BorderSide(color: Color(0xFFDDDDDD)),
                            foregroundColor: colors.textPrimary,
                            backgroundColor: Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // شعار جوجل بالألوان الرسمية (SVG inline بدون package)
                              SizedBox(
                                width: 20, height: 20,
                                child: CustomPaint(painter: _GoogleLogoPainter()),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'الدخول بحساب جوجل',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        onPressed: () =>
                            context.read<AuthProvider>().loginAsGuest(),
                        icon:  const Icon(Icons.explore_outlined),
                        label: const Text('تجربة التطبيق بدون تسجيل'),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ليس لديك حساب؟',
                            style:
                                TextStyle(color: colors.textSecondary),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen()),
                            ),
                            child: const Text('إنشاء حساب'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

// ── شعار جوجل بدون صورة خارجية ───────────────────────────────────────────────
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // رسم دائري مبسط بألوان جوجل
    final colors = [
      const Color(0xFF4285F4), // أزرق
      const Color(0xFF34A853), // أخضر
      const Color(0xFFFBBC05), // أصفر
      const Color(0xFFEA4335), // أحمر
    ];

    for (int i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.35;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.65),
        (i * 3.14159 / 2) - 0.3,
        3.14159 / 2 - 0.15,
        false,
        paint,
      );
    }

    // "G" المقطوع — الخط الأفقي
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.35;
    canvas.drawLine(
      Offset(c.dx, c.dy),
      Offset(c.dx + r * 0.65, c.dy),
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
