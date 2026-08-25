// lib/screens/seller/seller_orders_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../screens/shared/chat_screen.dart';
import '../../services/chat_service.dart';
import '../../services/notifications_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';

class SellerOrdersScreen extends StatelessWidget {
  final String? filterStatus;
  const SellerOrdersScreen({super.key, this.filterStatus});

  Color _statusColor(SougaColors colors, String s) {
    switch (s) {
      case 'pending': return colors.warning;
      case 'confirmed': return colors.info;
      case 'shipped': return colors.primary;
      case 'delivered': return colors.success;
      case 'cancelled': return colors.error;
      default: return colors.textSecondary;
    }
  }

  String _statusArabic(String s) {
    switch (s) {
      case 'pending': return 'انتظار';
      case 'confirmed': return 'مؤكد';
      case 'shipped': return 'تم الشحن';
      case 'delivered': return 'تم التوصيل';
      case 'cancelled': return 'ملغي';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(filterStatus != null ? 'طلبات: ${_statusArabic(filterStatus!)}' : 'الطلبات'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: (() {
          Query q = FirebaseFirestore.instance.collection('orders')
              .where('sellerId', isEqualTo: user.uid);
          if (filterStatus != null && filterStatus!.isNotEmpty) {
            q = q.where('status', isEqualTo: filterStatus);
          }
          return q.orderBy('createdAt', descending: true).snapshots();
        })(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.receipt_long_outlined, size: 80, color: colors.border),
              const SizedBox(height: 16),
              Text(filterStatus != null ? 'لا توجد طلبات بهذه الحالة' : 'لا توجد طلبات بعد',
                  style: TextStyle(fontSize: 16, color: colors.textSecondary)),
            ]));
          }

          final orders = snapshot.data!.docs
              .map((d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (_, i) => _OrderCard(
              order: orders[i],
              statusColor: (s) => _statusColor(colors, s),
              statusArabic: _statusArabic,
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final Color Function(String) statusColor;
  final String Function(String) statusArabic;

  const _OrderCard({
    required this.order,
    required this.statusColor,
    required this.statusArabic,
  });

  Future<void> _openBuyerLocation(String latLng) async {
    if (latLng.isEmpty) return;
    final clean = latLng.replaceAll(' ', '');
    final lat   = clean.split(',')[0];
    final lng   = clean.contains(',') ? clean.split(',')[1] : '';
    final gmaps = Uri.parse('https://maps.google.com/?q=$clean');
    if (await canLaunchUrl(gmaps)) {
      await launchUrl(gmaps, mode: LaunchMode.externalApplication);
    } else {
      final osm = Uri.parse(
          'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=15/$lat/$lng');
      await launchUrl(osm, mode: LaunchMode.externalApplication);
    }
  }

    Future<void> _updateStatus(BuildContext context, String newStatus) async {
    final colors = context.colors;
    try {
      await FirebaseFirestore.instance.collection('orders').doc(order.id)
          .update({'status': newStatus});

      // إرسال إشعار للمشتري
      await NotificationsService.notifyOrderStatus(
        customerId: order.customerId,
        orderId: order.id,
        newStatus: newStatus,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ تم تحديث الحالة إلى: ${statusArabic(newStatus)}'),
          backgroundColor: colors.success,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ خطأ: $e'), backgroundColor: colors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = statusColor(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('طلب #${order.id.substring(0, 8)}',
                style: const TextStyle(fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(statusArabic(order.status),
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.person_outlined, size: 14, color: colors.textSecondary),
            const SizedBox(width: 4),
            Text(order.customerName,
                style: TextStyle(color: colors.textSecondary, fontSize: 13)),
            const SizedBox(width: 12),
            Icon(Icons.phone_outlined, size: 14, color: colors.textSecondary),
            const SizedBox(width: 4),
            Text(order.customerPhone,
                style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          ]),
          const SizedBox(height: 6),
          ...order.products.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('• ${p.name} × ${p.quantity}',
                style: TextStyle(fontSize: 13, color: colors.textSecondary)),
          )),
          const SizedBox(height: 8),
          if (order.shippingAddress.address.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.location_on_outlined, size: 14, color: colors.textSecondary),
              const SizedBox(width: 4),
              Expanded(child: Text(order.shippingAddress.address,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary))),
              // ✅ زر الخريطة — يظهر فقط إذا حدّد المشتري موقعه
              if (order.shippingAddress.locationLatLng.isNotEmpty)
                InkWell(
                  onTap: () => _openBuyerLocation(order.shippingAddress.locationLatLng),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.map_rounded, size: 13, color: colors.primary),
                      const SizedBox(width: 3),
                      Text('خريطة', style: TextStyle(fontSize: 11, color: colors.primary)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Text('${order.totalAmount.toStringAsFixed(2)} ${order.currencySymbol}',
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary, fontSize: 16)),
            const Spacer(),
            // تواصل مع المشتري
            GestureDetector(
              onTap: () async {
                final user = context.read<AuthProvider>().currentUser;
                if (user == null) return;
                final roomId = await ChatService.getOrCreateRoom(
                  myUid:      user.uid,
                  myName:     user.storeName.isNotEmpty ? user.storeName : user.name,
                  myImage:    user.storeLogo.isNotEmpty ? user.storeLogo : user.profileImage,
                  otherUid:   order.customerId,
                  otherName:  order.customerName,
                  otherImage: '',
                );
                if (!context.mounted) return;
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    roomId: roomId,
                    otherName: order.customerName,
                    otherImage: '',
                  ),
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.accent),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chat_bubble_outline, size: 12, color: colors.accent),
                  const SizedBox(width: 4),
                  Text('تواصل', style: TextStyle(color: colors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            // تغيير الحالة
            if (order.status == 'pending')
              _actionButton(context, 'تأكيد', colors.info, () => _updateStatus(context, 'confirmed')),
            if (order.status == 'confirmed')
              _actionButton(context, 'شحن', colors.primary, () => _updateStatus(context, 'shipped')),
            if (order.status == 'shipped')
              _actionButton(context, 'تم التوصيل', colors.success, () => _updateStatus(context, 'delivered')),
            if (order.status != 'delivered' && order.status != 'cancelled')
              const SizedBox(width: 8),
            if (order.status != 'delivered' && order.status != 'cancelled')
              _actionButton(context, 'إلغاء', colors.error, () => _updateStatus(context, 'cancelled')),
          ]),
        ]),
      ),
    );
  }

  Widget _actionButton(BuildContext context, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
