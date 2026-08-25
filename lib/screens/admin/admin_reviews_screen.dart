// lib/screens/admin/admin_reviews_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/review_model.dart';
import '../../utils/app_colors.dart';

class AdminReviewsScreen extends StatelessWidget {
  const AdminReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة التقييمات')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.star_outline, size: 80, color: colors.border),
                const SizedBox(height: 16),
                Text('لا توجد تقييمات بعد',
                    style: TextStyle(fontSize: 16, color: colors.textSecondary)),
              ]),
            );
          }

          final reviews = snap.data!.docs
              .map((d) => ReviewModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();

          // إحصائيات سريعة
          final avg = reviews.isEmpty ? 0.0
              : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

          return Column(children: [
            // ملخص
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: colors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(child: Column(children: [
                  Text('${reviews.length}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Text('إجمالي التقييمات',
                      style: TextStyle(fontSize: 12, color: Colors.white70)),
                ])),
                Container(width: 1, height: 40, color: Colors.white30),
                Expanded(child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.star_rounded, color: colors.accent, size: 20),
                    const SizedBox(width: 4),
                    Text(avg.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  ]),
                  const Text('متوسط التقييمات',
                      style: TextStyle(fontSize: 12, color: Colors.white70)),
                ])),
              ]),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: reviews.length,
                itemBuilder: (_, i) => _ReviewAdminCard(review: reviews[i]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _ReviewAdminCard extends StatelessWidget {
  final ReviewModel review;
  const _ReviewAdminCard({required this.review});

  Future<void> _delete(BuildContext context) async {
    final colors = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف التقييم'),
        content: Text('حذف تقييم "${review.userName}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('حذف', style: TextStyle(color: colors.error))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('reviews').doc(review.id).delete();
      // إعادة حساب تقييم المنتج
      final snap = await FirebaseFirestore.instance
          .collection('reviews').where('productId', isEqualTo: review.productId).get();
      if (snap.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('products').doc(review.productId)
            .update({'rating': 0.0, 'reviewCount': 0});
      } else {
        final ratings = snap.docs.map((d) => (d.data()['rating'] as num).toDouble()).toList();
        final avg = ratings.reduce((a, b) => a + b) / ratings.length;
        await FirebaseFirestore.instance.collection('products').doc(review.productId)
            .update({'rating': double.parse(avg.toStringAsFixed(1)), 'reviewCount': snap.docs.length});
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('✅ تم حذف التقييم'), backgroundColor: colors.success));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 18, backgroundColor: colors.primary.withValues(alpha: 0.1),
              backgroundImage: review.userImage.isNotEmpty ? NetworkImage(review.userImage) : null,
              child: review.userImage.isEmpty
                  ? Text(review.userName.isNotEmpty ? review.userName[0] : 'م',
                      style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 13))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(review.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Row(children: List.generate(5, (i) => Icon(
                i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: colors.accent, size: 13,
              ))),
            ])),
            IconButton(
              icon: Icon(Icons.delete_outline, color: colors.error, size: 20),
              onPressed: () => _delete(context),
            ),
          ]),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment,
                style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.5)),
          ],
          const SizedBox(height: 4),
          Text('المنتج: ${review.productId.substring(0, 8)}...',
              style: TextStyle(fontSize: 11, color: colors.textHint)),
        ]),
      ),
    );
  }
}
