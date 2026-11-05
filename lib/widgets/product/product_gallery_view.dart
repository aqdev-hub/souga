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
  Widget build(BuildContext context) {
    final colors = context.colors;
    // ✅ الصورة تظهر كاملة بنسبتها الأصلية دون قص أو تشويه (contain)،
    // وخلفها نسخة مموّهة من الصورة نفسها تملأ المساحة الفارغة بدل شريط فارغ.
    return Stack(fit: StackFit.expand, children: [
      ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: CachedNetworkImage(
          imageUrl: item.url,
          fit: BoxFit.cover,
          memCacheWidth: 200,
          placeholder: (_, __) => Container(color: colors.border),
          errorWidget: (_, __, ___) => Container(color: colors.border),
        ),
      ),
      Container(color: Colors.black.withValues(alpha: 0.12)),
      CachedNetworkImage(
        imageUrl: item.url,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: 1080,
        placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) => Center(
          child: Icon(Icons.image_outlined, size: 64, color: colors.textHint),
        ),
      ),
    ]);
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

String? _youtubeThumbnail(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  String? id;
  if (host.endsWith('youtu.be')) {
    id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  } else if (host.endsWith('youtube.com')) {
    id = uri.queryParameters['v'] ??
        (uri.pathSegments.length >= 2 && (uri.pathSegments.first == 'shorts' || uri.pathSegments.first == 'embed')
            ? uri.pathSegments[1]
            : null);
  }
  if (id == null || id.isEmpty) return null;
  return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
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
    final colors = context.colors;
    final controller = _videoController;

    if (_hasError) {
      // ✅ بدل أيقونة ميتة: بطاقة قابلة للضغط تفتح الفيديو في تطبيقه/المتصفح.
      final thumb = _youtubeThumbnail(widget.item.url);
      return GestureDetector(
        onTap: () => launchUrl(Uri.parse(widget.item.url), mode: LaunchMode.externalApplication),
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
                child: const Text('اضغط لمشاهدة الفيديو',
                    style: TextStyle(color: Colors.white, fontSize: 12.5)),
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
