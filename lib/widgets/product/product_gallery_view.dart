// lib/widgets/product/product_gallery_view.dart
//
// ✅ Widget عرض بحت، بلا أي منطق قرار داخله. كل ما يفعله: يرسم الصفحة
// الحالية حسب نوعها (فيديو/صورة) ويُبلّغ الـ Controller بالتمرير عبر
// pageController المُدار بالكامل هناك.
//
// ✅ Performance: الفيديو يُهيَّأ (Lazy Initialization) فقط عند وصول
// صفحته لتصبح مرئية فعلياً، ويُوقَف تلقائياً عند مغادرتها.

import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../controllers/product_gallery_controller.dart';
import '../../models/gallery_item_model.dart';
import '../../utils/app_colors.dart';

class ProductGalleryView extends StatelessWidget {
  final ProductGalleryController controller;
  final double height;

  const ProductGalleryView({super.key, required this.controller, this.height = 380});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gallery = controller.gallery;

    if (gallery.isEmpty) {
      return Container(
        height: height,
        color: colors.border,
        child: Center(child: Icon(Icons.image_outlined, size: 64, color: colors.textHint)),
      );
    }

    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return PageView.builder(
            controller: controller.pageController,
            itemCount: gallery.length,
            itemBuilder: (context, index) {
              final item = gallery[index];
              if (item.isVideo) {
                return _GalleryVideoItem(item: item, isActive: controller.currentPage == index);
              }
              return _GalleryImageItem(item: item);
            },
          );
        },
      ),
    );
  }
}

class _GalleryImageItem extends StatelessWidget {
  final GalleryItemModel item;
  const _GalleryImageItem({required this.item});

  @override
  Widget build(BuildContext context) => ProductImageFrame(url: item.url);
}

/// ✅ إطار عرض صورة المنتج الموحَّد — المرجع الوحيد لطريقة عرض الصور في التطبيق
/// (المعرض، بطاقات المنتجات، المصغّرات، السلة، قوائم البائع/الأدمن).
///
/// القواعد (لا استثناء):
///  • الصورة كاملة بنسبتها الأصلية: BoxFit.contain — بلا قص ولا تمديد.
///  • موسَّطة أفقياً وعمودياً داخل مساحة ثابتة يحدّدها المستدعي، فكل المنتجات
///    تظهر بالحجم نفسه مهما اختلفت أبعاد صورها.
///  • الفراغات حول الصورة (عند اختلاف النسبة) تُملأ بنسخة مموّهة من الصورة نفسها
///    فلا تظهر مساحات فارغة؛ وفي المربعات الصغيرة جداً بلون هادئ بدل التمويه.
///  • لا BoxFit.cover لصورة المنتج نفسها. (cover يُستخدم فقط للخلفية المموّهة
///    التي لا يراها أحد كصورة، وهي مقصوصة عمداً لتغطي الفراغ.)
class ProductImageFrame extends StatelessWidget {
  final String url;
  /// null في الاتجاهين = يملأ المساحة المتاحة من الأب.
  final double? width;
  final double? height;
  /// خلفية مموّهة من الصورة نفسها (للمعرض والبطاقات) أو لون هادئ (للمربعات الصغيرة).
  final bool blurBackdrop;
  final double blurSigma;
  final int memCacheWidth;
  /// ما يُعرض عند الفشل/عدم وجود صورة (الافتراضي: أيقونة صورة).
  final Widget? fallback;

  const ProductImageFrame({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.blurBackdrop = true,
    this.blurSigma = 24,
    this.memCacheWidth = 1080,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final soft = colors.border.withValues(alpha: 0.45);
    final bad = fallback ??
        Center(child: Icon(Icons.image_outlined, size: 40, color: colors.textHint));

    final frame = RepaintBoundary(
      child: ClipRect(
        child: Stack(fit: StackFit.expand, children: [
          if (blurBackdrop) ...[
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma, tileMode: TileMode.clamp),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover, // خلفية فقط — انظر التوثيق أعلاه
                memCacheWidth: 120,
                placeholder: (_, __) => ColoredBox(color: soft),
                errorWidget: (_, __, ___) => ColoredBox(color: soft),
              ),
            ),
            ColoredBox(color: Colors.black.withValues(alpha: 0.10)),
          ] else
            ColoredBox(color: soft),
          CachedNetworkImage(
            imageUrl: url,
            // ✅ ضروري: بدون width/height صريحين يمرّر CachedNetworkImage قيوداً
            // "مرخاة" لـ Image فيعرضها بحجمها الأصلي ولا يكبّرها لتملأ المساحة
            // (فتتّسع الخلفية المموّهة). infinity هنا = تُقيَّد بحجم الإطار
            // فتتكبّر الصورة بنسبتها (contain) حتى تلامس أحد الضلعين.
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            memCacheWidth: memCacheWidth,
            placeholder: (_, __) => const Center(
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, __, ___) => bad,
          ),
        ]),
      ),
    );

    if (width == null && height == null) return frame;
    return SizedBox(width: width, height: height, child: frame);
  }
}

/// روابط منصات (يوتيوب/تيك توك/إنستغرام/فيسبوك/فيميو...) هي صفحات ويب وليست
/// ملف فيديو مباشراً، فلا يستطيع المشغّل الداخلي تشغيلها — تُفتح خارجياً.
bool _isPlatformVideoLink(String url) {
  final host = (Uri.tryParse(url)?.host ?? '').toLowerCase();
  const hosts = [
    'youtube.com', 'youtu.be', 'tiktok.com', 'instagram.com', 'facebook.com',
    'fb.watch', 'vimeo.com', 'snapchat.com', 'twitter.com', 'x.com',
    'drive.google.com', 'dropbox.com',
  ];
  return hosts.any((h) => host == h || host.endsWith('.$h'));
}

String? _youtubeId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  final segs = uri.pathSegments;
  String? id;
  if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
    id = segs.isNotEmpty ? segs.first : null;
  } else if (host == 'youtube.com' || host.endsWith('.youtube.com')) {
    id = uri.queryParameters['v'] ??
        (segs.length >= 2 && const ['shorts', 'embed', 'live'].contains(segs.first) ? segs[1] : null);
  }
  if (id == null || !RegExp(r'^[A-Za-z0-9_-]{6,20}$').hasMatch(id)) return null;
  return id;
}

String? _youtubeThumbnail(String url) {
  final id = _youtubeId(url);
  return id == null ? null : 'https://img.youtube.com/vi/$id/hqdefault.jpg';
}

/// رابط تضمين للتشغيل داخل الصفحة (يوتيوب/فيميو فقط)، وإلا null فيُفتح خارجياً.
String? _embedUrlFor(String url) {
  final yt = _youtubeId(url);
  if (yt != null) {
    return 'https://www.youtube.com/embed/$yt?autoplay=1&playsinline=1&rel=0&modestbranding=1';
  }
  final uri = Uri.tryParse(url);
  final host = (uri?.host ?? '').toLowerCase();
  if (uri != null && (host == 'vimeo.com' || host.endsWith('.vimeo.com'))) {
    final id = uri.pathSegments.where((p) => RegExp(r'^\d+$').hasMatch(p)).firstOrNull;
    if (id != null) return 'https://player.vimeo.com/video/$id?autoplay=1';
  }
  return null;
}

/// رابط آمن للتشغيل: https بدل http (أندرويد يمنع http الصريح افتراضياً).
String _normalizeVideoUrl(String raw) {
  var u = raw.trim();
  if (u.startsWith('http://')) u = 'https://${u.substring(7)}';
  return u;
}

class _GalleryVideoItem extends StatefulWidget {
  final GalleryItemModel item;
  final bool isActive;
  const _GalleryVideoItem({required this.item, required this.isActive});

  @override
  State<_GalleryVideoItem> createState() => _GalleryVideoItemState();
}

class _GalleryVideoItemState extends State<_GalleryVideoItem> {
  VideoPlayerController? _videoController;
  bool _initializing = false;
  bool _hasError = false;
  bool _playingEmbed = false; // يوتيوب/فيميو: لا نُنشئ WebView إلا بعد الضغط على التشغيل

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _initializeIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _GalleryVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _initializeIfNeeded();
      _videoController?.play();
    } else if (!widget.isActive && oldWidget.isActive) {
      _videoController?.pause();
      // مغادرة الصفحة تُغلق مشغّل التضمين فيتوقف الصوت ويُحرَّر الـ WebView.
      if (_playingEmbed) setState(() => _playingEmbed = false);
    }
  }

  Future<void> _initializeIfNeeded() async {
    if (_videoController != null || _initializing) return;
    // رابط منصة (يوتيوب...) ليس ملف فيديو: لا فائدة من محاولة التشغيل الداخلي.
    if (_isPlatformVideoLink(widget.item.url)) {
      if (mounted) setState(() => _hasError = true);
      return;
    }
    _initializing = true;
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(_normalizeVideoUrl(widget.item.url)));
      await controller.initialize();
      controller.setLooping(true);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _videoController = controller);
      if (widget.isActive) controller.play();
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      _initializing = false;
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;

    if (_hasError) {
      // ✅ بدل أيقونة ميتة: بطاقة قابلة للضغط تفتح الفيديو في تطبيقه/المتصفح.
      final thumb = _youtubeThumbnail(widget.item.url);
      final embedUrl = _embedUrlFor(widget.item.url);
      if (embedUrl != null && _playingEmbed) {
        return _EmbeddedVideoPlayer(embedUrl: embedUrl, originalUrl: widget.item.url);
      }
      return GestureDetector(
        onTap: () {
          if (embedUrl != null) {
            setState(() => _playingEmbed = true);
          } else {
            launchUrl(Uri.parse(widget.item.url), mode: LaunchMode.externalApplication);
          }
        },
        child: Stack(fit: StackFit.expand, children: [
          Container(color: Colors.black87),
          if (thumb != null)
            Opacity(
              opacity: 0.7,
              child: CachedNetworkImage(
                imageUrl: thumb, fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text(embedUrl != null ? 'اضغط لتشغيل الفيديو' : 'اضغط لمشاهدة الفيديو',
                    style: const TextStyle(color: Colors.white, fontSize: 12.5)),
              ),
            ]),
          ),
        ]),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black87,
        child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      );
    }

    return GestureDetector(
      onTap: () => setState(() {
        controller.value.isPlaying ? controller.pause() : controller.play();
      }),
      child: Stack(alignment: Alignment.center, fit: StackFit.expand, children: [
        const ColoredBox(color: Colors.black),
        FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        AnimatedOpacity(
          opacity: controller.value.isPlaying ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 60, height: 60,
            decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
          ),
        ),
      ]),
    );
  }
}


// ── مشغّل تضمين (يوتيوب/فيميو) داخل الصفحة عبر WebView ──────────────────────
// يُنشأ فقط بعد ضغط المستخدم على التشغيل (Lazy) فلا يكلّف شيئاً عند فتح المنتج،
// ويُحرَّر فور مغادرة الصفحة. المشغّل بنسبة 16:9 في الوسط وحوله أشرطة سوداء
// حتى يبقى السحب بين صور المعرض ممكناً من أعلى الصفحة وأسفلها.
class _EmbeddedVideoPlayer extends StatefulWidget {
  final String embedUrl;
  final String originalUrl;
  const _EmbeddedVideoPlayer({required this.embedUrl, required this.originalUrl});

  @override
  State<_EmbeddedVideoPlayer> createState() => _EmbeddedVideoPlayerState();
}

class _EmbeddedVideoPlayerState extends State<_EmbeddedVideoPlayer> {
  late final WebViewController _web;
  bool _loading = true;

  static const _allowedHosts = [
    'youtube.com', 'youtube-nocookie.com', 'youtu.be', 'vimeo.com', 'vimeocdn.com',
    'google.com', 'gstatic.com', 'googlevideo.com', 'ytimg.com', 'doubleclick.net',
  ];

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        // لا نسمح للمشغّل بالانتقال لصفحات غريبة داخل التطبيق.
        onNavigationRequest: (req) {
          if (req.url == 'about:blank') return NavigationDecision.navigate;
          final host = (Uri.tryParse(req.url)?.host ?? '').toLowerCase();
          final ok = _allowedHosts.any((h) => host == h || host.endsWith('.$h'));
          return ok ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
      ))
      ..loadRequest(
        Uri.parse(widget.embedUrl),
        headers: const {'Referer': 'https://souga-5fdb3.web.app/'},
      );
  }

  @override
  void dispose() {
    // إيقاف التشغيل/الصوت فوراً قبل تحرير الـ WebView.
    try {
      _web.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Colors.black),
      Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(children: [
            WebViewWidget(controller: _web),
            if (_loading)
              const ColoredBox(
                color: Colors.black,
                child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              ),
          ]),
        ),
      ),
      // مخرج دائم: بعض الفيديوهات يمنع صاحبها تضمينها، فيفتحها المشتري خارجياً.
      Positioned(
        bottom: 36, left: 0, right: 0,
        child: Center(
          child: GestureDetector(
            onTap: () => launchUrl(Uri.parse(widget.originalUrl), mode: LaunchMode.externalApplication),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.open_in_new, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text('فتح خارج التطبيق', style: TextStyle(color: Colors.white, fontSize: 11.5)),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}
