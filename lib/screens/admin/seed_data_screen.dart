// lib/screens/admin/seed_data_screen.dart
// شاشة مخصصة للأدمن لإضافة منتجات تجريبية

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_colors.dart';

class SeedDataScreen extends StatefulWidget {
  const SeedDataScreen({super.key});
  @override
  State<SeedDataScreen> createState() => _SeedDataScreenState();
}

class _SeedDataScreenState extends State<SeedDataScreen> {
  bool _isLoading = false;
  String _status = '';

  final List<Map<String, dynamic>> _sampleProducts = [
    // إلكترونيات
    {'name': 'سماعات بلوتوث لاسلكية', 'description': 'سماعات بلوتوث 5.0 عالية الجودة مع إلغاء الضوضاء، بطارية تدوم 30 ساعة', 'price': 249.0, 'stock': 15, 'category': 'electronics', 'rating': 4.5, 'images': ['https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400']},
    {'name': 'ساعة ذكية رياضية', 'description': 'ساعة ذكية مع مراقبة معدل ضربات القلب وتتبع النشاط البدني', 'price': 399.0, 'stock': 8, 'category': 'electronics', 'rating': 4.2, 'images': ['https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400']},
    {'name': 'شاحن لاسلكي سريع', 'description': 'شاحن لاسلكي 15W يدعم جميع الأجهزة الحديثة', 'price': 89.0, 'stock': 25, 'category': 'electronics', 'rating': 4.0, 'images': ['https://images.unsplash.com/photo-1585771724684-38269d6639fd?w=400']},
    {'name': 'لوحة مفاتيح ميكانيكية', 'description': 'لوحة مفاتيح ميكانيكية RGB للألعاب والبرمجة', 'price': 320.0, 'stock': 5, 'category': 'electronics', 'rating': 4.7, 'images': ['https://images.unsplash.com/photo-1618384887929-16ec33fab9ef?w=400']},

    // ملابس
    {'name': 'جاكيت كاجوال رجالي', 'description': 'جاكيت أنيق خفيف الوزن مناسب للإطلالات اليومية', 'price': 185.0, 'stock': 12, 'category': 'clothes', 'rating': 4.3, 'images': ['https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=400']},
    {'name': 'فستان صيفي نسائي', 'description': 'فستان خفيف ومريح بألوان زاهية مناسب للصيف', 'price': 145.0, 'stock': 20, 'category': 'clothes', 'rating': 4.6, 'images': ['https://images.unsplash.com/photo-1572804013309-59a88b7e92f1?w=400']},
    {'name': 'حذاء رياضي', 'description': 'حذاء رياضي مريح مناسب للجري واللياقة البدنية', 'price': 220.0, 'stock': 10, 'category': 'clothes', 'rating': 4.4, 'images': ['https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400']},

    // طعام
    {'name': 'عسل طبيعي أصيل', 'description': 'عسل طبيعي 100% من المناحل المحلية، غني بالفيتامينات والمعادن', 'price': 75.0, 'stock': 30, 'category': 'food', 'rating': 4.8, 'images': ['https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=400']},
    {'name': 'تمر مجدول فاخر', 'description': 'تمر مجدول طازج من أجود الأصناف، مثالي للهدايا', 'price': 95.0, 'stock': 50, 'category': 'food', 'rating': 4.9, 'images': ['https://images.unsplash.com/photo-1559181567-c3190bfbf93b?w=400']},
    {'name': 'زيت زيتون بكر', 'description': 'زيت زيتون بكر ممتاز معصور على البارد من مزارع محلية', 'price': 55.0, 'stock': 40, 'category': 'food', 'rating': 4.6, 'images': ['https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400']},

    // منزل
    {'name': 'طقم إبريق وكاسات', 'description': 'طقم شاي فاخر من السيراميك الفاخر مع 6 كاسات', 'price': 160.0, 'stock': 7, 'category': 'home', 'rating': 4.5, 'images': ['https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=400']},
    {'name': 'مصباح طاولة ذكي', 'description': 'مصباح ذكي LED قابل للتعتيم مع تحكم عن طريق التطبيق', 'price': 120.0, 'stock': 15, 'category': 'home', 'rating': 4.2, 'images': ['https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400']},
    {'name': 'وسادة مريحة للنوم', 'description': 'وسادة طبية من الإسفنج عالي الجودة لنوم مريح', 'price': 110.0, 'stock': 18, 'category': 'home', 'rating': 4.4, 'images': ['https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=400']},

    // رياضة
    {'name': 'حبل قفز احترافي', 'description': 'حبل قفز سرعة احترافي مناسب للتدريب الرياضي المكثف', 'price': 45.0, 'stock': 35, 'category': 'sports', 'rating': 4.3, 'images': ['https://images.unsplash.com/photo-1434596922112-19c563067271?w=400']},
    {'name': 'قفازات لياقة بدنية', 'description': 'قفازات رياضية مريحة لحماية اليدين أثناء التمرين', 'price': 65.0, 'stock': 22, 'category': 'sports', 'rating': 4.1, 'images': ['https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400']},
    {'name': 'كرة قدم احترافية', 'description': 'كرة قدم احترافية مقاس 5 معتمدة للملاعب الرسمية', 'price': 130.0, 'stock': 10, 'category': 'sports', 'rating': 4.6, 'images': ['https://images.unsplash.com/photo-1552318965-6e6be7484ada?w=400']},

    // كتب
    {'name': 'كتاب: فن اللامبالاة', 'description': 'كتاب ملهم يغير طريقة تفكيرك في الحياة والنجاح', 'price': 45.0, 'stock': 25, 'category': 'books', 'rating': 4.7, 'images': ['https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=400']},
    {'name': 'كتاب: العادات الذرية', 'description': 'دليل عملي لبناء عادات صحية وكسر العادات السيئة', 'price': 55.0, 'stock': 20, 'category': 'books', 'rating': 4.9, 'images': ['https://images.unsplash.com/photo-1589998059171-988d887df646?w=400']},
    {'name': 'مجموعة روايات عربية', 'description': 'مجموعة من أجمل الروايات العربية الحديثة في مجلد واحد', 'price': 85.0, 'stock': 12, 'category': 'books', 'rating': 4.5, 'images': ['https://images.unsplash.com/photo-1512820790803-83ca734da794?w=400']},
  ];

  Future<void> _seedData() async {
    setState(() { _isLoading = true; _status = 'جاري إضافة المنتجات التجريبية...'; });

    try {
      // أولاً: تحقق من وجود بائع تجريبي أو استخدم ID ثابت
      const String demoSellerId = 'demo_seller_001';
      const String demoSellerName = 'متجر سوجا التجريبي';

      // تحقق هل المنتجات موجودة مسبقاً
      final existing = await FirebaseFirestore.instance.collection('products')
          .where('sellerId', isEqualTo: demoSellerId).limit(1).get();

      if (existing.docs.isNotEmpty) {
        setState(() { _isLoading = false; _status = '⚠️ المنتجات التجريبية موجودة بالفعل!'; });
        return;
      }

      int count = 0;
      for (final product in _sampleProducts) {
        await FirebaseFirestore.instance.collection('products').add({
          ...product,
          'sellerId': demoSellerId,
          'sellerName': demoSellerName,
          'createdAt': DateTime.now().subtract(Duration(days: count)), // تواريخ مختلفة
        });
        count++;
        setState(() => _status = 'تم إضافة $count/${_sampleProducts.length} منتج...');
      }

      setState(() { _isLoading = false; _status = '✅ تم إضافة ${_sampleProducts.length} منتج تجريبي بنجاح!'; });
    } catch (e) {
      setState(() { _isLoading = false; _status = '❌ خطأ: $e'; });
    }
  }

  Future<void> _clearSeedData() async {
    setState(() { _isLoading = true; _status = 'جاري حذف المنتجات التجريبية...'; });
    try {
      const String demoSellerId = 'demo_seller_001';
      final snap = await FirebaseFirestore.instance.collection('products')
          .where('sellerId', isEqualTo: demoSellerId).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
      setState(() { _isLoading = false; _status = '✅ تم حذف ${snap.docs.length} منتج تجريبي'; });
    } catch (e) {
      setState(() { _isLoading = false; _status = '❌ خطأ: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('البيانات التجريبية')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.dataset_outlined, size: 80, color: colors.primary),
          const SizedBox(height: 24),
          const Text('إدارة البيانات التجريبية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${_sampleProducts.length} منتج تجريبي في 6 تصنيفات', style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 32),
          if (_status.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _seedData,
            icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.add_circle_outline),
            label: const Text('إضافة المنتجات التجريبية'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _clearSeedData,
            icon: const Icon(Icons.delete_outline),
            label: const Text('حذف المنتجات التجريبية'),
            style: OutlinedButton.styleFrom(foregroundColor: colors.error, side: BorderSide(color: colors.error)),
          ),
        ]),
      ),
    );
  }
}
