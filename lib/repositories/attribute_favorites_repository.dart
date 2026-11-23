// lib/repositories/attribute_favorites_repository.dart
//
// ✅ مفضلات البائع (خصائص وألوان) حسب الفئة الرئيسية. خاصة بكل بائع، لا تُضاف
// تلقائياً لأي منتج، ولا تتكرر (معرّف حتمي) — الحفظ مرة ثانية يحدّث القيم فقط.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attribute_favorite.dart';

class AttributeFavoritesRepository {
  final FirebaseFirestore _fs;
  AttributeFavoritesRepository({FirebaseFirestore? firestore}) : _fs = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _fs.collection('users').doc(uid).collection('attributeFavorites');

  /// مفضلات الفئة الرئيسية المحددة فقط (استعلام واحد مفلتر، بلا ترتيب مركّب).
  Future<List<AttributeFavorite>> fetchForRoot(String uid, String rootCategoryId) async {
    final snap = await _col(uid).where('rootCategoryId', isEqualTo: rootCategoryId).get();
    final list = snap.docs.map((d) => AttributeFavorite.fromMap(d.data(), d.id)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// يحفظ/يحدّث (merge بحسب المعرّف الحتمي) — لا ينشئ نسخة مكررة أبداً.
  Future<void> save(String uid, AttributeFavorite fav) async {
    await _col(uid).doc(fav.id).set({
      ...fav.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String uid, String id) => _col(uid).doc(id).delete();
}
