// lib/repositories/product_repository.dart
//
// ✅ إضافي بالكامل في هذه المرحلة — لا شاشة حالية تستدعيه بعد. الشاشات
// الحالية (home_screen, search_screen, add_product_screen...) لا تزال
// تستدعي FirebaseFirestore.instance مباشرة كما هي تماماً، ولن تتأثر بهذا
// الملف إطلاقاً حتى تُربَط به صراحة في مرحلة لاحقة من خطة الهجرة.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductRepository {
  final FirebaseFirestore _fs;
  ProductRepository({FirebaseFirestore? firestore}) : _fs = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _fs.collection('products');

  Future<ProductModel?> fetchById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return ProductModel.fromMap(doc.data()!, doc.id);
  }

  Stream<ProductModel?> watchById(String id) {
    return _col.doc(id).snapshots().map(
          (doc) => (doc.exists && doc.data() != null) ? ProductModel.fromMap(doc.data()!, doc.id) : null,
        );
  }

  /// ✅ يدعم الفلترة بالفئة الجديدة (categoryId) — ولأن منتجات كثيرة قد لا
  /// تُهاجَر فوراً، الاستدعاء الأعلى (Repository المستخدِم) مسؤول عن
  /// الجمع بين نتائج categoryId والفئة القديمة المسطّحة عند الحاجة
  /// (Fallback)، وليس هذا المستودع — يبقى هذا الملف بسيطاً وواضح المسؤولية.
  Stream<List<ProductModel>> watchByCategoryId(String categoryId, {int? limit}) {
    Query<Map<String, dynamic>> q = _col.where('categoryId', isEqualTo: categoryId);
    q = q.orderBy('createdAt', descending: true);
    if (limit != null) q = q.limit(limit);
    return q.snapshots().map((s) => s.docs.map((d) => ProductModel.fromMap(d.data(), d.id)).toList());
  }

  Future<String> create(ProductModel product) async {
    final data = product.toMap();
    final docRef = await _col.add(data);
    return docRef.id;
  }

  Future<void> update(String id, Map<String, dynamic> patch) {
    return _col.doc(id).update(patch);
  }

  Future<void> delete(String id) {
    return _col.doc(id).delete();
  }
}
