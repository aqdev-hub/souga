// lib/screens/seller/seller_orders_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../screens/shared/chat_screen.dart';
import '../../services/chat_service.dart';
import '../../services/notifications_service.dart';
import '../../services/order_service.dart';
import '../../widgets/order_list_tools.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';

class SellerOrdersScreen extends StatefulWidget {
  final String? filterStatus;
  const SellerOrdersScreen({super.key, this.filterStatus});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  String _query = '';
  OrderSort _sort = OrderSort.newest;
  bool _showDeleted = false; // عرض الطلبات التي حذفتُها من حسابي (للاستعادة)

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
    final filterStatus = widget.filterStatus;

    return Scaffold(
      appBar: AppBar(
        title: Text(_showDeleted
            ? 'الطلبات المحذوفة'
            : (filterStatus != null ? 'طلبات: ${_statusArabic(filterStatus)}' : 'الطلبات')),
        actions: [
          IconButton(
            tooltip: _showDeleted ? 'العودة للطلبات' : 'الطلبات المحذوفة',
            icon: Icon(_showDeleted ? Icons.receipt_long_outlined : Icons.delete_sweep_outlined),
            onPressed: () => setState(() => _showDeleted = !_showDeleted),
          ),
        ],
      ),
      body: Column(children: [
        OrderToolbar(
          sort: _sort,
          onQueryChanged: (v) => setState(() => _query = v),
          onSortChanged: (s) => setState(() => _sort = s),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: (() {
              Query q = FirebaseFirestore.instance.collection('orders')
                  .where('sellerId', isEqualTo: user.uid);
              if (filterStatus != null && filterStatus.isNotEmpty) {
                q = q.where('status', isEqualTo: filterStatus);
              }
              return q.orderBy('createdAt', descending: true).snapshots();
            })(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = (snapshot.data?.docs ?? [])
                  .map((d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                  .where((o) => o.hiddenForSeller == _showDeleted)
                  .toList();
              if (all.isEmpty) {
                return orderEmptyState(context,
                    searching: false,
                    emptyText: _showDeleted
                        ? 'لا توجد طلبات محذوفة'
                        : (filterStatus != null ? 'لا توجد طلبات بهذه الحالة' : 'لا توجد طلبات بعد'));
              }
              final orders = applyOrderQuery(all, query: _query, sort: _sort);
              if (orders.isEmpty) {
                return orderEmptyState(context, searching: true, emptyText: '');
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: orders.length,
                itemBuilder: (_, i) => _OrderCard(
                  order: orders[i],
                  inTrash: _showDeleted,
                  statusColor: (s) => _statusColor(colors, s),
                  statusArabic: _statusArabic,
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final Color Function(String) statusColor;
  final String Function(String) statusArabic;
  final bool inTrash;

  const _OrderCard({
    required this.order,
    required this.statusColor,
    required this.statusArabic,
    this.inTrash = false,
  });

  /// حذف من حسابي مع تراجع فوري (SnackBar) أو لاحقاً من "المحذوفة".
  Future<void> _hideOrRestore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (inTrash) {
        await OrderService.restore(order.id, OrderOwnerRole.seller);
        messenger.showSnackBar(const SnackBar(content: Text('تمت استعادة الطلب')));
      } else {
        await OrderService.hide(order.id, OrderOwnerRole.seller);
        if (context.mounted) {
          showUndoSnack(context, 'تم حذف الطلب من حسابك',
              () => OrderService.restore(order.id, OrderOwnerRole.seller));
        }
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('تعذّر تنفيذ العملية: $e')));
    }
  }

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

      await NotificationsService.notifyOrderStatus(
        customerId: order.customerId,
        orderId: order.id,
        newStatus: newStatus,
        productName: order.products.isNotEmpty ? order.products.first.name : '',
        imageUrl: order.products.isNotEmpty ? order.products.first.image : '',
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
            PopupMenuButton<String>(
              tooltip: 'خيارات',
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_vert, size: 20, color: colors.textSecondary),
              onSelected: (_) => _hideOrRestore(context),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'x',
                  child: Row(children: [
                    Icon(inTrash ? Icons.restore_from_trash_outlined : Icons.delete_outline,
                        size: 18, color: inTrash ? colors.success : colors.error),
                    const SizedBox(width: 8),
                    Text(inTrash ? 'استعادة الطلب' : 'حذف من حسابي'),
                  ]),
                ),
              ],
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
          // ✅ صورة مصغّرة + اسم كل منتج + خيارات التركيبة (Snapshot وقت الطلب)
          // لتجهيز التركيبة الصحيحة بالضبط.
          OrderProductsPreview(order: order, emphasizeVariants: true),
          const SizedBox(height: 8),
          if (order.shippingAddress.address.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.location_on_outlined, size: 14, color: colors.textSecondary),
              const SizedBox(width: 4),
              Expanded(child: Text(order.shippingAddress.address,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary))),
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
