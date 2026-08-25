// lib/providers/favorites_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritesProvider extends ChangeNotifier {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // مفاتيح Firestore
  // المفضلة: favorites/{uid}_{productId}
  // الإعجابات: likes/{uid}_{productId}

  String _favDocId(String uid, String productId) => '${uid}__$productId';

  // ─── المفضلة ──────────────────────────────────────────

  /// هل المنتج في المفضلة؟
  Stream<bool> isFavoriteStream(String uid, String productId) {
    if (uid == 'guest') return Stream.value(false);
    return _fs
        .collection('favorites')
        .doc(_favDocId(uid, productId))
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// جلب كل المنتجات المفضلة للمستخدم
  Stream<List<String>> favoritesStream(String uid) {
    if (uid == 'guest') return Stream.value([]);
    return _fs
        .collection('favorites')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()['productId'] as String).toList());
  }

  /// تبديل حالة المفضلة (إضافة/حذف)
  Future<void> toggleFavorite({
    required String uid,
    required String productId,
    required String productName,
    required String productImage,
  }) async {
    if (uid == 'guest') return;
    final docRef = _fs.collection('favorites').doc(_favDocId(uid, productId));
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set({
        'userId': uid,
        'productId': productId,
        'productName': productName,
        'productImage': productImage,
        'createdAt': DateTime.now(),
      });
    }
    notifyListeners();
  }

  // ─── الإعجابات ────────────────────────────────────────

  /// عدد الإعجابات لمنتج معين
  Stream<int> likesCountStream(String productId) {
    return _fs
        .collection('likes')
        .where('productId', isEqualTo: productId)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// هل المستخدم أعجب بهذا المنتج؟
  Stream<bool> isLikedStream(String uid, String productId) {
    if (uid == 'guest') return Stream.value(false);
    return _fs
        .collection('likes')
        .doc(_favDocId(uid, productId))
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// تبديل الإعجاب
  Future<void> toggleLike({required String uid, required String productId}) async {
    if (uid == 'guest') return;
    final docRef = _fs.collection('likes').doc(_favDocId(uid, productId));
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set({
        'userId': uid,
        'productId': productId,
        'createdAt': DateTime.now(),
      });
    }
    notifyListeners();
  }
}
