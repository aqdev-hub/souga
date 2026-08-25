// lib/widgets/product_card.dart
//
// ✅ إعادة تصميم كاملة (v2) — مستوحاة من مرجع تصميمي حديث لكن بهوية سوجا:
//   - شارة خصم % + السعر قبل الخصم مشطوباً (إن وُجد خصم فعلي على المنتج).
//   - زر "أضف للسلة" دائري بارز أسفل يمين البطاقة.
//   - تقييم + عدد المراجعات، اسم البائع كبديل إن لم يوجد تقييم بعد.
//   - حواف وظلال أنعم، ودعم كامل للوضع الفاتح/الداكن عبر context.colors.
//   - لا تغيير في التوقيع الخارجي (نفس المعاملات) — Drop-in replacement
//     لا يتطلب أي تعديل في الشاشات التي تستخدمه بالفعل.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/favorites_provider.dart';
import '../services/imagekit_service.dart';
import '../utils/app_colors.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final bool isGrid;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.isGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final imgHeight = isGrid ? 130.0 : 112.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isGrid ? null : 168,
        margin: isGrid ? null : const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: _buildImage(context, isGrid ? double.infinity : 168, imgHeight),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: colors.textPrimary, height: 1.25)),
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${product.price.toStringAsFixed(0)} ${product.currencySymbol}',
                        style: TextStyle(fontSize: isGrid ? 15 : 14,
                            fontWeight: FontWeight.bold, color: colors.primary)),
                    if (product.hasDiscount) ...[
                      const SizedBox(width: 6),
                      Text(product.originalPrice!.toStringAsFixed(0),
                          style: TextStyle(fontSize: 11, color: colors.textHint,
                              decoration: TextDecoration.lineThrough)),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (product.rating > 0) ...[
                      Icon(Icons.star_rounded, size: 13, color: colors.accent),
                      const SizedBox(width: 2),
                      Text(product.rating.toStringAsFixed(1),
                          style: TextStyle(fontSize: 11, color: colors.textSecondary,
                              fontWeight: FontWeight.w600)),
                      if (product.reviewCount > 0) ...[
                        const SizedBox(width: 2),
                        Text('(${product.reviewCount})',
                            style: TextStyle(fontSize: 10, color: colors.textHint)),
                      ],
                    ] else
                      Expanded(
                        child: Text(product.sellerName, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: colors.textSecondary)),
                      ),
                  ]),
                ],
              ),
            ),
          ]),

          // شارة الخصم (أعلى يمين — RTL: يمين الصورة)
          if (product.hasDiscount)
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('-${product.discountPercent}%',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),

          // زر المفضلة
          Positioned(top: 6, left: 6, child: _FavoriteButton(product: product)),

          // زر إضافة سريعة للسلة — أسفل يسار الصورة
          Positioned(
            bottom: imgHeight + 6, left: 6,
            child: _QuickAddButton(product: product),
          ),
        ]),
      ),
    );
  }

  Widget _buildImage(BuildContext context, double width, double height) {
    final colors = context.colors;
    if (product.firstImage.isNotEmpty) {
      final url = ImageKitService.productUrl(product.firstImage);
      return CachedNetworkImage(
        imageUrl: url, width: width, height: height, fit: BoxFit.cover,
        memCacheWidth: 320,
        placeholder: (_, __) => Container(width: width, height: height, color: colors.border,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
        errorWidget: (_, __, ___) => _placeholder(colors, width, height),
      );
    }
    return _placeholder(colors, width, height);
  }

  Widget _placeholder(SougaColors colors, double width, double height) {
    return Container(width: width, height: height, color: colors.border,
        child: Icon(Icons.image_outlined, size: 36, color: colors.textHint));
  }
}

// ─── زر المفضلة المصغّر ────────────────────────────────────
class _FavoriteButton extends StatelessWidget {
  final ProductModel product;
  const _FavoriteButton({required this.product});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final uid = user?.uid ?? 'guest';
    if (uid == 'guest') return const SizedBox();

    return StreamBuilder<bool>(
      stream: context.watch<FavoritesProvider>().isFavoriteStream(uid, product.id),
      builder: (_, snap) {
        final isFav = snap.data ?? false;
        return GestureDetector(
          onTap: () => context.read<FavoritesProvider>().toggleFavorite(
            uid: uid, productId: product.id,
            productName: product.name, productImage: product.firstImage,
          ),
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
            ),
            child: Icon(isFav ? Icons.favorite : Icons.favorite_outline,
                size: 16, color: isFav ? Colors.red : context.colors.textSecondary),
          ),
        );
      },
    );
  }
}

// ─── زر إضافة سريعة للسلة ────────────────────────────────────
class _QuickAddButton extends StatelessWidget {
  final ProductModel product;
  const _QuickAddButton({required this.product});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final inCart = context.watch<CartProvider>().isInCart(product.id);
    if (product.stock <= 0) return const SizedBox();

    return GestureDetector(
      onTap: () {
        final cart = context.read<CartProvider>();
        final user = context.read<AuthProvider>().currentUser;
        if (user == null || user.uid == 'guest') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('سجّل الدخول لإضافة منتجات للسلة'),
            backgroundColor: colors.warning,
          ));
          return;
        }
        cart.addItem(product);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ أُضيف للسلة'),
          backgroundColor: colors.success,
          duration: const Duration(milliseconds: 900),
        ));
      },
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: inCart ? colors.success : colors.primary,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Icon(inCart ? Icons.check_rounded : Icons.add_shopping_cart_rounded,
            color: Colors.white, size: 16),
      ),
    );
  }
}
