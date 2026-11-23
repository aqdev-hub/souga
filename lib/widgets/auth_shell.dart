// lib/widgets/auth_shell.dart
//
// الهيكل المشترك لشاشات الدخول / إنشاء الحساب / نسيت كلمة المرور / تأكيد البريد.
// الهوية (مرسومة برمجياً بالكامل في auth_art.dart، بلا صور):
//   هيدر حرير + شريط ذهبي معدني + حقيبة وعربة + شعار → بطاقة داكنة بحدّ ذهبي/قرمزي تتداخل مع الهيدر
//   → (اختياري) زخرفة سفلية خلف الفوتر تمتد خلف شريط التنقل (edge-to-edge).
//   الوضع الداكن: قرمزي + أسود   الوضع الفاتح: سماوي + أبيض   (عبر context.colors)
//
// الاستخدام:
//   AuthShell(title: 'مرحباً', child: ...)                       // يمرَّر في ScrollView
//   AuthShell(compact: true, scrollable: false, child: ...)      // المحتوى يملأ الباقي (مثل التبويبات)

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_colors.dart';
import 'auth_art.dart';

bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

const _goldStops = <Color>[
  Color(0xFF6E4413), Color(0xFFE9B964), Color(0xFFFFF1BE), Color(0xFFE3AE58), Color(0xFF9A6420),
];

// ════════════════════════════════════════════════════════════════════════════
class AuthShell extends StatefulWidget {
  final Widget child;
  final bool compact;          // هيدر أصغر للشاشات الداخلية
  final bool scrollable;       // false = المحتوى يملأ المساحة (للتبويبات ذات التمرير الداخلي)
  final String? title;         // عنوان الهيدر (الافتراضي: سوجا)
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? headerAction;  // زر في زاوية الهيدر (مثل "خروج")
  final Widget? footer;        // سطر الفوتر (أمام الزخرفة السفلية)
  final bool bottomWave;       // الزخرفة السفلية

  const AuthShell({
    super.key,
    required this.child,
    this.compact = false,
    this.scrollable = true,
    this.title,
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.headerAction,
    this.footer,
    this.bottomWave = false,
  });

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> {
  @override
  void initState() {
    super.initState();
    // edge-to-edge: الزخرفة تمتد خلف شريطي الحالة والتنقل
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = _isDark(context);
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF080509) : c.background,
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarContrastEnforced: false,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: LayoutBuilder(builder: (context, cons) {
                final w = cons.maxWidth;
                final s = w / kArtW;                       // وحدة → dp
                final cardMargin = math.max(12.0, w * 0.0376);
                final top = mq.padding.top;

                // ── الهيدر ─────────────────────────────────────────────────
                final double headerH;
                final double logoTop, logoD;
                if (widget.compact) {
                  logoD = 104 * s;
                  logoTop = math.max(70 * s, top + 8);
                  final titleTop = logoTop + logoD + 6 * s;
                  headerH = titleTop + 82 * s + 10 * s;
                } else {
                  logoD = 225 * s;
                  logoTop = 118 * s;
                  headerH = 545 * s;                       // قمة البطاقة ≈ 29.1% من ارتفاع التصميم
                }
                final header = _AuthHeader(
                  width: w, height: headerH, s: s, compact: widget.compact, dark: dark,
                  logoTop: logoTop, logoD: logoD,
                  title: widget.title ?? 'سوجا',
                  subtitle: widget.subtitle ?? (widget.compact ? null : 'سوقك المحلي بين يديك'),
                  showBack: widget.showBack, onBack: widget.onBack, action: widget.headerAction,
                );

                final cardMarginInsets = EdgeInsets.symmetric(horizontal: cardMargin);

                // ── محتوى غير قابل للتمرير (تبويبات) ──────────────────────
                if (!widget.scrollable) {
                  return SizedBox(
                    height: cons.maxHeight,
                    child: Column(children: [
                      header,
                      Expanded(
                        child: _Enter(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: mq.padding.bottom + 10),
                            child: AuthCard(
                              expand: true, margin: cardMarginInsets,
                              child: AuthTheme(child: widget.child),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  );
                }

                // ── قابل للتمرير ───────────────────────────────────────────
                final footerArtH = kFooterArtH * s;
                final linkH = widget.footer != null ? 54.0 : 0.0;
                return SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: cons.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(children: [
                        header,
                        _Enter(child: AuthCard(margin: cardMarginInsets, child: AuthTheme(child: widget.child))),
                        const Spacer(),
                        if (widget.bottomWave)
                          SizedBox(
                            width: w,
                            height: footerArtH + mq.padding.bottom + linkH,
                            child: Stack(children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(painter: AuthFooterPainter(dark: dark)),
                                ),
                              ),
                              if (widget.footer != null)
                                Positioned(left: 0, right: 0, top: 0, child: widget.footer!),
                            ]),
                          )
                        else ...[
                          if (widget.footer != null) widget.footer!,
                          SizedBox(height: mq.padding.bottom + 16),
                        ],
                      ]),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _Enter extends StatelessWidget {
  final Widget child;
  const _Enter({required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (_, t, ch) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 22 * (1 - t)), child: ch),
        ),
        child: child,
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  البطاقة: تعبئة فحمية متدرّجة + حدّ ذهبي/قرمزي رفيع + توهّج
// ════════════════════════════════════════════════════════════════════════════
class AuthCard extends StatelessWidget {
  final Widget child;
  final bool expand;
  final EdgeInsetsGeometry margin;
  const AuthCard({
    super.key,
    required this.child,
    this.expand = false,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = _isDark(context);
    const r = 24.0;
    final inner = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r - 1.4),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF100E13), Color(0xFF1D1C20), Color(0xFF121014)]
              : const [Color(0xFFFFFFFF), Color(0xFFF6FAFF), Color(0xFFEEF6FE)],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: child,
    );
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF3CC83).withValues(alpha: 0.95),
            c.primary.withValues(alpha: 0.55),
            const Color(0xFFE3AE58).withValues(alpha: 0.75),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: (dark ? c.primary : Colors.black).withValues(alpha: dark ? 0.30 : 0.12),
            blurRadius: 26,
            offset: const Offset(0, 8),
          ),
          if (dark)
            BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.10), blurRadius: 14),
        ],
      ),
      child: expand ? SizedBox.expand(child: inner) : inner,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  الهيدر: رسم + شعار + عنوان + عبارة + خط ذهبي
// ════════════════════════════════════════════════════════════════════════════
class _AuthHeader extends StatelessWidget {
  final double width, height, s, logoTop, logoD;
  final bool compact, dark, showBack;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? action;

  const _AuthHeader({
    required this.width,
    required this.height,
    required this.s,
    required this.compact,
    required this.dark,
    required this.logoTop,
    required this.logoD,
    required this.title,
    required this.subtitle,
    required this.showBack,
    required this.onBack,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final top = MediaQuery.of(context).padding.top;
    final artH = compact ? height + 70 * s : kHeaderArtH * s;
    final titleTop = compact ? logoTop + logoD + 6 * s : 335 * s;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(clipBehavior: Clip.none, children: [
        // الرسم يمتد خلف البطاقة (تداخل) وخلف شريط الحالة
        Positioned(
          left: 0, right: 0, top: 0, height: artH,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: AuthHeaderPainter(dark: dark, compact: compact)),
            ),
          ),
        ),

        // الشعار (الموجود سابقاً) داخل حلقة ذهبية
        Positioned(
          top: logoTop, left: 0, right: 0,
          child: Center(
            child: Container(
              width: logoD, height: logoD,
              padding: EdgeInsets.all(math.max(2.0, logoD * 0.014)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(colors: [
                  Color(0xFF6E4413), Color(0xFFE9B964), Color(0xFFFFF1BE), Color(0xFFE3AE58), Color(0xFF9A6420), Color(0xFF6E4413),
                ]),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFE9B964).withValues(alpha: 0.40), blurRadius: 22 * s * 2),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 8)),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.white,
                    child: Icon(Icons.storefront_rounded, size: logoD * .5, color: c.primary),
                  ),
                ),
              ),
            ),
          ),
        ),

        // العنوان
        Positioned(
          top: titleTop, left: 0, right: 0,
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: (compact ? 52 : 78) * s,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.15,
                shadows: const [Shadow(color: Color(0x73000000), blurRadius: 10, offset: Offset(0, 3))],
              ),
            ),
          ),
        ),

        if (subtitle != null) ...[
          Positioned(
            top: 440 * s, left: 0, right: 0,
            child: Center(
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 33 * s,
                  color: Colors.white.withValues(alpha: 0.95),
                  height: 1.3,
                  shadows: const [Shadow(color: Color(0x59000000), blurRadius: 6, offset: Offset(0, 2))],
                ),
              ),
            ),
          ),
          // الخط الذهبي المنحني (إلزامي تحت العبارة)
          Positioned(
            top: 490 * s, left: 0, right: 0,
            child: Center(
              child: SizedBox(
                width: 182 * s, height: 18 * s,
                child: const CustomPaint(painter: GoldUnderlinePainter()),
              ),
            ),
          ),
        ],

        if (showBack)
          PositionedDirectional(
            start: 6, top: top + 4,
            child: IconButton(
              tooltip: 'رجوع',
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: onBack ?? () => Navigator.maybePop(context),
            ),
          ),
        if (action != null) PositionedDirectional(end: 6, top: top + 4, child: action!),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ثيم الحقول داخل البطاقة: حقول مستديرة بخلفية داكنة/فاتحة وحدود ناعمة
// ════════════════════════════════════════════════════════════════════════════
class AuthTheme extends StatelessWidget {
  final Widget child;
  const AuthTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context);
    final dark = t.brightness == Brightness.dark;
    final fill = dark ? const Color(0xFF201E21) : const Color(0xFFF1F7FD);
    final edge = dark ? const Color(0xFF55505A) : const Color(0xFFB5C6D8);   // حدّ رمادي فضّي
    OutlineInputBorder b(Color col, [double w = 1.1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: col, width: w),
        );
    return Theme(
      data: t.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: fill,
          isDense: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          labelStyle: TextStyle(color: c.textSecondary, fontSize: 15),
          floatingLabelStyle: TextStyle(color: c.primary, fontWeight: FontWeight.w700),
          hintStyle: TextStyle(color: c.textHint),
          prefixIconColor: WidgetStateColor.resolveWith(
              (s) => s.contains(WidgetState.focused) ? c.primary : c.textSecondary),
          suffixIconColor: c.textSecondary,
          border: b(edge),
          enabledBorder: b(edge),
          focusedBorder: b(c.primary, 1.7),
          errorBorder: b(c.error),
          focusedErrorBorder: b(c.error, 1.7),
          disabledBorder: b(c.border.withValues(alpha: 0.5)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: c.primary,
            overlayColor: c.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: Colors.white,
            overlayColor: Colors.white,
            minimumSize: const Size(64, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: c.accent.withValues(alpha: 0.55)),
            ),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      child: child,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  أزرار
// ════════════════════════════════════════════════════════════════════════════
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final IconData? icon;
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon = Icons.arrow_forward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;
    const r = 18.0;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.5,
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          // حدّ ذهبي-وردي
          gradient: const LinearGradient(colors: [Color(0xFFF3CC83), Color(0xFFFF7A9C), Color(0xFFE3AE58)]),
          boxShadow: [BoxShadow(color: c.primary.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r - 1.2),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color.lerp(c.primary, Colors.white, 0.10)!, c.primary, c.primaryDark],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: InkWell(
                onTap: onPressed,
                child: Stack(children: [
                  // حافة علوية لامعة (glossy)
                  Positioned(
                    left: 0, right: 0, top: 0, height: 24,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0.0)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: busy
                          ? const SizedBox(
                              key: ValueKey('b'), width: 24, height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6))
                          // RTL ثابت: الأيقونة على يمين النص وتشير لليمين (غير معكوسة)
                          : Directionality(
                              key: const ValueKey('t'),
                              textDirection: TextDirection.rtl,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (icon != null) ...[
                                    Container(
                                      width: 28, height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.6),
                                      ),
                                      child: Icon(icon, color: Colors.white, size: 16, textDirection: TextDirection.ltr),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Text(label,
                                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthOutlineButton extends StatelessWidget {
  final Widget leading;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  const AuthOutlineButton({
    super.key,
    required this.leading,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = _isDark(context);
    final enabled = onPressed != null;
    const r = 18.0;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(1.3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          // حدّ ذهبي معدني
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFE9B964), Color(0xFFFFF1BE), Color(0xFFB9792F), Color(0xFFE3AE58)],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r - 1.3),
          child: Material(
            color: dark ? const Color(0xFF141115) : Colors.white,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                height: 52,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  busy
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.primary))
                      : leading,
                  const SizedBox(width: 12),
                  Text(label,
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: c.textPrimary)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// فاصل "أو" بخطّين
class AuthOrDivider extends StatelessWidget {
  final String text;
  const AuthOrDivider({super.key, this.text = 'أو'});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Expanded(child: Divider(color: c.border, thickness: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text, style: TextStyle(color: c.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      Expanded(child: Divider(color: c.border)),
    ]);
  }
}

/// سطر أسفل البطاقة: "ليس لديك حساب؟ إنشاء حساب" بخطوط ذهبية على الجانبين
class AuthFooterLink extends StatelessWidget {
  final String question;
  final String action;
  final VoidCallback? onTap;
  const AuthFooterLink({super.key, required this.question, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget line() => Expanded(
          child: Container(
            height: 1.2,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.accent.withValues(alpha: 0.0), c.accent, c.accent.withValues(alpha: 0.0)]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Row(children: [
        line(),
        Text(question, style: TextStyle(color: c.textPrimary, fontSize: 14.5)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Text(action,
                style: TextStyle(color: _isDark(context) ? c.primaryLight : c.primary, fontSize: 15, fontWeight: FontWeight.w900)),
          ),
        ),
        line(),
      ]),
    );
  }
}
