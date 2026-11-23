// lib/widgets/auth_art.dart
//
// رسم برمجي كامل (بدون أي صور أو مكتبات) لخلفية شاشات الدخول:
//   • هيدر: حرير عنابي/قرمزي متعدد الطبقات + شريط ذهبي معدني متغيّر السماكة + حقيبة + عربة
//   • زخرفة سفلية بنفس الأسلوب
// الإحداثيات بوحدات مرجعية: العرض 841 وحدة (يُقاس بـ w/841).
// الوضع الداكن = عنابي/قرمزي، الوضع الفاتح = سماوي/أبيض (الذهب ثابت في الاثنين).
//
// ملاحظة: لا تعدّل الأرقام يدوياً؛ هي مولَّدة من نموذج معاينة متصفح قورن بالمرجع.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const double kArtW = 841.0;
const double kHeaderArtH = 700.0;   // ارتفاع رسم الهيدر (وحدات)
const double kFooterArtH = 200.0;   // ارتفاع رسم الفوتر (وحدات)

// ── ألوان الرموز لكل ثيم ─────────────────────────────────────────────────────
const _dark = <String, int>{
  'bg': 0xFF0B050A, 'w0': 0xFF32010C, 'w1': 0xFF460113, 'w2': 0xFF6D0120, 'w3': 0xFF780020,
  'c0': 0xFFA20032, 'c1': 0xFFA40134, 'c2': 0xFFDA0F47, 'hot': 0xFFFF4D73, 'pink': 0xFFFF7A9C, 'glow': 0xFFFFD9A0,
};
const _light = <String, int>{
  'bg': 0xFFF4F9FF, 'w0': 0xFF0B5FBF, 'w1': 0xFF0F6FD6, 'w2': 0xFF1E90FF, 'w3': 0xFF46A8FF,
  'c0': 0xFF1E90FF, 'c1': 0xFF3AA3FF, 'c2': 0xFF6CC0FF, 'hot': 0xFFA8DCFF, 'pink': 0xFFCFEBFF, 'glow': 0xFFFFFFFF,
};

class _Pal {
  final Map<String, int> m;
  const _Pal(this.m);
  Color col(String t, double a) {
    final v = t.startsWith('#') ? int.parse('FF${t.substring(1)}', radix: 16) : m[t]!;
    return Color(v).withValues(alpha: a);
  }
}

// ── مُحلّل مسارات مبسّط: M L C Z مطلقة فقط ──────────────────────────────────
Path _P(String d) {
  final t = RegExp(r'[MLCZ]|-?\d+(?:\.\d+)?').allMatches(d).map((m) => m.group(0)!).toList();
  final p = Path();
  var i = 0;
  double n() => double.parse(t[i++]);
  while (i < t.length) {
    final c = t[i++];
    switch (c) {
      case 'M': p.moveTo(n(), n()); break;
      case 'L': p.lineTo(n(), n()); break;
      case 'C': p.cubicTo(n(), n(), n(), n(), n(), n()); break;
      case 'Z': p.close(); break;
    }
  }
  return p;
}

class _G {
  final bool radial;
  final List<double> a;
  final List<List<dynamic>> stops;
  const _G._(this.radial, this.a, this.stops);
  factory _G.lin(num x0, num y0, num x1, num y1, List<List<dynamic>> s) =>
      _G._(false, [x0.toDouble(), y0.toDouble(), x1.toDouble(), y1.toDouble()], s);
  factory _G.rad(num cx, num cy, num r, List<List<dynamic>> s) =>
      _G._(true, [cx.toDouble(), cy.toDouble(), r.toDouble()], s);

  Shader shader(_Pal p) {
    final colors = [for (final s in stops) p.col(s[1] as String, (s[2] as num).toDouble())];
    final offs = [for (final s in stops) (s[0] as num).toDouble()];
    return radial
        ? ui.Gradient.radial(Offset(a[0], a[1]), a[2], colors, offs)
        : ui.Gradient.linear(Offset(a[0], a[1]), Offset(a[2], a[3]), colors, offs);
  }
}

class _L { final Path path; final _G fill; const _L(this.path, this.fill); }
class _S {
  final Path path; final double w, blur; final String tok; final double a;
  const _S(this.path, this.w, this.blur, this.tok, this.a);
}
class _Gold { final Path body, hi; final _G fill; const _Gold(this.body, this.hi, this.fill); }

final List<_L> _hLayers = [
  _L(_P('M0 0 L841 0 L841 700 L0 700 Z'), _G.lin(0,0,0,700,[[0.0,'w1',1.0],[0.45,'w2',1.0],[0.78,'w0',1.0],[1.0,'bg',1.0]])),
  _L(_P('M0 0 L841 0 L841 700 L0 700 Z'), _G.rad(840,130,520,[[0.0,'hot',0.55],[0.25,'c1',0.95],[0.6,'w3',0.5],[1.0,'w2',0.0]])),
  _L(_P('M0 292 C150 276 290 338 470 316 C610 298 740 232 841 176 L841 292 C730 340 560 392 380 388 C220 384 90 372 0 352 Z'), _G.lin(0,320,841,200,[[0.0,'c1',0.8],[0.4,'c0',0.55],[0.75,'hot',0.35],[1.0,'c1',0.5]])),
  _L(_P('M841 70 C760 80 680 130 610 190 C560 232 520 290 460 330 C540 270 600 200 680 150 C740 112 800 100 841 104 Z'), _G.lin(460,330,841,80,[[0.0,'c1',0.0],[0.5,'c2',0.7],[1.0,'hot',0.9]])),
  _L(_P('M0 352 C90 374 220 392 380 390 C560 394 730 342 841 294 L841 440 C720 430 560 470 380 470 C220 470 90 452 0 420 Z'), _G.lin(0,360,0,470,[[0.0,'w0',0.75],[1.0,'w1',0.0]])),
  _L(_P('M0 420 C110 446 240 466 390 458 C560 450 700 392 841 352 L841 470 C700 500 540 540 380 536 C220 532 90 500 0 470 Z'), _G.lin(0,440,841,420,[[0.0,'c0',0.8],[0.5,'w3',0.7],[1.0,'c1',0.8]])),
  _L(_P('M841 396 C760 430 650 492 520 520 C620 548 740 524 841 470 Z'), _G.lin(520,520,841,400,[[0.0,'w3',0.0],[0.5,'c1',0.8],[1.0,'hot',0.85]])),
  _L(_P('M0 150 C140 220 230 290 340 318 C220 300 110 270 0 236 Z'), _G.lin(0,150,340,318,[[0.0,'w3',0.0],[0.6,'c1',0.55],[1.0,'w3',0.0]])),
];
final List<_S> _hStrokes = [
  _S(_P('M0 296 C150 280 290 342 470 320 C610 302 740 236 841 180'), 2.2, 1.5, 'glow', 0.55),
  _S(_P('M0 352 C90 374 220 392 380 388 C560 392 730 340 841 292'), 2.0, 1.5, 'pink', 0.5),
  _S(_P('M0 346 C130 372 270 392 400 372'), 2.4, 1.2, '#F3CC83', 0.85),
  _S(_P('M520 520 C640 548 760 520 841 468'), 2.0, 1.2, 'glow', 0.45),
];
final List<_L> _fLayers = [
  _L(_P('M0 36 C190 62 380 150 560 134 C700 120 790 62 841 52 L841 200 L0 200 Z'), _G.lin(0,40,0,200,[[0.0,'w3',1.0],[0.5,'w1',1.0],[1.0,'w0',1.0]])),
  _L(_P('M0 78 C210 104 400 176 580 154 C700 140 780 104 841 96 L841 200 L0 200 Z'), _G.lin(0,90,841,120,[[0.0,'c0',0.85],[0.5,'w3',0.7],[1.0,'c1',0.9]])),
  _L(_P('M520 118 C640 100 760 70 841 56 L841 130 C760 128 640 150 520 150 Z'), _G.lin(520,130,841,60,[[0.0,'w3',0.0],[0.5,'c2',0.85],[1.0,'hot',0.95]])),
  _L(_P('M0 128 C200 140 400 190 560 178 C700 168 780 140 841 134 L841 200 L0 200 Z'), _G.lin(0,140,841,150,[[0.0,'w3',0.8],[0.6,'c0',0.8],[1.0,'c1',0.9]])),
];
final List<_S> _fStrokes = [
  _S(_P('M470 156 C600 162 740 120 841 88'), 2.0, 1.0, '#F3CC83', 0.85),
  _S(_P('M0 90 C210 112 400 182 580 160 C700 148 780 112 841 104'), 1.8, 1.2, 'pink', 0.45),
];
final _Gold _hGold = _Gold(_P('M841 186 C770 184 700 190 650 222 C610 250 585 288 540 312 C515 326 492 332 468 335 C540 324 580 306 604 285 C640 252 700 228 760 226 C800 225 825 227 841 229 Z'), _P('M841 188 C770 186 702 192 652 224 C612 252 587 289 542 313 C518 326 495 332 472 335'), _G.lin(841,206,470,335,[[0.0,'#FFF1BE',1.0],[0.18,'#E9B964',1.0],[0.45,'#B9792F',1.0],[0.75,'#E3AE58',1.0],[1.0,'#6E4413',0.8]]));
final _Gold _fGold = _Gold(_P('M0 20 C110 16 230 58 330 100 C400 128 450 140 504 142 C440 142 380 126 320 108 C220 76 120 52 0 54 Z'), _P('M0 24 C112 20 230 60 330 102 C400 130 452 142 506 143'), _G.lin(0,36,506,142,[[0.0,'#FFF1BE',1.0],[0.25,'#E9B964',1.0],[0.55,'#B9792F',1.0],[0.85,'#E3AE58',1.0],[1.0,'#6E4413',0.6]]));
final _bag = (side: _P('M44 214 L84 202 L78 360 L40 352 Z'), body: _P('M84 202 L196 198 L228 360 L78 360 Z'), hA: _P('M108 204 C100 150 118 134 140 134 C166 134 170 168 160 200'), hB: _P('M134 202 C128 168 140 152 154 152'));
final _cart = (frame: _P('M139 4 L112 12 L94 98 L22 98'), basket: _P('M6 40 L120 30 L98 94 L24 94 Z'), base: _P('M22 98 L16 114 L96 114'), grid: [_P('M36 38 L44 92'),_P('M64 36 L70 93'),_P('M92 33 L94 93'),_P('M10 60 L112 52'),_P('M16 78 L106 72')], wheels: [Offset(36,128),Offset(88,128)]);


// ════════════════════════════════════════════════════════════════════════════
//  رسّامو الهيدر والفوتر
// ════════════════════════════════════════════════════════════════════════════
void _drawLayers(Canvas c, _Pal p, List<_L> ls) {
  for (final l in ls) {
    c.drawPath(l.path, Paint()..shader = l.fill.shader(p)..isAntiAlias = true);
  }
}

void _drawStrokes(Canvas c, _Pal p, List<_S> ss) {
  for (final s in ss) {
    c.drawPath(
      s.path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.w
        ..strokeCap = StrokeCap.round
        ..color = p.col(s.tok, s.a)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur),
    );
  }
}

/// شريط ذهبي معدني: ظل ← جسم متدرّج ← حافة داكنة ← خط لمعان.
void _drawGold(Canvas c, _Pal p, _Gold g) {
  c.drawPath(
    g.body.shift(const Offset(0, 8)),
    Paint()
      ..color = const Color(0x99000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
  );
  c.drawPath(g.body, Paint()..shader = g.fill.shader(p)..isAntiAlias = true);
  c.drawPath(
    g.body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xB35A320A),
  );
  c.drawPath(
    g.hi,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xE6FFF6D2),
  );
}

void _drawBagAndCart(Canvas c, _Pal p) {
  // حقيبة
  c.drawPath(_bag.side, Paint()..color = p.col('w3', 0.9));
  c.drawPath(
    _bag.body,
    Paint()
      ..shader = ui.Gradient.linear(const Offset(80, 200), const Offset(228, 360),
          [p.col('c2', 1), p.col('w3', 1)]),
  );
  final st = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  c.drawPath(_bag.hA, st..strokeWidth = 6..color = p.col('c2', 1));
  c.drawPath(_bag.hB, st..strokeWidth = 3.5..color = p.col('w3', 1));

  // عربة
  c.save();
  c.translate(670, 288);
  st..color = p.col('c2', 1);
  c.drawPath(_cart.frame, st..strokeWidth = 7);
  c.drawPath(_cart.base, st..strokeWidth = 7);
  c.drawPath(_cart.basket, st..strokeWidth = 6);
  for (final g in _cart.grid) {
    c.drawPath(g, st..strokeWidth = 4);
  }
  for (final w in _cart.wheels) {
    c.drawCircle(w, 10, st..strokeWidth = 5);
  }
  c.restore();
}

/// رسم الهيدر. [compact]: بلا حقيبة/عربة ومزاح لأعلى ليناسب الشاشات الداخلية.
class AuthHeaderPainter extends CustomPainter {
  final bool dark;
  final bool compact;
  const AuthHeaderPainter({required this.dark, this.compact = false});

  @override
  void paint(Canvas canvas, Size size) {
    final p = _Pal(dark ? _dark : _light);
    final s = size.width / kArtW;
    canvas.save();
    canvas.scale(s);
    if (compact) canvas.translate(0, -110);
    _drawLayers(canvas, p, _hLayers);
    _drawStrokes(canvas, p, _hStrokes);
    _drawGold(canvas, p, _hGold);
    if (!compact) _drawBagAndCart(canvas, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AuthHeaderPainter o) => o.dark != dark || o.compact != compact;
}

/// رسم الزخرفة السفلية؛ يملأ أي ارتفاع إضافي (خلف شريط التنقل) بلون القاعدة.
class AuthFooterPainter extends CustomPainter {
  final bool dark;
  const AuthFooterPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final p = _Pal(dark ? _dark : _light);
    final s = size.width / kArtW;
    final artH = kFooterArtH * s;
    canvas.save();
    canvas.translate(0, size.height - artH);
    // امتداد القاعدة تحت الرسم (edge-to-edge خلف شريط التنقل)
    canvas.drawRect(Rect.fromLTWH(0, artH - 1, size.width, size.height), Paint()..color = p.col('w0', 1));
    canvas.scale(s);
    _drawLayers(canvas, p, _fLayers);
    _drawStrokes(canvas, p, _fStrokes);
    _drawGold(canvas, p, _fGold);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AuthFooterPainter o) => o.dark != dark;
}

/// خط ذهبي منحنٍ قصير تحت العبارة التعريفية (متدرّج معدني، سميك في الوسط).
class GoldUnderlinePainter extends CustomPainter {
  const GoldUnderlinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, h * 0.78)
      ..quadraticBezierTo(w * 0.5, h * -0.30, w, h * 0.78)
      ..quadraticBezierTo(w * 0.5, h * 0.18, 0, h * 0.78)
      ..close();
    canvas.drawPath(
      path.shift(Offset(0, h * 0.25)),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.3),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(w, 0), const [
          Color(0x009A6420), Color(0xFFE3AE58), Color(0xFFFFF1BE), Color(0xFFE3AE58), Color(0x009A6420),
        ], const [0.0, 0.2, 0.5, 0.8, 1.0]),
    );
  }

  @override
  bool shouldRepaint(covariant GoldUnderlinePainter o) => false;
}
