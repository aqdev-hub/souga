// lib/screens/seller/delivery_scan_screen.dart
//
// مسح باركود (QR) رمز التسليم من هاتف المشتري بدل كتابته.
// الباركود يحمل: SOUGA-DLV|<orderId>|<code>  — نتحقق أنه لنفس الطلب قبل قبوله.
// يقبل أيضاً باركود/QR يحمل الأربعة أرقام فقط.
// تُرجِع الشاشة الرمز (4 أرقام) أو null عند الرجوع/اختيار الإدخال اليدوي.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../utils/app_colors.dart';

/// بناء حمولة الباركود (يستعملها المشتري لعرضه)
String deliveryQrPayload(String orderId, String code) => 'SOUGA-DLV|$orderId|$code';

class DeliveryScanScreen extends StatefulWidget {
  final String orderId;
  const DeliveryScanScreen({super.key, required this.orderId});

  @override
  State<DeliveryScanScreen> createState() => _DeliveryScanScreenState();
}

class _DeliveryScanScreenState extends State<DeliveryScanScreen> {
  final MobileScannerController _ctrl = MobileScannerController(
    formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.code39],
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _done = false;
  bool _torch = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? _extractCode(String raw) {
    final v = raw.trim();
    if (RegExp(r'^\d{4}$').hasMatch(v)) return v;
    final parts = v.split('|');
    if (parts.length == 3 && parts[0] == 'SOUGA-DLV' && RegExp(r'^\d{4}$').hasMatch(parts[2])) {
      if (parts[1] != widget.orderId) {
        setState(() => _error = 'هذا الباركود يخص طلباً آخر');
        return null;
      }
      return parts[2];
    }
    setState(() => _error = 'باركود غير صالح لرمز التسليم');
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final code = _extractCode(raw);
      if (code != null) {
        _done = true;
        HapticFeedback.mediumImpact();
        Navigator.pop(context, code);
        return;
      } else {
        HapticFeedback.lightImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = MediaQuery.of(context).size;
    final box = size.width * 0.68;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('مسح باركود التسليم'),
        actions: [
          IconButton(
            tooltip: 'الفلاش',
            icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded),
            onPressed: () async {
              await _ctrl.toggleTorch();
              if (mounted) setState(() => _torch = !_torch);
            },
          ),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) => const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.no_photography_outlined, color: Colors.white70, size: 56),
                SizedBox(height: 12),
                Text('تعذّر تشغيل الكاميرا',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('اسمح لسوجا باستخدام الكاميرا من إعدادات الهاتف، أو أدخل الرمز يدوياً.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.5)),
              ]),
            ),
          ),
        ),
        // إطار المسح
        IgnorePointer(
          child: CustomPaint(
            size: size,
            painter: _FramePainter(box: box, color: colors.accent),
          ),
        ),
        Positioned(
          left: 20, right: 20, bottom: 28,
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _error == null
                    ? const Text('وجّه الكاميرا نحو الباركود في هاتف المشتري',
                        key: ValueKey('hint'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 14))
                    : Container(
                        key: ValueKey(_error),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            color: colors.error, borderRadius: BorderRadius.circular(12)),
                        child: Text(_error!, style: const TextStyle(color: Colors.white)),
                      ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.keyboard_alt_outlined),
                label: const Text('إدخال الرمز يدوياً'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _FramePainter extends CustomPainter {
  final double box;
  final Color color;
  _FramePainter({required this.box, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.42), width: box, height: box);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(22));
    // تعتيم خارج الإطار
    final bg = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRRect(rr);
    canvas.drawPath(
      Path.combine(PathOperation.difference, bg, hole),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    // زوايا
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const l = 30.0;
    final r = rect;
    for (final c in [
      [r.topLeft, const Offset(l, 0), const Offset(0, l)],
      [r.topRight, const Offset(-l, 0), const Offset(0, l)],
      [r.bottomLeft, const Offset(l, 0), const Offset(0, -l)],
      [r.bottomRight, const Offset(-l, 0), const Offset(0, -l)],
    ]) {
      final o = c[0];
      canvas.drawLine(o, o + c[1], p);
      canvas.drawLine(o, o + c[2], p);
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => old.box != box || old.color != color;
}
