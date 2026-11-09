// lib/widgets/product_sort_menu.dart
//
// فرز المنتجات — قائمة اختيار يغيّرها المستخدم بحرية، مشتركة بين قائمة منتجات
// البائع وإدارة المنتجات (المدير).

import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../utils/app_colors.dart';

enum ProductSort { newest, oldest, priceLow, priceHigh, nameAsc, stockLow, ratingHigh }

extension ProductSortX on ProductSort {
  String get label {
    switch (this) {
      case ProductSort.newest:     return 'الأحدث أولاً';
      case ProductSort.oldest:     return 'الأقدم أولاً';
      case ProductSort.priceLow:   return 'السعر: من الأقل';
      case ProductSort.priceHigh:  return 'السعر: من الأعلى';
      case ProductSort.nameAsc:    return 'الاسم (أ - ي)';
      case ProductSort.stockLow:   return 'الأقل كمية';
      case ProductSort.ratingHigh: return 'الأعلى تقييماً';
    }
  }

  IconData get icon {
    switch (this) {
      case ProductSort.newest:     return Icons.arrow_downward_rounded;
      case ProductSort.oldest:     return Icons.arrow_upward_rounded;
      case ProductSort.priceLow:   return Icons.trending_down_rounded;
      case ProductSort.priceHigh:  return Icons.trending_up_rounded;
      case ProductSort.nameAsc:    return Icons.sort_by_alpha_rounded;
      case ProductSort.stockLow:   return Icons.inventory_2_outlined;
      case ProductSort.ratingHigh: return Icons.star_outline_rounded;
    }
  }
}

List<ProductModel> sortProducts(List<ProductModel> src, ProductSort sort) {
  final list = List<ProductModel>.of(src);
  switch (sort) {
    case ProductSort.newest:     list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); break;
    case ProductSort.oldest:     list.sort((a, b) => a.createdAt.compareTo(b.createdAt)); break;
    case ProductSort.priceLow:   list.sort((a, b) => a.price.compareTo(b.price)); break;
    case ProductSort.priceHigh:  list.sort((a, b) => b.price.compareTo(a.price)); break;
    case ProductSort.nameAsc:    list.sort((a, b) => a.name.compareTo(b.name)); break;
    case ProductSort.stockLow:   list.sort((a, b) => a.stock.compareTo(b.stock)); break;
    case ProductSort.ratingHigh: list.sort((a, b) => b.rating.compareTo(a.rating)); break;
  }
  return list;
}

/// زر "فرز" بقائمة منسدلة.
class ProductSortButton extends StatelessWidget {
  final ProductSort sort;
  final ValueChanged<ProductSort> onChanged;
  const ProductSortButton({super.key, required this.sort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PopupMenuButton<ProductSort>(
      tooltip: 'فرز',
      initialValue: sort,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => ProductSort.values
          .map((s) => PopupMenuItem(
                value: s,
                child: Row(children: [
                  Icon(s.icon, size: 18, color: s == sort ? colors.primary : colors.textSecondary),
                  const SizedBox(width: 10),
                  Text(s.label,
                      style: TextStyle(
                        fontWeight: s == sort ? FontWeight.bold : FontWeight.normal,
                        color: s == sort ? colors.primary : null,
                      )),
                ]),
              ))
          .toList(),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sort_rounded, size: 20, color: colors.primary),
          const SizedBox(width: 4),
          Text('فرز', style: TextStyle(fontSize: 12.5, color: colors.textPrimary)),
        ]),
      ),
    );
  }
}
