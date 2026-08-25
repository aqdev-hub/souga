// lib/widgets/product/product_gallery_view.dart
//
// ✅ المرحلة 4 (جزء أول) — Widget عرض بحت، بلا أي منطق قرار داخله. كل ما
// يفعله: يرسم الصفحة الحالية حسب نوعها (فيديو/صورة) ويُبلّغ الـ Controller
// بالتمرير عبر pageController المُدار بالكامل هناك.
//
// ✅ Performance: الفيديو يُهيَّأ (Lazy Initialization) فقط عند وصول
// صفحته لتصبح مرئية فعلياً، ويُوقَف تلقائياً عند مغادرتها — لا يُهيَّأ كل
// الفيديوهات دفعة واحدة عند فتح الشاشة.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
                return _GalleryVideoItem(
                  item: item,
                  isActive: controller.currentPage == index,
                );
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
    return CachedNetworkImage(
      imageUrl: item.url,
      fit: BoxFit.cover,
      width: double.infinity,
      memCacheWidth: 1080,
      placeholder: (_, __) => Container(
        color: colors.border,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, __, ___) => Container(
        color: colors.border,
        child: Icon(Icons.image_outlined, size: 64, color: colors.textHint),
      ),
    );
  }
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
    _initializing = true;
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.item.url));
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
      return Container(
        color: colors.border,
        child: Center(child: Icon(Icons.videocam_off_outlined, size: 48, color: colors.textHint)),
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
        FittedBox(
          fit: BoxFit.cover,
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
