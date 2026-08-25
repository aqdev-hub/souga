// lib/services/notifications_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationsService {
  static final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // ─── إرسال إشعار ────────────────────────────────────
  static Future<void> send({
    required String toUserId,
    required String title,
    required String body,
    required String type,
    String referenceId = '',
  }) async {
    try {
      await _fs.collection('notifications').add({
        'userId': toUserId,
        'title': title,
        'body': body,
        'type': type,
        'referenceId': referenceId,
        'isRead': false,
        'createdAt': DateTime.now(),
      });
    } catch (_) {}
  }

  // ─── إشعار طلب جديد للبائع ──────────────────────────
  static Future<void> notifyNewOrder({
    required String sellerId,
    required String customerName,
    required String orderId,
    required double amount,
  }) async {
    await send(
      toUserId: sellerId,
      title: '🛒 طلب جديد!',
      body: 'قام $customerName بطلب بقيمة ${amount.toStringAsFixed(2)} ر.س',
      type: 'new_order',
      referenceId: orderId,
    );
  }

  // ─── إشعار تحديث حالة الطلب للمشتري ────────────────
  static Future<void> notifyOrderStatus({
    required String customerId,
    required String orderId,
    required String newStatus,
  }) async {
    final statusLabels = {
      'confirmed': 'تم تأكيد طلبك ✅',
      'shipped': 'طلبك في الطريق 🚚',
      'delivered': 'تم توصيل طلبك 🎉',
      'cancelled': 'تم إلغاء طلبك ❌',
    };
    final label = statusLabels[newStatus] ?? 'تم تحديث حالة طلبك';
    await send(
      toUserId: customerId,
      title: label,
      body: 'رقم الطلب: ${orderId.substring(0, 8)}...',
      type: 'order_status',
      referenceId: orderId,
    );
  }

  // ─── جلب إشعارات مستخدم ─────────────────────────────
  static Stream<List<NotificationModel>> getUserNotifications(String uid) {
    if (uid == 'guest') return Stream.value([]);
    return _fs
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs
            .map((d) => NotificationModel.fromMap(d.data(), d.id))
            .toList());
  }

  // ─── عدد الإشعارات غير المقروءة ─────────────────────
  static Stream<int> getUnreadCount(String uid) {
    if (uid == 'guest') return Stream.value(0);
    return _fs
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // ─── تعيين كمقروء ────────────────────────────────────
  static Future<void> markAsRead(String notificationId) async {
    await _fs.collection('notifications').doc(notificationId)
        .update({'isRead': true});
  }

  // ─── تعيين كل الإشعارات كمقروءة ─────────────────────
  static Future<void> markAllAsRead(String uid) async {
    final snap = await _fs.collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _fs.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ─── حذف إشعار ───────────────────────────────────────
  static Future<void> delete(String notificationId) async {
    await _fs.collection('notifications').doc(notificationId).delete();
  }
}
