// lib/screens/admin/admin_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/order_list_tools.dart';

class AdminOrdersScreen extends StatefulWidget {
  final String? filterStatus;
  const AdminOrdersScreen({super.key, this.filterStatus});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String _query = '';
  OrderSort _sort = OrderSort.newest;
  bool _showDeleted = false;

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

  Future<void> _hideOrRestore(OrderModel o) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_showDeleted) {
        await OrderService.restore(o.id, OrderOwnerRole.admin);
        messenger.showSnackBar(const SnackBar(content: Text('تمت استعادة الطلب')));
      } else {
        await OrderService.hide(o.id, OrderOwnerRole.admin);
        if (mounted) {
          showUndoSnack(context, 'تم حذف الطلب من قائمة الإدارة',
              () => OrderService.restore(o.id, OrderOwnerRole.admin));
        }
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('تعذّر تنفيذ العملية: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(_showDeleted ? 'الطلبات المحذوفة' : 'إدارة الطلبات'),
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
          hint: 'ابحث برقم الطلب أو المنتج أو المشتري أو البائع...',
          sort: _sort,
          onQueryChanged: (v) => setState(() => _query = v),
          onSortChanged: (s) => setState(() => _sort = s),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final filter = widget.filterStatus;
              final all = (snap.data?.docs ?? [])
                  .map((d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                  .where((o) => o.hiddenForAdmin == _showDeleted)
                  .where((o) => filter == null || filter.isEmpty || o.status == filter)
                  .toList();
              if (all.isEmpty) {
                return orderEmptyState(context,
                    searching: false,
                    emptyText: _showDeleted ? 'لا توجد طلبات محذوفة' : 'لا توجد طلبات');
              }
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
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('طلب #${o.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text(o.statusArabic, style: TextStyle(color: statusColor, fontSize: 12)),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'خيارات',
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_vert, size: 20, color: colors.textSecondary),
                          onSelected: (_) => _hideOrRestore(o),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'x',
                              child: Row(children: [
                                Icon(_showDeleted ? Icons.restore_from_trash_outlined : Icons.delete_outline,
                                    size: 18, color: _showDeleted ? colors.success : colors.error),
                                const SizedBox(width: 8),
                                Text(_showDeleted ? 'استعادة الطلب' : 'حذف من قائمة الإدارة'),
                              ]),
                            ),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text('المشتري: ${o.customerName}', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                      Text('البائع: ${o.sellerName}', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 10),
                      // ✅ صورة مصغّرة + اسم كل منتج في الطلب
                      OrderProductsPreview(order: o),
                      Text('الإجمالي: ${o.totalAmount.toStringAsFixed(2)} ${o.currencySymbol}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
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
