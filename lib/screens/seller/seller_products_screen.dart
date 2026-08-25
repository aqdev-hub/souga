// lib/screens/seller/seller_products_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/imagekit_service.dart';
import '../../services/marketing_service.dart';
import '../../services/seo_rebuild_service.dart';
import '../../utils/app_colors.dart';
import 'add_product_screen.dart';

// ── أسماء التصنيفات بالعربية — تُستخدم فقط لبناء سياق إعلان الذكاء الاصطناعي ──
const List<Map<String, String>> _kSellerProductCategories = [
  {'id': 'electronics', 'name': 'إلكترونيات'},
  {'id': 'clothes',     'name': 'ملابس'},
  {'id': 'food',        'name': 'طعام'},
  {'id': 'home',        'name': 'منزل'},
  {'id': 'sports',      'name': 'رياضة'},
  {'id': 'books',       'name': 'كتب'},
  {'id': 'other',       'name': 'أخرى'},
  {'id': 'perfumes',    'name': 'عطور'},
  {'id': 'accessories', 'name': 'اكسسوارات'},
];

String _categoryDisplayName(String id) {
  final match = _kSellerProductCategories.firstWhere(
    (c) => c['id'] == id,
    orElse: () => {'id': id, 'name': id},
  );
  return match['name'] ?? id;
}

class SellerProductsScreen extends StatelessWidget {
  const SellerProductsScreen({super.key});

  Future<void> _deleteProduct(BuildContext context, String productId) async {
    final colors = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: const Text('هل أنت متأكد من حذف هذا المنتج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('حذف', style: TextStyle(color: colors.error))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('products').doc(productId).delete();
      // ✅ إعادة بناء صفحات SEO الثابتة في الخلفية بعد الحذف — بدون انتظار
      // المستخدم (وإلا ستبقى صفحة SEO للمنتج المحذوف متاحة على Hosting).
      unawaited(SeoRebuildService.triggerRebuild(reason: 'product_deleted:$productId'));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('تم حذف المنتج'), backgroundColor: colors.success),
        );
      }
    }
  }

  // ── فتح شاشة الإعلان التسويقي بالذكاء الاصطناعي لمنتج منشور بالفعل ──────────
  void _openMarketingAd(BuildContext context, ProductModel p) {
    final user = context.read<AuthProvider>().currentUser;
    final storeName = (user?.storeName.isNotEmpty ?? false)
        ? user!.storeName
        : (user?.name.isNotEmpty ?? false)
            ? user!.name
            : p.sellerName;

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MarketingAdScreen(
        productId:          p.id,
        productName:        p.name,
        productDescription: p.description,
        productPrice:       p.price.toStringAsFixed(2),
        storeName:          storeName,
        category:           _categoryDisplayName(p.category),
        productImageUrl:    p.firstImage.isNotEmpty
            ? ImageKitService.productUrl(p.firstImage) : '',
        currencyCode:       p.currencyCode,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('منتجاتي')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('sellerId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inventory_2_outlined, size: 100, color: colors.border),
                const SizedBox(height: 16),
                Text('لا توجد منتجات بعد',
                    style: TextStyle(fontSize: 18, color: colors.textSecondary)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddProductScreen())),
                  icon: const Icon(Icons.add),
                  label: const Text('أضف أول منتج'),
                ),
              ]),
            );
          }

          final products = snapshot.data!.docs
              .map((d) => ProductModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: products.length,
            itemBuilder: (_, i) {
              final p = products[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: p.firstImage.isNotEmpty
                        ? Image.network(p.firstImage,
                            width: 60, height: 60, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                width: 60, height: 60, color: colors.border,
                                child: const Icon(Icons.image_outlined)))
                        : Container(
                            width: 60, height: 60, color: colors.border,
                            child: Icon(Icons.image_outlined, color: colors.textHint)),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p.price.toStringAsFixed(2)} ر.س',
                        style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
                    Text('الكمية: ${p.stock}',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                  ]),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.auto_awesome, color: Color(0xFFE1306C)),
                      tooltip: 'إعلان تسويقي بالذكاء الاصطناعي',
                      onPressed: () => _openMarketingAd(context, p),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: colors.primary),
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => AddProductScreen(product: p))),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: colors.error),
                      onPressed: () => _deleteProduct(context, p.id),
                    ),
                  ]),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddProductScreen())),
        backgroundColor: colors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة منتج', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
