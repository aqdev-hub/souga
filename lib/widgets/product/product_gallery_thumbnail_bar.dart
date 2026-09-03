// lib/widgets/product/product_gallery_thumbnail_bar.dart
//
// ✅ يعرض فقط controller.thumbnails (Hero + قيم المتغيرات) — لا يظهر أي
// صورة Item عامة هنا؛ صور Item يتم تصفّحها بالسحب داخل المعرض فقط.
// Widget عرض بحت بلا أي منطق قرار.

import 'package:flutter/material.dart';
import '../../controllers/product_gallery_controller.dart';
import '../../utils/app_colors.dart';

class ProductGalleryThumbnailBar extends StatelessWidget {
  final ProductGalleryController controller;
  const ProductGalleryThumbnailBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final thumbs = controller.thumbnails;
        if (thumbs.length <= 1) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 68,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: thumbs.length,
            itemBuilder: (context, index) => _ThumbnailTile(entry: thumbs[index]),
          ),
        );
      },
    );
  }
}

class _ThumbnailTile extends StatelessWidget {
  final ThumbnailEntry entry;
  const _ThumbnailTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderColor = entry.isActive ? colors.primary : colors.border;
    final borderWidth = entry.isActive ? 2.5 : 1.0;

    return Opacity(
      opacity: entry.isAvailable ? 1.0 : 0.35,
      child: GestureDetector(
        onTap: entry.onTap,
        child: Container(
          width: 56, height: 56,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: entry.imageUrl != null
                ? Image.network(
                    entry.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(colors),
                  )
                : _fallback(colors),
          ),
        ),
      ),
    );
  }

  Widget _fallback(SougaColors colors) {
    if (entry.hex != null) {
      return Container(color: _parseHex(entry.hex!));
    }
    if (entry.label != null) {
      return Container(
        color: colors.surface,
        alignment: Alignment.center,
        child: Text(entry.label!, style: TextStyle(fontSize: 10, color: colors.textPrimary)),
      );
    }
    return Container(color: colors.border, child: Icon(Icons.image_outlined, size: 20, color: colors.textHint));
  }

  Color _parseHex(String hex) {
    final clean = hex.replaceAll('#', '');
    final value = int.tryParse('FF$clean', radix: 16);
    return value != null ? Color(value) : Colors.grey;
  }
}
