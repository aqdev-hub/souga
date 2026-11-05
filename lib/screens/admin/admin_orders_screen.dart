// lib/screens/admin/admin_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import '../../utils/app_colors.dart';

class AdminOrdersScreen extends StatelessWidget {
  final String? filterStatus;
  const AdminOrdersScreen({super.key, this.filterStatus});

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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الطلبات')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text('لا توجد طلبات'));
          final orders = snap.data!.docs.map((d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (_, i) {
              final o = orders[i];
              final statusColor = _statusColor(colors, o.status);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('طلب #${o.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text(o.statusArabic, style: TextStyle(color: statusColor, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text('المشتري: ${o.customerName}', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  Text('البائع: ${o.sellerName}', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  Text('الإجمالي: ${o.totalAmount.toStringAsFixed(2)} ${o.currencySymbol}', style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                ])),
              );
            },
          );
        },
      ),
    );
  }
}
