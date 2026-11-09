// lib/screens/customer/orders_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/order_list_tools.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _query = '';
  OrderSort _sort = OrderSort.newest;

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

  /// ✅ التراجع عن الطلب (إلغاء) — متاح قبل الشحن فقط.
  Future<void> _cancelOrder(OrderModel o) async {
    final colors = context.colors;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('التراجع عن الطلب'),
        content: Text('هل تريد إلغاء الطلب #${o.id.substring(0, 8)}؟\nسيتم إبلاغ البائع بالإلغاء ولا يمكن التراجع عنه بعد ذلك.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('إلغاء الطلب', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await OrderService.cancelByCustomer(o);
      messenger.showSnackBar(SnackBar(
        content: const Text('تم إلغاء الطلب'),
        backgroundColor: colors.success,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('تعذّر إلغاء الطلب: $e'),
        backgroundColor: colors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final colors = context.colors;

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
      body: Column(children: [
        OrderToolbar(
          hint: 'ابحث برقم الطلب أو اسم المنتج أو المتجر...',
          sort: _sort,
          onQueryChanged: (v) => setState(() => _query = v),
          onSortChanged: (s) => setState(() => _sort = s),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders')
                .where('customerId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return orderEmptyState(context, searching: false, emptyText: 'لا توجد طلبات بعد');
              }
              final all = snap.data!.docs
                  .map((d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                  .toList();
              final orders = applyOrderQuery(all, query: _query, sort: _sort);
              if (orders.isEmpty) {
                return orderEmptyState(context, searching: true, emptyText: '');
              }
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
                      const SizedBox(height: 6),
                      Text('المتجر: ${o.sellerName}', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 10),
                      // ✅ صورة مصغّرة + اسم كل منتج (مع خيارات التركيبة المشتراة)
                      OrderProductsPreview(order: o),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text('الإجمالي: ${o.totalAmount.toStringAsFixed(2)} ${o.currencySymbol}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                        const Spacer(),
                        Icon(Icons.payments_outlined, size: 16, color: colors.textSecondary),
                        const SizedBox(width: 4),
                        Text('عند الاستلام', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                      ]),
                      if (OrderService.canCustomerCancel(o)) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _cancelOrder(o),
                            icon: Icon(Icons.undo_rounded, size: 18, color: colors.error),
                            label: Text('التراجع عن الطلب', style: TextStyle(color: colors.error)),
                            style: OutlinedButton.styleFrom(side: BorderSide(color: colors.error)),
                          ),
                        ),
                      ],
                    ])),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
