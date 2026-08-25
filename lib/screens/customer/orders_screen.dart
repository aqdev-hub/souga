// lib/screens/customer/orders_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

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
      case 'confirmed': return Icons.check_circle_outline;
      case 'shipped': return Icons.local_shipping_outlined;
      case 'delivered': return Icons.done_all;
      case 'cancelled': return Icons.cancel_outlined;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final colors = context.colors;

    // إصلاح: استخدام {} في الشرط
    if (user.uid == 'guest') {
      return Scaffold(
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_outline, size: 80, color: colors.border),
          const SizedBox(height: 16),
          Text('سجّل دخولك لرؤية طلباتك', style: TextStyle(fontSize: 16, color: colors.textSecondary)),
        ])),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders')
            .where('customerId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.receipt_long_outlined, size: 100, color: colors.border),
              const SizedBox(height: 16),
              Text('لا توجد طلبات بعد', style: TextStyle(fontSize: 18, color: colors.textSecondary)),
            ]));
          }
          final orders = snap.data!.docs.map((d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (_, i) {
              final o = orders[i];
              final statusColor = _statusColor(colors, o.status);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('طلب #${o.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_statusIcon(o.status), size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(o.statusArabic, style: TextStyle(color: statusColor, fontSize: 12)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text('المتجر: ${o.sellerName}', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  ...o.products.map((p) => Text('• ${p.name} × ${p.quantity}', style: TextStyle(fontSize: 13, color: colors.textSecondary))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('الإجمالي: ${o.totalAmount.toStringAsFixed(2)} ${o.currencySymbol}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                    const Spacer(),
                    Icon(Icons.payments_outlined, size: 16, color: colors.textSecondary),
                    const SizedBox(width: 4),
                    Text('عند الاستلام', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                  ]),
                ])),
              );
            },
          );
        },
      ),
    );
  }
}
