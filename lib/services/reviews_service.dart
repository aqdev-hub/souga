// lib/services/reviews_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

class ReviewsService {
  static final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// جلب تقييمات منتج معين
  static Stream<List<ReviewModel>> getProductReviews(String productId) {
    return _fs
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ReviewModel.fromMap(d.data(), d.id)).toList());
  }

  /// هل المستخدم قيّم هذا المنتج من قبل؟
  static Future<ReviewModel?> getUserReview(String productId, String userId) async {
    final snap = await _fs
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return ReviewModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  /// إضافة أو تعديل تقييم
  /// يُعيد رسالة النجاح أو الفشل
  static Future<String> submitReview({
    required String productId,
    required String userId,
    required String userName,
    required String userImage,
    required double rating,
    required String comment,
  }) async {
    try {
      // تحقق هل يوجد تقييم سابق
      final existing = await getUserReview(productId, userId);

      if (existing != null) {
        // تعديل التقييم القائم
        await _fs.collection('reviews').doc(existing.id).update({
          'rating': rating,
          'comment': comment,
          'createdAt': DateTime.now(),
        });
      } else {
        // إضافة تقييم جديد
        final review = ReviewModel(
          id: '',
          productId: productId,
          userId: userId,
          userName: userName,
          userImage: userImage,
          rating: rating,
          comment: comment,
          createdAt: DateTime.now(),
        );
        await _fs.collection('reviews').add(review.toMap());
      }

      // إعادة حساب متوسط التقييم وتحديثه في المنتج
      await _recalculateProductRating(productId);

      return 'success';
    } catch (e) {
      return 'error: $e';
    }
  }

  /// حذف تقييم
  static Future<void> deleteReview(String reviewId, String productId) async {
    await _fs.collection('reviews').doc(reviewId).delete();
    await _recalculateProductRating(productId);
  }

  /// إعادة حساب متوسط التقييم للمنتج
  static Future<void> _recalculateProductRating(String productId) async {
    final snap = await _fs
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .get();

    if (snap.docs.isEmpty) {
      await _fs.collection('products').doc(productId).update({'rating': 0.0, 'reviewCount': 0});
      return;
    }

    final ratings = snap.docs.map((d) => (d.data()['rating'] as num).toDouble()).toList();
    final avg = ratings.reduce((a, b) => a + b) / ratings.length;
    final rounded = double.parse(avg.toStringAsFixed(1));

    await _fs.collection('products').doc(productId).update({
      'rating': rounded,
      'reviewCount': snap.docs.length,
    });
  }
}
