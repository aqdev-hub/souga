// lib/screens/seller/seller_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/notifications_service.dart';
import '../../utils/app_colors.dart';
import 'seller_orders_screen.dart';
import 'seller_products_screen.dart';
import '../shared/notifications_screen.dart';

class SellerDashboardScreen extends StatelessWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final fs = FirebaseFirestore.instance;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(user.storeName.isNotEmpty ? user.storeName : user.name),
        automaticallyImplyLeading: false,
        actions: [
          // زر الإشعارات مع عداد
          StreamBuilder<int>(
            stream: NotificationsService.getUnreadCount(user.uid),
            builder: (_, snap) {
              final count = snap.data ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count', style: const TextStyle(fontSize: 10)),
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('إحصائيات متجرك',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _SellerStatCard(
              title: 'المنتجات', icon: Icons.inventory_2_outlined, color: colors.primary,
              future: fs.collection('products').where('sellerId', isEqualTo: user.uid)
                  .count().get().then((s) => s.count ?? 0),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SellerProductsScreen())),
            )),
            const SizedBox(width: 12),
            Expanded(child: _SellerStatCard(
              title: 'طلبات جديدة', icon: Icons.fiber_new_outlined, color: colors.warning,
              future: fs.collection('orders').where('sellerId', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'pending').count().get().then((s) => s.count ?? 0),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SellerOrdersScreen(filterStatus: 'pending'))),
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _SellerStatCard(
              title: 'إجمالي الطلبات', icon: Icons.receipt_long_outlined, color: colors.info,
              future: fs.collection('orders').where('sellerId', isEqualTo: user.uid)
                  .count().get().then((s) => s.count ?? 0),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SellerOrdersScreen())),
            )),
            const SizedBox(width: 12),
            Expanded(child: _SellerStatCard(
              title: 'مكتملة', icon: Icons.check_circle_outline, color: colors.success,
              future: fs.collection('orders').where('sellerId', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'delivered').count().get().then((s) => s.count ?? 0),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SellerOrdersScreen(filterStatus: 'delivered'))),
            )),
          ]),
          const SizedBox(height: 24),
          Text('آخر الطلبات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: fs.collection('orders').where('sellerId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true).limit(5).snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Center(child: Padding(padding: const EdgeInsets.all(24),
                    child: Text('لا توجد طلبات بعد',
                        style: TextStyle(color: colors.textSecondary))));
              }
              return Column(children: snap.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'pending';
                final statusColor = _statusColor(colors, status);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withValues(alpha: 0.15),
                      child: Icon(_statusIcon(status), color: statusColor, size: 20),
                    ),
                    title: Text(data['customerName'] ?? ''),
                    subtitle: Text('${(data['totalAmount'] ?? 0).toStringAsFixed(2)} ${(data['currencySymbol'] ?? 'ر.س')}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_statusArabic(status),
                          style: TextStyle(color: statusColor, fontSize: 12)),
                    ),
                  ),
                );
              }).toList());
            },
          ),
        ]),
      ),
    );
  }

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

  IconData _statusIcon(String s) {
    switch (s) {
      case 'pending': return Icons.hourglass_empty;
      case 'confirmed': return Icons.check;
      case 'shipped': return Icons.local_shipping_outlined;
      case 'delivered': return Icons.check_circle_outline;
      default: return Icons.cancel_outlined;
    }
  }

  String _statusArabic(String s) {
    switch (s) {
      case 'pending': return 'انتظار';
      case 'confirmed': return 'مؤكد';
      case 'shipped': return 'شحن';
      case 'delivered': return 'مكتمل';
      case 'cancelled': return 'ملغي';
      default: return s;
    }
  }
}

class _SellerStatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Future<int> future;
  final VoidCallback onTap;

  const _SellerStatCard({
    required this.title, required this.icon,
    required this.color, required this.future, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: color, size: 26),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 12, color: color.withValues(alpha: 0.5)),
            ]),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: future,
              builder: (_, snap) => Text(snap.hasData ? '${snap.data}' : '...',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            ),
            Text(title, style: TextStyle(fontSize: 13, color: context.colors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}
