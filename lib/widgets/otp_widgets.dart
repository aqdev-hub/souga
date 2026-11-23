// lib/widgets/otp_widgets.dart
//
// مكوّنات مشتركة لشاشات التحقق (تأكيد البريد + نسيت كلمة المرور):
//   OtpInput        — 6 خانات (أرقام وحروف) مع لصق وهزّة خطأ ومؤشر وامض
//   OtpHero         — أيقونة متحركة بحلقات نابضة
//   OtpSuccessBurst — علامة نجاح تُرسم بحركة مع جسيمات
//   OtpTimerRow     — عدّاد صلاحية الرمز + إعادة الإرسال بعدّاد تنازلي

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/otp_api.dart';
import '../utils/app_colors.dart';

String maskEmail(String e) {
  final i = e.indexOf('@');
  if (i <= 0) return e;
  final u = e.substring(0, i);
  final keep = u.length <= 2 ? u.length : 2;
  return '${u.substring(0, keep)}${'*' * math.max(1, u.length - keep)}${e.substring(i)}';
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) =>
      n.copyWith(text: n.text.toUpperCase());
}

// ════════════════════════════════════════════════════════════════════════════
//  OtpInput
// ════════════════════════════════════════════════════════════════════════════
class OtpInput extends StatefulWidget {
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  const OtpInput({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<OtpInput> createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> with TickerProviderStateMixin {
  static const int length = 6;
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 480));
  late final AnimationController _blink = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  bool _error = false;
  bool _completedSent = false;

  String get value => _ctrl.text;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _shake.dispose();
    _blink.dispose();
    super.dispose();
  }

  /// هزّة + اهتزاز + تلوين أحمر (عند رمز خاطئ)
  void shake() {
    HapticFeedback.heavyImpact();
    setState(() => _error = true);
    _shake.forward(from: 0);
  }

  /// مسح الخانات وإعادة التركيز
  void clear() {
    _ctrl.clear();
    _completedSent = false;
    setState(() => _error = false);
    if (widget.enabled) _focus.requestFocus();
  }

  /// يلصق رمزاً من الحافظة (6 خانات من الأحرف/الأرقام) ويُكمله تلقائياً. يُرجع نجاح العملية.
  Future<bool> pasteFromClipboard() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t =
        (d?.text ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (t.length < length) return false;
    final code = t.substring(0, length);
    _ctrl.value = TextEditingValue(
        text: code, selection: const TextSelection.collapsed(offset: length));
    _onChanged(code);
    return true;
  }

  void _onChanged(String v) {
    if (_error) setState(() => _error = false);
    widget.onChanged?.call(v);
    if (v.length == length) {
      if (!_completedSent) {
        _completedSent = true;
        HapticFeedback.selectionClick();
        widget.onCompleted(v);
      }
    } else {
      _completedSent = false;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = _ctrl.text;
    final focused = _focus.hasFocus;

    return LayoutBuilder(builder: (context, cons) {
      const gap = 8.0;
      final boxW =
          math.min(50.0, (cons.maxWidth - gap * (length - 1)) / length);
      return AnimatedBuilder(
        animation: _shake,
        builder: (_, child) {
          final t = _shake.value;
          final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(length, (i) {
                  final filled = i < text.length;
                  final active = focused &&
                      widget.enabled &&
                      i == math.min(text.length, length - 1) &&
                      text.length < length;
                  final borderColor = _error
                      ? c.error
                      : active
                          ? c.primary
                          : filled
                              ? c.accent
                              : c.border;
                  return Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: boxW,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _error
                            ? c.error.withValues(alpha: 0.06)
                            : filled
                                ? c.accent.withValues(alpha: 0.10)
                                : c.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: borderColor,
                            width: active || _error ? 2 : 1.5),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                    color: c.primary.withValues(alpha: 0.18),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3))
                              ]
                            : const [],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedScale(
                            scale: filled ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutBack,
                            child: Text(
                              filled ? text[i] : '',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: _error
                                    ? c.error
                                    : (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : c.primaryDark),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          if (active)
                            FadeTransition(
                              opacity: _blink,
                              child: Container(
                                  width: 2, height: 26, color: c.primary),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              // حقل نصي حقيقي شفاف فوق الخانات: يستقبل النقر واللصق والكتابة
              Positioned.fill(
                child: Opacity(
                  opacity: 0.0,
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    autofocus: false,
                    keyboardType: TextInputType.visiblePassword,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    showCursor: false,
                    maxLength: length,
                    style: const TextStyle(color: Colors.transparent),
                    cursorColor: Colors.transparent,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                      _UpperCaseFormatter(),
                      LengthLimitingTextInputFormatter(length),
                    ],
                    onChanged: _onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  OtpHero — أيقونة بحلقات نابضة وطفو خفيف
// ════════════════════════════════════════════════════════════════════════════
class OtpHero extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color? onColor; // لون الأيقونة/الحلقات (أبيض فوق الهيدر الأحمر)
  const OtpHero({super.key, required this.icon, this.size = 104, this.onColor});

  @override
  State<OtpHero> createState() => _OtpHeroState();
}

class _OtpHeroState extends State<OtpHero> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = widget.onColor ?? c.primary;
    final s = widget.size;
    return SizedBox(
      width: s * 1.6,
      height: s * 1.6,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final float = math.sin(_c.value * math.pi * 2) * 4;
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final shift in const [0.0, 0.5])
                Builder(builder: (_) {
                  final t = (_c.value + shift) % 1.0;
                  return Opacity(
                    opacity: (1 - t) * 0.35,
                    child: Container(
                      width: s * (1 + t * 0.6),
                      height: s * (1 + t * 0.6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: fg, width: 2),
                      ),
                    ),
                  );
                }),
              Transform.translate(
                offset: Offset(0, float),
                child: Container(
                  width: s * 0.82,
                  height: s * 0.82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.onColor != null ? Colors.white : c.surface,
                    border: Border.all(color: c.accent, width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Icon(widget.icon, size: s * 0.42, color: c.primary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  OtpSuccessBurst — دائرة تنمو ← علامة صح تُرسم ← جسيمات ذهبية/حمراء
// ════════════════════════════════════════════════════════════════════════════
class OtpSuccessBurst extends StatefulWidget {
  final double size;
  const OtpSuccessBurst({super.key, this.size = 150});

  @override
  State<OtpSuccessBurst> createState() => _OtpSuccessBurstState();
}

class _OtpSuccessBurstState extends State<OtpSuccessBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void initState() {
    super.initState();
    _c.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: widget.size * 1.7,
      height: widget.size * 1.7,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _BurstPainter(
            progress: _c.value,
            main: c.success,
            gold: c.accent,
            red: c.primary,
            circleSize: widget.size,
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final Color main, gold, red;
  final double circleSize;
  _BurstPainter({
    required this.progress,
    required this.main,
    required this.gold,
    required this.red,
    required this.circleSize,
  });

  double _seg(double a, double b) => ((progress - a) / (b - a)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = circleSize / 2;

    // 1) الدائرة (0 → 0.4)
    final grow = Curves.easeOutBack.transform(_seg(0.0, 0.4));
    canvas.drawCircle(center, r * grow, Paint()..color = main);
    canvas.drawCircle(
      center,
      r * grow + 6,
      Paint()
        ..color = gold.withValues(alpha: 0.9 * grow.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // 2) علامة الصح (0.35 → 0.7)
    final p = Curves.easeInOut.transform(_seg(0.35, 0.7));
    if (p > 0) {
      final path = Path()
        ..moveTo(center.dx - r * 0.38, center.dy + r * 0.02)
        ..lineTo(center.dx - r * 0.10, center.dy + r * 0.30)
        ..lineTo(center.dx + r * 0.42, center.dy - r * 0.26);
      final paint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.17
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final m in path.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * p), paint);
      }
    }

    // 3) جسيمات (0.3 → 1.0)
    final t = _seg(0.3, 1.0);
    if (t > 0 && t < 1) {
      final rnd = math.Random(7);
      for (var i = 0; i < 18; i++) {
        final ang = (i / 18) * math.pi * 2 + rnd.nextDouble() * 0.3;
        final dist = r *
            (1.15 +
                Curves.easeOut.transform(t) * (0.55 + rnd.nextDouble() * 0.25));
        final pos = center + Offset(math.cos(ang), math.sin(ang)) * dist;
        final col = (i.isEven ? gold : red).withValues(alpha: (1 - t));
        final rad = (i % 3 == 0 ? 5.0 : 3.2) * (1 - t * 0.4);
        canvas.drawCircle(pos, rad, Paint()..color = col);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.progress != progress;
}

// ════════════════════════════════════════════════════════════════════════════
//  OtpTimerRow — صلاحية الرمز + إعادة الإرسال
// ════════════════════════════════════════════════════════════════════════════
class OtpTimerRow extends StatefulWidget {
  final int initialCooldown;
  final int initialExpiry;

  /// يطلب رمزاً جديداً. يُرجع النتيجة، أو null عند الفشل (الأب يعرض الخطأ).
  final Future<OtpSendResult?> Function() onResend;
  const OtpTimerRow({
    super.key,
    required this.initialCooldown,
    required this.initialExpiry,
    required this.onResend,
  });

  @override
  State<OtpTimerRow> createState() => OtpTimerRowState();
}

class OtpTimerRowState extends State<OtpTimerRow> {
  late int _cooldown = widget.initialCooldown;
  late int _expiry = widget.initialExpiry;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_cooldown > 0 || _expiry > 0) {
        setState(() {
          if (_cooldown > 0) _cooldown--;
          if (_expiry > 0) _expiry--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// يُستدعى من الأب بعد إرسال ناجح/أو عند معرفة فاصل متبقٍّ
  void reset({required int cooldown, required int expiry}) {
    if (!mounted) return;
    setState(() {
      _cooldown = cooldown;
      _expiry = expiry;
    });
  }

  String _mmss(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Future<void> _resend() async {
    if (_busy || _cooldown > 0) return;
    setState(() => _busy = true);
    final r = await widget.onResend();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r != null) {
        _cooldown = r.cooldownSeconds;
        _expiry = r.expiresInSeconds;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final expired = _expiry <= 0;
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Row(
            key: ValueKey(expired),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(expired ? Icons.timer_off_outlined : Icons.timer_outlined,
                  size: 18, color: expired ? c.error : c.textSecondary),
              const SizedBox(width: 6),
              Text(
                expired
                    ? 'انتهت صلاحية الرمز — اطلب رمزاً جديداً'
                    : 'ينتهي الرمز خلال ${_mmss(_expiry)}',
                style: TextStyle(
                  fontSize: 13,
                  color: expired ? c.error : c.textSecondary,
                  fontWeight: expired ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: (_cooldown > 0 || _busy) ? null : _resend,
          child: _busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: c.primary))
              : Text(
                  _cooldown > 0
                      ? 'إعادة الإرسال بعد $_cooldown ث'
                      : 'لم يصلك الرمز؟ أعد الإرسال',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _cooldown > 0 ? c.textHint : c.primary,
                  ),
                ),
        ),
        if (_cooldown == 0)
          Text(
            'تحقق أيضاً من مجلد الرسائل غير المرغوبة (Spam)',
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
      ],
    );
  }
}

/// زر "لصق الرمز" — ينسخ الرمز من الحافظة (انسخه من الرسالة ثم اضغط هنا).
class OtpPasteButton extends StatelessWidget {
  final GlobalKey<OtpInputState> otpKey;
  const OtpPasteButton({super.key, required this.otpKey});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextButton.icon(
      onPressed: () async {
        final ok = await otpKey.currentState?.pasteFromClipboard() ?? false;
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
                content: Text(
                    'لم نجد رمزاً من 6 خانات في الحافظة. انسخه من الرسالة أولاً.')));
        }
      },
      icon: Icon(Icons.content_paste_rounded, size: 18, color: c.primary),
      label: const Text('لصق الرمز من الحافظة'),
    );
  }
}
