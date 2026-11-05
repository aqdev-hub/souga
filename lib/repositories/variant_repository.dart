// lib/repositories/variant_repository.dart
//
// ✅ يحتوي "SKU Generator" كدالة نقية (generateCombinations) — تم التحقق
// من صحتها الرياضية بمعزل عن Flutter قبل كتابتها هنا (حالات: خاصية واحدة،
// خاصيتان، ثلاث خصائص، صفر خصائص) — راجع سجل الجلسة. الدالة لا تعتمد على
// Firestore إطلاقاً، فهي قابلة للاختبار بـ Unit Test مباشر لاحقاً.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_variant_model.dart';

class VariantRepository {
  final FirebaseFirestore _fs;
  VariantRepository({FirebaseFirestore? firestore}) : _fs = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String productId) =>
      _fs.collection('products').doc(productId).collection('variants');

  /// ✅ SKU Generator — توليد كل التركيبات الممكنة (Cartesian Product) من
  /// خيارات عدة خصائص متغيّرة دفعة واحدة.
  ///
  /// مثال: {'color': ['red','blue'], 'size': ['s','xl']}
  /// يُعيد: [{'color':'red','size':'s'}, {'color':'red','size':'xl'},
  ///         {'color':'blue','size':'s'}, {'color':'blue','size':'xl'}]
  ///
  /// يعمل صحيحاً مع أي عدد من الخصائص (1، 2، 3...)، ويُعيد قائمة فارغة
  /// إن لم توجد أي خاصية متغيّرة (منتج بسيط بلا Variants) — لا يُفترض
  /// وجود لون أو مقاس أبداً.
  static List<Map<String, String>> generateCombinations(
    Map<String, List<String>> optionsByKey,
  ) {
    final keys = optionsByKey.keys.toList();
    if (keys.isEmpty) return [];

    List<Map<String, String>> result = [<String, String>{}];
    for (final key in keys) {
      final values = optionsByKey[key]!;
      final newResult = <Map<String, String>>[];
      for (final combo in result) {
        for (final value in values) {
          newResult.add({...combo, key: value});
        }
      }
      result = newResult;
    }
    return result;
  }

  /// بناء SKU نصي قابل للقراءة من معرّف المنتج + قيم التركيبة، بترتيب
  /// ثابت (حسب ترتيب variantKeys) حتى يكون كل SKU فريداً ومتوقَّعاً.
  static String buildSku(String productId, List<String> variantKeys, Map<String, String> optionValues) {
    final shortProductId = productId.length > 6 ? productId.substring(0, 6) : productId;
    final parts = variantKeys.map((k) => (optionValues[k] ?? '').toUpperCase()).join('-');
    return '$shortProductId-$parts'.toUpperCase();
  }

  Future<List<ProductVariantModel>> fetchAll(String productId) async {
    final snap = await _col(productId).get();
    return snap.docs.map((d) => ProductVariantModel.fromMap(d.data(), d.id)).toList();
  }

  Stream<List<ProductVariantModel>> watchAll(String productId) {
    return _col(productId).snapshots().map(
          (snap) => snap.docs.map((d) => ProductVariantModel.fromMap(d.data(), d.id)).toList(),
        );
  }

  Future<void> upsert(String productId, ProductVariantModel variant) {
    return _col(productId).doc(variant.id).set(variant.toMap(), SetOptions(merge: true));
  }

  /// ✅ يكتب كل التركيبات المولَّدة دفعة واحدة (Batch) بدل استدعاء منفصل
  /// لكل تركيبة — أداء أفضل عند نشر منتج بعشرات التركيبات، وذرّية أعلى.
  Future<void> upsertBatch(String productId, List<ProductVariantModel> variants) async {
    final batch = _fs.batch();
    for (final v in variants) {
      batch.set(_col(productId).doc(v.id), v.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> delete(String productId, String variantId) {
    return _col(productId).doc(variantId).delete();
  }
}
