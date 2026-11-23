// lib/services/notification_router.dart
//
// يوجّه النقر على أي إشعار (Push أو من شاشة الإشعارات) إلى المحتوى المقصود:
//   new_product / productId → صفحة المنتج
//   new_order / order_status → شاشة الطلبات حسب دور المستخدم (مشتري/بائع/مشرف)
//   chat → المحادثة نفسها
//   غير ذلك → شاشة الإشعارات
//
// ينتظر جاهزية الـ Navigator ثم يعمل فوق الشاشة الحالية.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../providers/auth_provider.dart';
import '../screens/admin/admin_payments_screen.dart';
import '../screens/customer/orders_screen.dart';
import '../screens/seller/seller_orders_screen.dart';
import '../screens/shared/chat_screen.dart';
import '../screens/shared/notifications_screen.dart';
import 'deep_link_service.dart';

class NotificationRouter {
  NotificationRouter._();

  /// نقطة الدخول الوحيدة. آمنة الاستدعاء قبل جاهزية الواجهة.
  static void open({
    required String type,
    String referenceId = '',
    String productId = '',
    int attempt = 0,
  }) {
    final nav = DeepLinkService.navigatorKey.currentState;
    final ctx = DeepLinkService.navigatorKey.currentContext;
    if (nav == null || ctx == null) {
      if (attempt >= 40) return; // ~12 ثانية
      Future.delayed(const Duration(milliseconds: 300), () => open(
          type: type, referenceId: referenceId, productId: productId, attempt: attempt + 1));
      return;
    }
    unawaited(_go(nav, ctx, type, referenceId, productId));
  }

  static Future<void> _go(NavigatorState nav, BuildContext ctx, String type,
      String referenceId, String productId) async {
    try {
      final pid = productId.isNotEmpty
          ? productId
          : (type == 'new_product' ? referenceId : '');
      if (pid.isNotEmpty) {
        DeepLinkService.openProductByIdWhenReady(pid);
        return;
      }

      final user = ctx.read<AuthProvider>().currentUser;
      if (user == null) return;

      switch (type) {
        case 'new_order':
        case 'order_status':
          if (user.isAdmin) {
            nav.push(MaterialPageRoute(builder: (_) => const AdminPaymentsScreen()));
          } else if (user.isSeller) {
            nav.push(MaterialPageRoute(builder: (_) => const SellerOrdersScreen()));
          } else {
            nav.push(MaterialPageRoute(builder: (_) => const OrdersScreen()));
          }
          return;

        case 'chat':
          if (referenceId.isEmpty) break;
          final doc = await FirebaseFirestore.instance
              .collection('chat_rooms').doc(referenceId).get();
          if (!doc.exists || doc.data() == null) break;
          final room = ChatRoom.fromMap(doc.data()!, doc.id);
          nav.push(MaterialPageRoute(
            builder: (_) => ChatScreen(
              roomId: room.id,
              otherName: room.otherName(user.uid),
              otherImage: room.otherImage(user.uid),
            ),
          ));
          return;
      }
      nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    } catch (e) {
      debugPrint('[NotifRouter] error: $e');
    }
  }
}
