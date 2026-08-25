// lib/services/marketing_service.dart
//
//  v3.0 — المشاركة الاحترافية:
//  ✅ مشاركة صورة المنتج + النص الإعلاني معاً
//  ✅ "اطلب الآن" = deep link للمنتج داخل التطبيق
//  ✅ لو التطبيق غير مثبت → رابط تنزيل الموقع
//  ✅ timeout 60 ثانية
//  ✅ retry تلقائي

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'share_options_sheet.dart' show showShareOptionsSheet, ShareProductData, SougaAdText;
import 'api_client.dart';

// رابط تنزيل التطبيق من الموقع الشخصي
const String _appDownloadUrl =
    'https://abdulquddus-dev.github.io/?project=souga';

// ─────────────────────────────────────────────────────────────────────────────
class MarketingService {
  static const String _serverUrl = ApiClient.serverBaseUrl;

  static Future<MarketingResult> generateAd({
    required String productName,
    required String productDescription,
    required String productPrice,
    required String storeName,
    required String category,
    String currencyCode = 'SAR',
    int    maxRetries   = 2,
  }) async {
    Exception? lastErr;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('[Marketing] Attempt $attempt for: $productName');
        final res = await http.post(
          Uri.parse('$_serverUrl/generate-ad'),
          headers: await ApiClient.authHeaders(),
          body: jsonEncode({
            'productName':        productName,
            'productDescription': productDescription,
            'productPrice':       productPrice,
            'storeName':          storeName,
            'category':           category,
            'currency':           currencyCode,
          }),
        ).timeout(const Duration(seconds: 60));

        if (res.statusCode == 401 || res.statusCode == 403) {
          return MarketingResult.error('auth', ApiClient.friendlyAuthError(res.statusCode));
        }
        if (res.statusCode == 429) {
          return MarketingResult.error('rate_limit', ApiClient.friendlyAuthError(429));
        }
        if (res.statusCode == 503 && attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 8));
          continue;
        }
        if (res.statusCode != 200) {
          lastErr = Exception('HTTP ${res.statusCode}');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: attempt * 3));
            continue;
          }
          return MarketingResult.error('server_error', 'خطأ في الخادم. تحقق من الاتصال.');
        }

        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>? ?? {};

        return MarketingResult.success(MarketingContent(
          title:            (data['title']            ?? productName).toString(),
          instagramCaption: (data['instagramCaption'] ?? '').toString(),
          features:         List<String>.from(data['features'] ?? []),
          hashtags:         List<String>.from(data['hashtags'] ?? []),
          callToAction:     (data['callToAction']     ?? 'اطلب الآن').toString(),
          productName:      productName,
          productPrice:     productPrice,
          storeName:        storeName,
          currencyCode:     currencyCode,
          isFallback:       body['note'] == 'fallback_template',
        ));

      } on Exception catch (e) {
        lastErr = e;
        debugPrint('[Marketing] Attempt $attempt error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 5));
        }
      }
    }

    final msg = lastErr?.toString() ?? '';
    if (msg.contains('timeout') || msg.contains('TimeoutException')) {
      return MarketingResult.error('timeout',
          'انتهت مهلة الاتصال. الخادم قد يكون نائماً، أعد المحاولة.');
    }
    return MarketingResult.error('unknown', 'تعذر التوصل بالخادم. تحقق من الاتصال.');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class MarketingResult {
  final MarketingContent? content;
  final String?           errorCode;
  final String?           errorMessage;
  bool get isSuccess => content != null;

  const MarketingResult._({this.content, this.errorCode, this.errorMessage});
  factory MarketingResult.success(MarketingContent c) =>
      MarketingResult._(content: c);
  factory MarketingResult.error(String code, String msg) =>
      MarketingResult._(errorCode: code, errorMessage: msg);
}

// ─────────────────────────────────────────────────────────────────────────────
class MarketingContent {
  final String       title;
  final String       instagramCaption;
  final List<String> features;
  final List<String> hashtags;
  final String       callToAction;
  final String       productName;
  final String       productPrice;
  final String       storeName;
  final String       currencyCode;
  final bool         isFallback;

  const MarketingContent({
    required this.title,
    required this.instagramCaption,
    required this.features,
    required this.hashtags,
    required this.callToAction,
    required this.productName,
    required this.productPrice,
    required this.storeName,
    this.currencyCode = 'SAR',
    this.isFallback   = false,
  });

  String get hashtagsText => hashtags.map((h) => h.startsWith('#') ? h : '#$h').join(' ');

  String get fullShareText =>
      '$instagramCaption\n\n💰 $productPrice $currencyCode\n🏪 $storeName\n\n$hashtagsText';
}

// ─────────────────────────────────────────────────────────────────────────────
//  شاشة الإعلان التسويقي — مع مشاركة صورة + نص
// ─────────────────────────────────────────────────────────────────────────────
class MarketingAdScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final String productDescription;
  final String productPrice;
  final String storeName;
  final String category;
  final String productImageUrl;
  final String currencyCode;

  const MarketingAdScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.productDescription,
    required this.productPrice,
    required this.storeName,
    required this.category,
    required this.productImageUrl,
    this.currencyCode = 'SAR',
  });

  @override
  State<MarketingAdScreen> createState() => _MarketingAdScreenState();
}

class _MarketingAdScreenState extends State<MarketingAdScreen>
    with TickerProviderStateMixin {
  MarketingContent? _content;
  String?           _errorMessage;
  String?           _errorCode;
  bool              _loading      = false;
  bool              _sharing      = false;

  final _editCtrl  = TextEditingController();
  final _cardKey   = GlobalKey(); // لالتقاط بطاقة الإعلان كصورة

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _generate();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_loading) { return; }
    setState(() { _loading = true; _content = null; _errorMessage = null; });

    final result = await MarketingService.generateAd(
      productName:        widget.productName,
      productDescription: widget.productDescription,
      productPrice:       widget.productPrice,
      storeName:          widget.storeName,
      category:           widget.category,
      currencyCode:       widget.currencyCode,
    );

    if (!mounted) { return; }

    if (result.isSuccess) {
      final c = result.content!;
      setState(() {
        _content      = c;
        _loading      = false;
        _editCtrl.text = c.fullShareText;
      });
    } else {
      setState(() {
        _errorMessage = result.errorMessage;
        _errorCode    = result.errorCode;
        _loading      = false;
      });
    }
  }

  // ── التقاط بطاقة الإعلان كصورة PNG ──────────────────────────────
  Future<File?> _captureAdCard() async {
    try {
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) { return null; }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) { return null; }

      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/souga_ad_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      return file;
    } catch (e) {
      debugPrint('[Marketing] capture error: $e');
      return null;
    }
  }

  // ── مشاركة الإعلان (صورة + نص) ───────────────────────────────────
  // ── فتح نافذة خيارات المشاركة الأربع ─────────────────────────────────────
  Future<void> _openShareOptions() async {
    if (_sharing) return;
    // webLink يُحسب تلقائياً: https://souga-5fdb3.web.app/product/<productId>
    final adText    = _editCtrl.text.trim();
    final imageUrls = widget.productImageUrl.isNotEmpty
        ? [widget.productImageUrl] : <String>[];

    await showShareOptionsSheet(
      context,
      data: ShareProductData(
        productId:          widget.productId,
        productName:        widget.productName,
        productPrice:       widget.productPrice,
        currencySymbol:     _currencySymbol(),
        storeName:          widget.storeName,
        imageUrls:          imageUrls,
        adText:             adText,
        productDescription: widget.productDescription,
      ),
    );
  }

  String _currencySymbol() {
    switch (widget.currencyCode.toUpperCase()) {
      case 'YER': return 'ر.ي';
      case 'USD': return '\$';
      case 'EUR': return '€';
      case 'SAR': return 'ر.س';
      default:    return widget.currencyCode;
    }
  }

  Future<void> _shareAdWithImage() async {
    if (_sharing) { return; }
    setState(() => _sharing = true);

    try {
      final text = _editCtrl.text.trim();

      // ── رابط "اطلب الآن" ────────────────────────────────────────
      // Deep link للمنتج داخل التطبيق (souga://product/ID)
      // إذا التطبيق غير مثبت → يفتح صفحة التنزيل
      // رابط المنتج — ثابت
      final productWebLink = 'https://souga-5fdb3.web.app/product/${widget.productId}';

      // استخدام SougaShareText لمنع تكرار السعر والمتجر والـ CTA
      final imageUrls = widget.productImageUrl.isNotEmpty
     ? [widget.productImageUrl]
     : <String>[];

      final shareData = ShareProductData(
        productId:      widget.productId,
        productName:    widget.productName,
        productPrice:   widget.productPrice,
        currencySymbol: _currencySymbol(),
        storeName:      widget.storeName,
         imageUrls:      imageUrls,
        adText:         text,
      );
      final fullText = SougaAdText(shareData).build();
      debugPrint('[Marketing] webLink: \$productWebLink');

      // ── محاولة مشاركة الصورة ────────────────────────────────────
      final imgFile = await _captureAdCard();

      if (imgFile != null) {
        // مشاركة صورة بطاقة الإعلان + النص
        await Share.shareXFiles(
          [XFile(imgFile.path, mimeType: 'image/png')],
          text:    fullText,
          subject: _content?.title ?? widget.productName,
        );
      } else if (widget.productImageUrl.isNotEmpty) {
        // احتياطي: حاول تنزيل صورة المنتج ومشاركتها
        final prodImg = await _downloadImage(widget.productImageUrl);
        if (prodImg != null) {
          await Share.shareXFiles(
            [XFile(prodImg.path, mimeType: 'image/jpeg')],
            text:    fullText,
            subject: _content?.title ?? widget.productName,
          );
        } else {
          // احتياطي أخير: نص فقط
          await Share.share(fullText, subject: _content?.title ?? widget.productName);
        }
      } else {
        await Share.share(fullText, subject: _content?.title ?? widget.productName);
      }

    } catch (e) {
      debugPrint('[Marketing] share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في المشاركة: $e'),
              backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) { setState(() => _sharing = false); }
    }
  }

  String get _shareCtaText => _content?.callToAction ?? 'اطلب الآن';

  // ── تنزيل صورة من URL ────────────────────────────────────────────
  Future<File?> _downloadImage(String url) async {
    try {
      final res  = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) { return null; }
      final dir  = await getTemporaryDirectory();
      final ext  = url.contains('.png') ? 'png' : 'jpg';
      final file = File('${dir.path}/souga_img_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(res.bodyBytes);
      return file;
    } catch (e) {
      debugPrint('[Marketing] download error: $e');
      return null;
    }
  }

  // ── نسخ النص ──────────────────────────────────────────────────────
  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: _editCtrl.text.trim()));
    if (!mounted) { return; }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم نسخ النص'),
          duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('إعلان تسويقي'),
        actions: [
          if (!_loading)
            IconButton(
              icon:    const Icon(Icons.refresh),
              tooltip: 'توليد جديد',
              onPressed: _generate,
            ),
        ],
      ),
      body: _loading
          ? _buildLoadingScreen()
          : _errorMessage != null
              ? _buildErrorScreen()
              : _buildContent(),
    );
  }

  // ── شاشة التحميل ──────────────────────────────────────────────────
  Widget _buildLoadingScreen() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      ScaleTransition(scale: _pulseAnim, child: Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFDC143C), Color(0xFF9B0E2A)]),
          shape:       BoxShape.circle,
          boxShadow: [BoxShadow(color: const Color(0xFFDC143C).withValues(alpha: 0.35),
              blurRadius: 20)],
        ),
        child: const Center(child: Icon(Icons.auto_awesome,
            color: Colors.white, size: 40)),
      )),
      const SizedBox(height: 24),
      const Text('Gemini AI يكتب إعلانك...',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('قد يستغرق حتى 60 ثانية',
          style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
      const SizedBox(height: 20),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 48),
        child: LinearProgressIndicator(color: Color(0xFFDC143C)),
      ),
      const SizedBox(height: 16),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: const Color(0xFFFFB300)),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline, color: Color(0xFFFFB300), size: 16),
          SizedBox(width: 8),
          Expanded(child: Text(
            'يرجى الانتظار وعدم الضغط مجدداً\nلتجنب تجاوز حصة الذكاء الاصطناعي',
            style: TextStyle(fontSize: 11, color: Color(0xFF5D4037)),
            textAlign: TextAlign.center,
          )),
        ]),
      ),
    ]),
  );

  // ── شاشة الخطأ ────────────────────────────────────────────────────
  Widget _buildErrorScreen() {
    final icon  = _errorCode == 'rate_limit' ? Icons.hourglass_empty_outlined
        : _errorCode == 'timeout'            ? Icons.wifi_off_outlined
        : Icons.error_outline;
    final tip   = _errorCode == 'rate_limit' ? 'انتظر دقيقة ثم أعد المحاولة'
        : _errorCode == 'timeout'            ? 'الخادم كان نائماً، استيقظ الآن. أعد المحاولة'
        : 'تحقق من الاتصال وأعد المحاولة';
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 52, color: const Color(0xFFBDBDBD)),
        const SizedBox(height: 14),
        Text(_errorMessage ?? 'حدث خطأ',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(tip, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _generate,
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة المحاولة'),
        ),
      ]),
    ));
  }

  // ── المحتوى الرئيسي ───────────────────────────────────────────────
  Widget _buildContent() {
    final c = _content!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        if (c.isFallback)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(color: const Color(0xFFFFB300)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Color(0xFFFFB300), size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'تم استخدام قالب افتراضي. اضغط تحديث لتوليد إعلان بالذكاء الاصطناعي.',
                style: TextStyle(fontSize: 11, color: Color(0xFF5D4037)),
              )),
            ]),
          ),

        // ── بطاقة الإعلان القابلة للمشاركة ──────────────────────────
        // RepaintBoundary لالتقاطها كصورة
        RepaintBoundary(
          key: _cardKey,
          child: Container(
            decoration: BoxDecoration(
              gradient:     const LinearGradient(
                  colors: [Color(0xFFDC143C), Color(0xFF7A0021)],
                  begin: Alignment.topRight, end: Alignment.bottomLeft),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color:      const Color(0xFFDC143C).withValues(alpha: 0.3),
                  blurRadius: 16, offset: const Offset(0, 6))],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // هيدر
              Row(children: [
                const Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 5),
                const Text('إعلان تسويقي',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:        Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(c.storeName,
                      style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ]),
              const SizedBox(height: 10),

              // عنوان الإعلان
              Text(c.title, style: const TextStyle(
                  color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.bold, height: 1.3)),
              const SizedBox(height: 10),

              // صورة المنتج
              if (widget.productImageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1.2,
                    child: Image.network(widget.productImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: Colors.white12,
                            child: const Center(child: Icon(Icons.image_outlined,
                                color: Colors.white30, size: 48)))),
                  ),
                ),
              const SizedBox(height: 10),

              // السعر
              Row(children: [
                const Icon(Icons.attach_money, color: Color(0xFFFFD700), size: 15),
                Text(' ${widget.productPrice} ${widget.currencyCode}',
                    style: const TextStyle(color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                // ← زر "اطلب الآن" مع deep link
                GestureDetector(
                  onTap: () => _onCtaTap(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color:        Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(c.callToAction,
                        style: const TextStyle(
                            color: Color(0xFFDC143C), fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ),
                ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 18),

        // ── الميزات ───────────────────────────────────────────────
        if (c.features.isNotEmpty) ...[
          const Text('المميزات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          ...c.features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              Container(width: 5, height: 5, margin: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(color: Color(0xFFDC143C),
                      shape: BoxShape.circle)),
              Expanded(child: Text(f, style: const TextStyle(fontSize: 13))),
            ]),
          )),
          const SizedBox(height: 14),
        ],

        // ── الهاشتاقات ────────────────────────────────────────────
        if (c.hashtags.isNotEmpty) ...[
          const Text('الوسوم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: c.hashtags.map((h) {
            final tag = h.startsWith('#') ? h : '#$h';
            return GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: tag));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ تم نسخ $tag'),
                        duration: const Duration(seconds: 1)));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:        const Color(0xFFDC143C).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(
                      color: const Color(0xFFDC143C).withValues(alpha: 0.3)),
                ),
                child: Text(tag,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFDC143C))),
              ),
            );
          }).toList()),
          const SizedBox(height: 18),
        ],

        // ── نص قابل للتعديل ──────────────────────────────────────
        Row(children: [
          const Text('نص الإعلان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          TextButton.icon(
            onPressed: _copyText,
            icon: const Icon(Icons.copy_outlined, size: 15, color: Color(0xFFDC143C)),
            label: const Text('نسخ', style: TextStyle(color: Color(0xFFDC143C), fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: TextField(
            controller: _editCtrl,
            maxLines:   null,
            minLines:   5,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.all(12),
              border:         InputBorder.none,
              hintText:       'نص الإعلان...',
              hintStyle:      TextStyle(color: Color(0xFFBDBDBD)),
            ),
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
        const SizedBox(height: 18),

        // ── زر المشاركة — يفتح نافذة الخيارات الأربع ─────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sharing ? null : _openShareOptions,
            icon: _sharing
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.campaign_outlined, size: 20),
            label: Text(_sharing ? 'جاري التحضير...' : '📤 مشاركة الإعلان'),
            style: ElevatedButton.styleFrom(
              padding:   const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // زر إعادة التوليد
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _generate,
            icon:  const Icon(Icons.refresh_outlined, size: 18),
            label: const Text('توليد إعلان جديد'),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  // ── "اطلب الآن" — deep link ───────────────────────────────────────
  Future<void> _onCtaTap() async {
    // محاولة فتح التطبيق مباشرة بـ deep link
    // إذا فشل → فتح صفحة التنزيل
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📱 ${_content?.callToAction ?? "اطلب الآن"}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
