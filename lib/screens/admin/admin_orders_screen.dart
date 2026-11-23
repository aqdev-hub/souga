// lib/screens/admin/admin_orders_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/orders_api.dart';
import '../../utils/app_colors.dart';
import '../../utils/order_ui.dart';
import 'admin_payments_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  final String? filterStatus;
  const AdminOrdersScreen({super.key, this.filterStatus});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late String _filter; // all | action | <status>

  @override
  void initState() {
    super.initState();
    _filter = widget.filterStatus ?? 'all';
  }

  bool _match(OrderModel o) {
    if (_filter == 'all') return true;
    if (_filter == 'action') {
      return o.paymentStatus == 'refund_pending' ||
          o.paymentStatus == 'awaiting_verification' ||
          o.status == OrderModel.disputed ||
          o.deliveryAttempts >= 5;
    }
    return o.status == _filter;
  }

  Future<void> _markRefunded(OrderModel o) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد رد المبلغ'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: 'مرجع التحويل (اختياري)',
            helperText: 'المبلغ: ${OrderUi.money(o.refundAmount > 0 ? o.refundAmount : o.totalAmount, o.currencySymbol)}',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تم الرد')),
        ],
      ),
    );
    final ref = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    final res = await OrdersApi.adminMarkRefunded(o.id, reference: ref);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(res.ok
        ? OrderUi.snack(context, 'تم تسجيل الاسترداد')
        : OrderUi.snack(context, res.message, error: true));
  }

  Future<void> _resetDelivery(OrderModel o) async {
    final res = await OrdersApi.adminResetDelivery(o.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(res.ok
        ? OrderUi.snack(context, 'أُعيد فتح محاولات الرمز')
        : OrderUi.snack(context, res.message, error: true));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلبات'),
        actions: [
          IconButton(
            tooltip: 'المدفوعات والنزاعات',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminPaymentsScreen())),
          ),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final f in const [
                ['all', 'الكل'], ['action', 'تحتاج إجراء'], ['pending', 'جديدة'],
                ['confirmed', 'قيد التجهيز'], ['shipped', 'في الطريق'],
                ['disputed', 'نزاعات'], ['completed', 'مكتملة'], ['cancelled', 'ملغاة'],
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(f[1]),
                    selected: _filter == f[0],
                    onSelected: (_) => setState(() => _filter = f[0]),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders')
                .orderBy('createdAt', descending: true).limit(300).snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final orders = (snap.data?.docs ?? [])
                  .map((d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                  .where(_match)
                  .toList();
              if (orders.isEmpty) return const Center(child: Text('لا توجد طلبات'));
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: orders.length,
                itemBuilder: (_, i) {
                  final o = orders[i];
                  final sc = OrderUi.statusColor(colors, o);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(padding: const EdgeInsets.all(14), child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('طلب #${o.id.substring(0, 8)}',
                            style: const TextStyle(fontWeight: FontWeight.bold))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text(o.statusArabic, style: TextStyle(color: sc, fontSize: 12)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text('المشتري: ${o.customerName} — ${o.customerPhone}',
                          style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                      Text('البائع: ${o.sellerName}', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                      Text('${o.paymentMethodArabic}${o.paymentStatusArabic.isNotEmpty ? ' — ${o.paymentStatusArabic}' : ''}',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
                      Text('الإجمالي: ${OrderUi.money(o.totalAmount, o.currencySymbol)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                      if (o.paymentStatus == 'refund_pending' || o.deliveryAttempts >= 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(spacing: 8, children: [
                            if (o.paymentStatus == 'refund_pending')
                              OutlinedButton.icon(
                                onPressed: () => _markRefunded(o),
                                icon: const Icon(Icons.currency_exchange, size: 16),
                                label: const Text('تم رد المبلغ'),
                              ),
                            if (o.deliveryAttempts >= 5)
                              OutlinedButton.icon(
                                onPressed: () => _resetDelivery(o),
                                icon: const Icon(Icons.lock_open_rounded, size: 16),
                                label: const Text('فك قفل رمز التسليم'),
                              ),
                          ]),
                        ),
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
