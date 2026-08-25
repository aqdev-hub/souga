// lib/screens/customer/favorites_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/product_card.dart';
import 'product_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isGuest = user == null || user.uid == 'guest';
    final colors = context.colors;

    if (isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('المفضلة')),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.favorite_outline, size: 80, color: colors.border),
          const SizedBox(height: 16),
          Text('سجّل دخولك لحفظ منتجاتك المفضلة',
              style: TextStyle(color: colors.textSecondary, fontSize: 15)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            child: const Text('تسجيل الدخول'),
          ),
        ])),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: StreamBuilder<List<String>>(
        stream: context.read<FavoritesProvider>().favoritesStream(user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final productIds = snap.data ?? [];
          if (productIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 100, color: colors.border),
                  const SizedBox(height: 16),
                  Text('قائمة المفضلة فارغة',
                      style: TextStyle(fontSize: 18, color: colors.textSecondary)),
                  const SizedBox(height: 8),
                  Text('ابدأ بإضافة منتجات تعجبك ❤️',
                      style: TextStyle(color: colors.textHint)),
                ],
              ),
            );
          }

          return FutureBuilder<List<ProductModel>>(
            future: _loadProducts(productIds),
            builder: (context, prodSnap) {
              if (!prodSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final products = prodSnap.data!;
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: 0.72,
                  crossAxisSpacing: 10, mainAxisSpacing: 10,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) => ProductCard(
                  product: products[i], isGrid: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: products[i]))),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<ProductModel>> _loadProducts(List<String> ids) async {
    if (ids.isEmpty) return [];
    final snap = await FirebaseFirestore.instance
        .collection('products')
        .where(FieldPath.documentId, whereIn: ids.take(10).toList())
        .get();
    return snap.docs.map((d) => ProductModel.fromMap(d.data(), d.id)).toList();
  }
}
