// lib/services/share_options_sheet.dart
// ─────────────────────────────────────────────────────────────────────────────
//  نظام المشاركة والتسويق الموحّد — Souga
//
//  المعمارية:
//    SougaProductLink  — رابط المنتج (ثابت، لا يُبنى من رابط التطبيق)
//    SougaAdText       — النص التسويقي الاحترافي (بدون تكرار)
//    SougaMediaBuilder — بنّاء الوسائط (Story / Reel Kit / Single / Carousel)
//    showShareOptionsSheet — نقطة الدخول الوحيدة
//
//  ملاحظة Reel:
//    Flutter/Dart لا يتضمن video encoder. لذلك "Reel Kit" يُولّد 3 فريمات
//    إعلانية عالية الجودة (بطاقات مُصمَّمة لـ Reel) تُشارك كـ slideshow.
//    المستخدم يستطيع رفعها لـ CapCut / Instagram / TikTok مباشرة لبناء Reel.
//    هذا أفضل من محاولة بناء فيديو بـ Canvas لأنه يُنتج جودة أعلى.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ثوابت
// ════════════════════════════════════════════════════════════════════════════

const String _kProductBase = 'https://souga-5fdb3.web.app/product';

const Color _kCrimson  = Color(0xFFDC143C);
const Color _kCrimsonD = Color(0xFF7A0021);
const Color _kGold     = Color(0xFFFFB300);
const Color _kDark     = Color(0xFF0D0D1A);
const Color _kDarkMid  = Color(0xFF1A1A2E);

// ════════════════════════════════════════════════════════════════════════════
//  ShareProductData
// ════════════════════════════════════════════════════════════════════════════

class ShareProductData {
  final String       productId;
  final String       productName;
  final String       productPrice;
  final String       currencySymbol;
  final String       storeName;
  final String       sellerLogo;
  final List<String> imageUrls;       // روابط كاملة
  final String       adText;          // نص Gemini (قد يكون فارغاً)
  final String       productDescription;

  const ShareProductData({
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.currencySymbol,
    required this.storeName,
    this.sellerLogo          = '',
    required this.imageUrls,
    this.adText              = '',
    this.productDescription  = '',
  });

  // ── رابط المنتج — مصدر واحد لا يتغيّر ─────────────────────────────────
  String get webLink => '$_kProductBase/$productId';
}

// ════════════════════════════════════════════════════════════════════════════
//  SougaAdText — بنّاء النص التسويقي الاحترافي
// ════════════════════════════════════════════════════════════════════════════

class SougaAdText {
  final ShareProductData d;
  const SougaAdText(this.d);

  String build({String? prefix, bool forReel = false, bool forStory = false}) {
    final ad     = d.adText.trim();
    final hasAd  = ad.isNotEmpty;

    // Hook: إما النص من Gemini أو عنوان افتراضي جذاب
    final hook = hasAd ? ad : _buildHook();

    // تحقق من التكرار
    final needsPrice = !_contains(hook, [d.productPrice, d.currencySymbol]);
    final needsStore = d.storeName.isNotEmpty &&
        !_contains(hook, [d.storeName]);
    final needsCta   = !_contains(hook, ['اطلب', 'تسوق', 'شاهد', 'احصل']);

    final buf = StringBuffer();

    if (prefix != null && prefix.isNotEmpty) {
      buf.writeln(prefix);
      buf.writeln();
    }

    buf.write(hook);

    if (needsPrice || needsStore) {
      buf.writeln();
    }
    if (needsPrice) buf.write('\n💰 ${d.productPrice} ${d.currencySymbol}');
    if (needsStore) buf.write('\n🏪 ${d.storeName}');

    buf.writeln();
    if (needsCta) {
      buf.write('\n🛒 اطلب الآن: ${d.webLink}');
    } else {
      buf.write('\n🔗 ${d.webLink}');
    }

    final result = buf.toString().trim();

    debugPrint('[Souga Share] ────────────────────');
    debugPrint('[Souga Share] product : ${d.productId}');
    debugPrint('[Souga Share] webLink : ${d.webLink}');
    debugPrint('[Souga Share] text    :\n$result');
    debugPrint('[Souga Share] ────────────────────');

    return result;
  }

  String buildReel()  => build(prefix: '🎬 ${d.storeName}', forReel:  true);
  String buildStory() => build(prefix: '✨ ${d.storeName}', forStory: true);

  // ── Hook ذكي بدون Gemini ────────────────────────────────────────────────
  String _buildHook() {
    final name = d.productName.trim();
    final desc = _shortDesc();

    if (desc.isEmpty) {
      return '✨ $name\n\nجودة لا تُضاهى بسعر لا يُقاوم.';
    }
    return '✨ $name\n\n$desc';
  }

  String _shortDesc() {
    final desc = d.productDescription.trim();
    if (desc.isEmpty) return '';
    return desc.length > 80 ? '${desc.substring(0, 80)}...' : desc;
  }

  bool _contains(String text, List<String> terms) =>
      terms.any((t) => t.isNotEmpty && text.contains(t));
}

// ════════════════════════════════════════════════════════════════════════════
//  showShareOptionsSheet — نقطة الدخول الوحيدة
// ════════════════════════════════════════════════════════════════════════════

Future<void> showShareOptionsSheet(
  BuildContext context, {
  required ShareProductData data,
}) =>
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder:            (_) => _ShareSheet(data: data),
    );

// ════════════════════════════════════════════════════════════════════════════
//  تنزيل صورة
// ════════════════════════════════════════════════════════════════════════════

Future<File?> _dlImg(String url) async {
  if (url.trim().isEmpty) return null;
  try {
    final res = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final dir  = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/sg_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(res.bodyBytes);
    return file;
  } catch (e) {
    debugPrint('[Souga Share] download error: $e  url=$url');
    return null;
  }
}

Future<ui.Image?> _loadUiImage(File f, {int? w, int? h}) async {
  try {
    final bytes = await f.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes,
        targetWidth: w, targetHeight: h);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) { return null; }
}

// ════════════════════════════════════════════════════════════════════════════
//  _ShareSheet
// ════════════════════════════════════════════════════════════════════════════

class _ShareSheet extends StatefulWidget {
  final ShareProductData data;
  const _ShareSheet({required this.data});
  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  bool   _loading      = false;
  String _loadingLabel = '';

  static const _opts = <_Opt>[
    _Opt('carousel', Icons.photo_library_outlined, Color(0xFF7B2D8B),
        'جميع الصور (Carousel)',
        'كل صور المنتج كألبوم — مثالي للمنشور'),
    _Opt('single',   Icons.photo_outlined,          Color(0xFFE91E8C),
        'الصورة الرئيسية',
        'صورة واحدة احترافية مع النص التسويقي'),
    _Opt('story',    Icons.auto_stories_outlined,   Color(0xFFFF5722),
        'Story إعلانية (9:16)',
        'تصميم Story جاهز للنشر على Instagram'),
    _Opt('reel',     Icons.auto_awesome_motion,     Color(0xFF0095F6),
        'Reel Kit — 3 فريمات تسويقية',
        'فريمات جاهزة لـ CapCut / Instagram / TikTok'),
  ];

  Future<void> _exec(String id) async {
    if (_loading) return;
    setState(() {
      _loading      = true;
      _loadingLabel = 'جاري التحضير...';
    });
    try {
      switch (id) {
        case 'carousel': await _doCarousel(); break;
        case 'single':   await _doSingle();   break;
        case 'story':    await _doStory();    break;
        case 'reel':     await _doReelKit();  break;
      }
    } catch (e) {
      debugPrint('[Souga Share] exec error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         const Text('حدث خطأ أثناء التحضير'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Carousel: جميع الصور ─────────────────────────────────────────────────
  Future<void> _doCarousel() async {
    setState(() => _loadingLabel = 'جاري تنزيل الصور...');
    final d    = widget.data;
    final text = SougaAdText(d).build();

    final files = <XFile>[];
    for (final url in d.imageUrls.take(10)) {
      setState(() => _loadingLabel =
          'تنزيل صورة ${files.length + 1}/${d.imageUrls.take(10).length}...');
      final f = await _dlImg(url);
      if (f != null) files.add(XFile(f.path, mimeType: 'image/jpeg'));
    }

    if (files.isEmpty) {
      await Share.share(text, subject: d.productName);
    } else {
      await Share.shareXFiles(files, text: text, subject: d.productName);
    }
    if (mounted) Navigator.pop(context);
  }

  // ── Single: صورة رئيسية واحدة ────────────────────────────────────────────
  Future<void> _doSingle() async {
    setState(() => _loadingLabel = 'جاري تحضير الصورة...');
    final d    = widget.data;
    final text = SougaAdText(d).build();

    if (d.imageUrls.isEmpty) {
      await Share.share(text, subject: d.productName);
    } else {
      final f = await _dlImg(d.imageUrls.first);
      if (f != null) {
        await Share.shareXFiles(
          [XFile(f.path, mimeType: 'image/jpeg')],
          text: text, subject: d.productName,
        );
      } else {
        await Share.share(text, subject: d.productName);
      }
    }
    if (mounted) Navigator.pop(context);
  }

  // ── Story: بطاقة إعلانية 1080×1920 ──────────────────────────────────────
  Future<void> _doStory() async {
    setState(() => _loadingLabel = 'جاري بناء Story...');
    final d    = widget.data;
    final text = SougaAdText(d).buildStory();

    final storyFile = await SougaMediaBuilder.buildStory(d,
        onProgress: (s) { if (mounted) setState(() => _loadingLabel = s); });

    if (storyFile != null) {
      await Share.shareXFiles(
        [XFile(storyFile.path, mimeType: 'image/jpeg')],
        text: text, subject: d.productName,
      );
    } else {
      await Share.share(text, subject: d.productName);
    }
    if (mounted) Navigator.pop(context);
  }

  // ── Reel Kit: 3 فريمات تسويقية جاهزة للـ Reel ───────────────────────────
  //
  //  لماذا فريمات وليس فيديو؟
  //  Flutter/Dart لا يحتوي video encoder بدون packages خارجية.
  //  بدلاً من صورة collage واحدة ضعيفة، نُولّد 3 فريمات إعلانية عالية الجودة:
  //    Frame 1: بطاقة المنتج الرئيسية (Hook + الصورة الأولى)
  //    Frame 2: مزايا المنتج (الصور 2-3 في layout)
  //    Frame 3: CTA + رابط المنتج + شعار Souga
  //  المستخدم يرفعها لـ CapCut/Instagram/TikTok → Reel احترافي في ثوانٍ.
  Future<void> _doReelKit() async {
    setState(() => _loadingLabel = 'جاري بناء فريمات Reel...');
    final d    = widget.data;
    final text = SougaAdText(d).buildReel();

    final frames = await SougaMediaBuilder.buildReelKit(d,
        onProgress: (s) { if (mounted) setState(() => _loadingLabel = s); });

    if (frames.isEmpty) {
      await Share.share(text, subject: d.productName);
    } else {
      final xfiles = frames
          .map((f) => XFile(f.path, mimeType: 'image/jpeg'))
          .toList();
      final reelInstructions = '''$text

━━━━━━━━━━━━━━━━━━
📱 لإنشاء Reel احترافي:
1. افتح CapCut أو Instagram
2. ارفع هذه الـ ${frames.length} فريمات
3. أضف موسيقى من المكتبة
4. انشر Reel جاهز!
━━━━━━━━━━━━━━━━━━''';
      await Share.shareXFiles(xfiles,
          text: reelInstructions, subject: d.productName);
    }
    if (mounted) Navigator.pop(context);
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Container(
      decoration: const BoxDecoration(
        color:        _kDarkMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // handle
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        // header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: _kCrimson.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.campaign_outlined,
                color: _kCrimson, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.productName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white,
                    fontSize: 15, fontWeight: FontWeight.bold)),
            Text(
                '${d.productPrice} ${d.currencySymbol}'
                '${d.storeName.isNotEmpty ? ' · ${d.storeName}' : ''}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ])),
          // عدد الصور
          if (d.imageUrls.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${d.imageUrls.length} صور',
                  style: const TextStyle(color: _kGold, fontSize: 11)),
            ),
        ]),
        const SizedBox(height: 18),

        // loading
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: _kCrimson, strokeWidth: 2.5)),
              const SizedBox(width: 14),
              Flexible(child: Text(_loadingLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 14))),
            ]),
          )
        else ...[
          for (final opt in _opts) ...[
            _OptTile(opt: opt, onTap: () => _exec(opt.id)),
            const SizedBox(height: 8),
          ],
          const Divider(color: Colors.white12, height: 20),
          const Row(children: [
            Text('شارك على:',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            Spacer(),
            _PI(Icons.camera_alt,     Color(0xFFE91E8C), 'Instagram'),
            SizedBox(width: 10),
            _PI(Icons.chat_bubble,    Color(0xFF25D366), 'WhatsApp'),
            SizedBox(width: 10),
            _PI(Icons.facebook,       Color(0xFF1877F2), 'Facebook'),
            SizedBox(width: 10),
            _PI(Icons.share_outlined, Colors.white54,           'أخرى'),
          ]),
        ],
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SougaMediaBuilder — بنّاء الوسائط
// ════════════════════════════════════════════════════════════════════════════

abstract class SougaMediaBuilder {
  // ── Story: بطاقة إعلانية 1080×1920 ────────────────────────────────────
  static Future<File?> buildStory(
    ShareProductData d, {
    void Function(String)? onProgress,
  }) async {
    const W = 1080.0;
    const H = 1920.0;
    try {
      onProgress?.call('تنزيل صورة المنتج...');
      File? prodFile;
      if (d.imageUrls.isNotEmpty) {
        prodFile = await _dlImg(d.imageUrls.first);
      }
      final prodImg = prodFile != null
          ? await _loadUiImage(prodFile, w: 1080, h: 1080)
          : null;

      final rec = ui.PictureRecorder();
      final c   = Canvas(rec, const Rect.fromLTWH(0, 0, W, H));

      // خلفية متدرجة
      _drawBg(c, W, H,
          [_kCrimson, _kCrimsonD, _kDark],
          [0.0, 0.5, 1.0]);

      // دوائر زخرفية
      _drawCircles(c, W, H);

      // صورة المنتج — مستديرة في المنتصف
      if (prodImg != null) {
        onProgress?.call('بناء Story...');
        const imgRect = Rect.fromLTWH(90, 340, 900, 900);
        // ظل
        c.drawRRect(
          RRect.fromRectAndRadius(imgRect, const Radius.circular(36)),
          Paint()
            ..color      = Colors.black45
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
        );
        // صورة
        c.save();
        c.clipRRect(
            RRect.fromRectAndRadius(imgRect, const Radius.circular(36)));
        c.drawImageRect(
          prodImg,
          Rect.fromLTWH(
              0, 0, prodImg.width.toDouble(), prodImg.height.toDouble()),
          imgRect, Paint(),
        );
        c.restore();
        // حدة بيضاء حول الصورة
        c.drawRRect(
          RRect.fromRectAndRadius(imgRect, const Radius.circular(36)),
          Paint()
            ..color  = Colors.white.withValues(alpha: 0.12)
            ..style  = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        // placeholder
        c.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(90, 340, 900, 900), const Radius.circular(36)),
          Paint()..color = Colors.white.withValues(alpha: 0.06),
        );
      }

      // اسم المتجر — أعلى
      if (d.storeName.isNotEmpty) {
        _drawText(c, d.storeName, 80, 230, W - 160, 46,
            Colors.white.withValues(alpha: 0.88));
      }

      // سطر فاصل
      c.drawLine(const Offset(80, 300), const Offset(400, 300),
          Paint()
            ..color       = Colors.white.withValues(alpha: 0.25)
            ..strokeWidth = 1.5);

      // اسم المنتج
      _drawText(c, d.productName, 80, 1320, W - 160, 48,
          Colors.white, FontWeight.bold);

      // السعر
      _drawBadge(c, '${d.productPrice} ${d.currencySymbol}',
          80, 1420, 460, 90, _kGold, _kDark);

      // زر CTA
      _drawCta(c, '🛒  اطلب الآن', 80, 1640, W - 160, 100);

      // شعار Souga
      _drawText(c, 'Souga سوجا', W - 280, H - 72, 260, 26,
          Colors.white.withValues(alpha: 0.45));

      return await _savePicture(rec, W.toInt(), H.toInt(), 'story');
    } catch (e) {
      debugPrint('[Souga Media] story error: $e');
      return null;
    }
  }

  // ── Reel Kit: 3 فريمات تسويقية ─────────────────────────────────────────
  static Future<List<File>> buildReelKit(
    ShareProductData d, {
    void Function(String)? onProgress,
  }) async {
    const W = 1080.0;
    const H = 1920.0;
    final files = <File>[];

    try {
      // تنزيل الصور
      onProgress?.call('تنزيل صور المنتج...');
      final imgs = <ui.Image>[];
      for (final url in d.imageUrls.take(6)) {
        final f = await _dlImg(url);
        if (f != null) {
          final img = await _loadUiImage(f, w: 1080, h: 1080);
          if (img != null) imgs.add(img);
        }
      }

      // ── Frame 1: Hook — الصورة الأولى مع العنوان ─────────────────────
      onProgress?.call('بناء فريم 1/3 (Hook)...');
      {
        final rec = ui.PictureRecorder();
        final c   = Canvas(rec, const Rect.fromLTWH(0, 0, W, H));

        // خلفية داكنة جذابة
        _drawBg(c, W, H, [_kDark, _kDarkMid, const Color(0xFF0A0A1F)],
            [0.0, 0.5, 1.0]);
        _drawCircles(c, W, H, opacity: 0.06);

        // صورة المنتج الأولى — كبيرة في الوسط
        if (imgs.isNotEmpty) {
          const imgRect = Rect.fromLTWH(0, 260, W, W);
          // overlay gradient فوق الصورة
          c.save();
          c.clipRect(imgRect);
          c.drawImageRect(imgs[0],
              Rect.fromLTWH(0, 0, imgs[0].width.toDouble(),
                  imgs[0].height.toDouble()),
              imgRect, Paint());
          // gradient أعلى وأسفل
          _drawGrad(c, 0, 260, W, 300,
              [_kDark, Colors.transparent], [0.0, 1.0]);
          _drawGrad(c, 0, 260 + W - 300, W, 300,
              [Colors.transparent, _kDark], [0.0, 1.0]);
          c.restore();
        }

        // نص Hook
        _drawText(c, '✨', W / 2 - 40, 120, 80, 80, Colors.white);
        _drawText(c, d.productName, 60, 220, W - 120, 62,
            Colors.white, FontWeight.bold);

        // نص جذاب أسفل الصورة
        final hook = d.productDescription.isNotEmpty
            ? (d.productDescription.length > 60
                ? '${d.productDescription.substring(0, 60)}...'
                : d.productDescription)
            : 'جودة استثنائية بسعر لا يُقاوم';
        _drawText(c, hook, 60, 1380, W - 120, 38,
            Colors.white.withValues(alpha: 0.85));

        _drawBadge(c, '${d.productPrice} ${d.currencySymbol}',
            60, 1480, 420, 88, _kGold, _kDark);

        // شعار صغير
        _drawText(c, 'Souga سوجا', W - 260, H - 60, 220, 24,
            Colors.white.withValues(alpha: 0.4));

        final f = await _savePicture(rec, W.toInt(), H.toInt(), 'reel_f1');
        if (f != null) files.add(f);
      }

      // ── Frame 2: مزايا — شبكة الصور ─────────────────────────────────
      onProgress?.call('بناء فريم 2/3 (مزايا)...');
      {
        final rec = ui.PictureRecorder();
        final c   = Canvas(rec, const Rect.fromLTWH(0, 0, W, H));

        _drawBg(c, W, H,
            [_kCrimsonD, _kCrimson.withValues(alpha: 0.8), _kDark],
            [0.0, 0.4, 1.0]);

        // عنوان
        _drawText(c, 'لماذا ${d.productName}؟', 60, 100, W - 120, 54,
            Colors.white, FontWeight.bold);
        c.drawLine(const Offset(60, 175), const Offset(340, 175),
            Paint()
              ..color       = _kGold
              ..strokeWidth = 3);

        // شبكة صور 2×2 من الصور المتاحة
        final gridImgs = imgs.take(4).toList();
        const cellW    = (W - 40) / 2;
        const cellH    = cellW * 1.1;
        for (int i = 0; i < gridImgs.length; i++) {
          final col  = i % 2;
          final row  = i ~/ 2;
          final x    = 20.0 + col * (cellW + 10);
          final y    = 220.0 + row * (cellH + 10);
          final rect = Rect.fromLTWH(x, y, cellW, cellH);
          c.save();
          c.clipRRect(RRect.fromRectAndRadius(rect,
              const Radius.circular(20)));
          c.drawImageRect(
            gridImgs[i],
            Rect.fromLTWH(0, 0, gridImgs[i].width.toDouble(),
                gridImgs[i].height.toDouble()),
            rect, Paint(),
          );
          c.restore();
        }

        // إذا أقل من 4 صور → placeholder
        final placeholderCount = 4 - gridImgs.length;
        for (int i = gridImgs.length; i < gridImgs.length + placeholderCount; i++) {
          final col  = i % 2;
          final row  = i ~/ 2;
          final x    = 20.0 + col * (cellW + 10);
          final y    = 220.0 + row * (cellH + 10);
          c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x, y, cellW, cellH),
                const Radius.circular(20)),
            Paint()..color = Colors.white.withValues(alpha: 0.06),
          );
        }

        // نص + سعر أسفل
        final gridBottom = 220.0 + (gridImgs.length <= 2 ? 1 : 2) * (cellH + 10);
        _drawText(c, d.storeName, 60, gridBottom + 30, W - 120, 36,
            _kGold, FontWeight.bold);
        _drawText(c, '${d.productPrice} ${d.currencySymbol}',
            60, gridBottom + 90, W - 120, 52,
            Colors.white, FontWeight.bold);

        _drawText(c, 'Souga سوجا', W - 260, H - 60, 220, 24,
            Colors.white.withValues(alpha: 0.4));

        final f = await _savePicture(rec, W.toInt(), H.toInt(), 'reel_f2');
        if (f != null) files.add(f);
      }

      // ── Frame 3: CTA + رابط + شعار ───────────────────────────────────
      onProgress?.call('بناء فريم 3/3 (CTA)...');
      {
        final rec = ui.PictureRecorder();
        final c   = Canvas(rec, const Rect.fromLTWH(0, 0, W, H));

        _drawBg(c, W, H,
            [_kDark, _kDarkMid, _kCrimsonD],
            [0.0, 0.6, 1.0]);
        _drawCircles(c, W, H, opacity: 0.08);

        // صورة الأولى خلفية شبه شفافة
        if (imgs.isNotEmpty) {
          c.save();
          final paint = Paint()
            ..color = Colors.white.withValues(alpha: 0.07);
          c.drawImageRect(
            imgs[0],
            Rect.fromLTWH(0, 0, imgs[0].width.toDouble(),
                imgs[0].height.toDouble()),
            const Rect.fromLTWH(0, 500, W, W),
            paint,
          );
          c.restore();
        }

        // نص CTA
        _drawText(c, '🛍️ لا تفوّتك الفرصة!', 80, 300, W - 160, 58,
            Colors.white, FontWeight.bold);
        _drawText(c, d.productName, 80, 400, W - 160, 44,
            Colors.white.withValues(alpha: 0.9));

        _drawBadge(c, '${d.productPrice} ${d.currencySymbol}',
            80, 520, 480, 96, _kGold, _kDark);

        // زر اطلب الآن كبير
        _drawCta(c, '🛒  اطلب الآن من سوجا', 80, 680, W - 160, 110);

        // رابط المنتج
        _drawText(c, d.webLink, 80, 820, W - 160, 26,
            Colors.white.withValues(alpha: 0.55));

        // شعار Souga كبير
        _drawText(c, 'Souga', 80, H - 280, 500, 120,
            Colors.white.withValues(alpha: 0.04), FontWeight.bold);
        _drawText(c, 'سوجا المحلي', 80, H - 140, 400, 40,
            _kCrimson, FontWeight.bold);
        _drawText(c, 'souga.store', 80, H - 72, 300, 28,
            Colors.white.withValues(alpha: 0.45));

        final f = await _savePicture(rec, W.toInt(), H.toInt(), 'reel_f3');
        if (f != null) files.add(f);
      }
    } catch (e) {
      debugPrint('[Souga Media] reelKit error: $e');
    }

    return files;
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  static void _drawBg(Canvas c, double w, double h,
      List<Color> colors, List<double> stops) {
    c.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
            Offset.zero, Offset(w * 0.3, h),
            colors, stops),
    );
  }

  static void _drawGrad(Canvas c, double x, double y,
      double w, double h, List<Color> colors, List<double> stops) {
    c.drawRect(
      Rect.fromLTWH(x, y, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
            Offset(x, y), Offset(x, y + h),
            colors, stops),
    );
  }

  static void _drawCircles(Canvas c, double w, double h,
      {double opacity = 0.05}) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    c.drawCircle(Offset(w * 0.85, h * 0.15), 280, paint);
    c.drawCircle(Offset(w * 0.1,  h * 0.8),  200, paint);
    c.drawCircle(Offset(w * 0.6,  h * 0.6),  160,
        Paint()..color = _kCrimson.withValues(alpha: opacity * 0.5));
  }

  static void _drawText(Canvas c, String text, double x, double y,
      double maxW, double size, Color color,
      [FontWeight weight = FontWeight.normal]) {
    TextPainter(
      text:      TextSpan(text: text,
          style: TextStyle(color: color, fontSize: size, fontWeight: weight,
              height: 1.3)),
      textDirection: TextDirection.rtl,
      maxLines:      3,
    )
      ..layout(maxWidth: maxW)
      ..paint(c, Offset(x, y));
  }

  static void _drawBadge(Canvas c, String text,
      double x, double y, double w, double h,
      Color bg, Color fg) {
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h),
          const Radius.circular(24)),
      Paint()..color = bg,
    );
    _drawText(c, text, x + 20, y + (h - 48) / 2, w - 40, 44, fg,
        FontWeight.bold);
  }

  static void _drawCta(Canvas c, String text,
      double x, double y, double w, double h) {
    // ظل
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, y + 8, w, h), const Radius.circular(30)),
      Paint()
        ..color      = Colors.black38
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // زر
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h), const Radius.circular(30)),
      Paint()
        ..shader = ui.Gradient.linear(
            Offset(x, y), Offset(x + w, y),
            [Colors.white, const Color(0xFFF5F5F5)]),
    );
    _drawText(c, text, x + 20, y + (h - 44) / 2, w - 40, 40,
        _kCrimson, FontWeight.bold);
  }

  static Future<File?> _savePicture(
      ui.PictureRecorder rec, int w, int h, String name) async {
    try {
      final pic   = rec.endRecording();
      final img   = await pic.toImage(w, h);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      return file;
    } catch (e) {
      debugPrint('[Souga Media] save error: $e');
      return null;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  UI Helpers
// ════════════════════════════════════════════════════════════════════════════

class _Opt {
  final String   id, label, sublabel;
  final IconData icon;
  final Color    color;
  const _Opt(this.id, this.icon, this.color, this.label, this.sublabel);
}

class _OptTile extends StatelessWidget {
  final _Opt opt; final VoidCallback onTap;
  const _OptTile({required this.opt, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color:        opt.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(
            color: opt.color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: opt.color,
              borderRadius: BorderRadius.circular(12)),
          child: Icon(opt.icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(opt.label,
              style: const TextStyle(color: Colors.white,
                  fontSize: 14, fontWeight: FontWeight.bold)),
          Text(opt.sublabel,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 11)),
        ])),
        Icon(Icons.arrow_forward_ios_rounded,
            color: opt.color, size: 14),
      ]),
    ),
  );
}

class _PI extends StatelessWidget {
  final IconData i; final Color c; final String l;
  const _PI(this.i, this.c, this.l);
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(width: 34, height: 34,
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.14),
            shape: BoxShape.circle),
        child: Icon(i, color: c, size: 17)),
    const SizedBox(height: 2),
    Text(l, style: const TextStyle(color: Colors.white30, fontSize: 9)),
  ]);
}
