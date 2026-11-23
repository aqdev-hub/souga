// lib/screens/admin/admin_paused_sellers_screen.dart
//
// البائعون الذين أوقف السيرفر استقبال طلباتهم تلقائياً بعد تكرار تجاوز مهلة
// القبول (العتبة في app_config/orders.sellerTimeoutsBeforePause، الافتراضي 5).
// الاستئناف يصفّر العدّاد.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/orders_api.dart';
import '../../utils/app_colors.dart';
import '../../utils/order_ui.dart';

class AdminPausedSellersScreen extends StatefulWidget {
  const AdminPausedSellersScreen({super.key});

  @override
  State<AdminPausedSellersScreen> createState() => _AdminPausedSellersScreenState();
}

class _AdminPausedSellersScreenState extends State<AdminPausedSellersScreen> {
  final Set<String> _busy = {};

  Future<void> _resume(String uid, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استئناف المتجر؟'),
        content: Text('سيستقبل «$name» الطلبات مجدداً ويُصفَّر عدّاد التجاوزات.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استئناف')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy.add(uid));
    final r = await OrdersApi.adminResumeSeller(uid);
    if (!mounted) return;
    setState(() => _busy.remove(uid));
    ScaffoldMessenger.of(context).showSnackBar(
        OrderUi.snack(context, r.ok ? 'تم استئناف المتجر' : r.message, error: !r.ok));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('بائعون موقوفون تلقائياً')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('ordersPaused', isEqualTo: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('تعذّر التحميل', style: TextStyle(color: c.error)));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified_outlined, size: 56, color: c.success),
                const SizedBox(height: 10),
                Text('لا يوجد بائعون موقوفون', style: TextStyle(color: c.textSecondary)),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i];
              final m = d.data();
              final store = (m['storeName'] ?? '').toString();
              final name = store.isNotEmpty ? store : (m['name'] ?? d.id).toString();
              final n = (m['sellerTimeouts'] as num?)?.toInt() ?? 0;
              return Card(
                child: ListTile(
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('تجاوز مهلة القبول $n مرة'),
                  trailing: _busy.contains(d.id)
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : ElevatedButton(onPressed: () => _resume(d.id, name), child: const Text('استئناف')),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
