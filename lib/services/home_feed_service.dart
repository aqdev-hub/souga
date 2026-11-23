// lib/services/home_feed_service.dart
//
// تغذية الشاشة الرئيسية بطلب واحد مُخزَّن مؤقتاً بدل 5 مستمعين حيّين (snapshots):
//   • قراءة واحدة (get) لأحدث 80 منتجاً في التصنيف ثم اشتقاق الأقسام محلياً:
//     الأحدث / الأعلى تقييماً / الأكثر تقييماً (شعبية) / عروض اليوم
//   • كاش في الذاكرة 3 دقائق لكل تصنيف + منع تكرار الطلب الجاري
//   • لا يحتاج فهارس Firestore مركّبة إضافية (ترتيب createdAt فقط)
// الحداثة: سحب للتحديث (force) أو انتهاء المدة.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';

class HomeFeed {
  final List<ProductModel> newest;
  final List<ProductModel> topRated;
  final List<ProductModel> popular;
  final List<ProductModel> deals;
  const HomeFeed({
    required this.newest, required this.topRated,
    required this.popular, required this.deals,
  });
  bool get isEmpty => newest.isEmpty;
}

class _Entry {
  final DateTime at;
  final Future<HomeFeed> future;
  _Entry(this.at, this.future);
}

class HomeFeedService {
  HomeFeedService._();

  static const int _fetchSize = 80;
  static const Duration _ttl = Duration(minutes: 3);
  static final Map<String, _Entry> _cache = {};

  static Future<HomeFeed> load(String category, {bool force = false}) {
    final hit = _cache[category];
    if (!force && hit != null && DateTime.now().difference(hit.at) < _ttl) {
      return hit.future;
    }
    final f = _fetch(category);
    _cache[category] = _Entry(DateTime.now(), f);
    // فشل الطلب لا يُخزَّن (تُعاد المحاولة في الطلب التالي)
    f.catchError((_) { _cache.remove(category); return const HomeFeed(newest: [], topRated: [], popular: [], deals: []); });
    return f;
  }

  static void invalidate() => _cache.clear();

  static Future<HomeFeed> _fetch(String category) async {
    Query q = FirebaseFirestore.instance.collection('products');
    if (category.isNotEmpty) q = q.where('category', isEqualTo: category);
    final snap = await q.orderBy('createdAt', descending: true).limit(_fetchSize).get();
    final all = snap.docs
        .map((d) => ProductModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();

    final top = all.where((p) => p.rating > 0).toList()
      ..sort((a, b) {
        final c = b.rating.compareTo(a.rating);
        return c != 0 ? c : b.reviewCount.compareTo(a.reviewCount);
      });
    final pop = all.where((p) => p.reviewCount > 0).toList()
      ..sort((a, b) => b.reviewCount.compareTo(a.reviewCount));

    return HomeFeed(
      newest:   all.take(10).toList(),
      topRated: top.take(8).toList(),
      popular:  pop.take(8).toList(),
      deals:    all.where((p) => p.hasDiscount).take(10).toList(),
    );
  }
}
