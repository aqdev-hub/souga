// lib/services/order_service.dart
//
// عمليات الطلبات المشتركة بين شاشات المشتري/البائع/المدير.
//
// • إلغاء المشتري لطلبه (تراجع عن الطلب) — مسموح بقواعد Firestore الحالية
//   (العميل يستطيع تحديث الطلب فقط إلى status == 'cancelled').
// • الحذف "من حسابي" (Soft delete): لا يُحذف المستند فعلياً، بل يُخفى من قوائم
//   صاحب الحساب فقط بعلامة hiddenForSeller / hiddenForAdmin — فيمكن التراجع
//   فوراً (SnackBar) أو لاحقاً من قائمة "المحذوفة"، ولا يتأثر المشتري أو الطرف
//   الآخر. لا يحتاج أي تعديل في قواعد Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import 'notifications_service.dart';

enum OrderOwnerRole { seller, admin }

class OrderService {
  static final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('orders');

  /// المشتري يستطيع الإلغاء فقط قبل الشحن.
  static bool canCustomerCancel(OrderModel o) =>
      o.status == OrderModel.pending || o.status == OrderModel.confirmed;

  static Future<void> cancelByCustomer(OrderModel o) async {
    await _col.doc(o.id).update({
      'status': OrderModel.cancelled,
      'cancelledBy': 'customer',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
    final first = o.products.isNotEmpty ? o.products.first : null;
    await NotificationsService.send(
      toUserId: o.sellerId,
      title: '❌ ألغى المشتري طلبه',
      body: '${o.customerName} ألغى طلب '
          '${first?.name ?? 'منتج'}${o.products.length > 1 ? ' وغيره' : ''} '
          '(#${o.id.substring(0, 8)})',
      type: 'order_status',
      referenceId: o.id,
      imageUrl: first?.image ?? '',
    );
  }

  static String _field(OrderOwnerRole r) =>
      r == OrderOwnerRole.seller ? 'hiddenForSeller' : 'hiddenForAdmin';

  static Future<void> hide(String orderId, OrderOwnerRole role) =>
      _col.doc(orderId).update({_field(role): true});

  static Future<void> restore(String orderId, OrderOwnerRole role) =>
      _col.doc(orderId).update({_field(role): false});
}
