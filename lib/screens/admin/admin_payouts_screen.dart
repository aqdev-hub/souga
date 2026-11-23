// lib/screens/admin/admin_payouts_screen.dart
//
// مستحقات البائعين: يرى المشرف الرصيد المتاح لكل بائع بكل عملة،
// وبعد تحويل المبلغ فعلياً (خارج التطبيق) يسجّل «دفعة» فيخصمها السيرفر
// من الرصيد المتاح ويكتب قيداً في الدفتر ويُشعر البائع.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/orders_api.dart';
import '../../utils/app_colors.dart';
import '../../utils/order_ui.dart';

class AdminPayoutsScreen extends StatefulWidget {
  const AdminPayoutsScreen({super.key});

  @override
  State<AdminPayoutsScreen> createState() => _AdminPayoutsScreenState();
}

class _AdminPayoutsScreenState extends State<AdminPayoutsScreen> {
  final Map<String, Future<String>> _names = {};

  Future<String> _nameOf(String uid) => _names.putIfAbsent(uid, () async {
        try {
          final d = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final m = d.data() ?? {};
          final store = (m['storeName'] ?? '').toString();
          final name = (m['name'] ?? '').toString();
          final phone = (m['phone'] ?? '').toString();
          final base = store.isNotEmpty ? store : (name.isNotEmpty ? name : uid);
          return phone.isNotEmpty ? '$base · $phone' : base;
        } catch (_) {
          return uid;
        }
      });

  Future<void> _payout(String sellerId, String name, String currency, double available) async {
    final amountCtrl = TextEditingController(
        text: available == available.roundToDouble() ? available.toStringAsFixed(0) : available.toStringAsFixed(2));
    final refCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل دفعة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$name\nالمتاح: ${OrderUi.money(available, currency)}',
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'المبلغ المحوَّل ($currency)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: refCtrl,
            decoration: const InputDecoration(labelText: 'رقم العملية/المرجع (اختياري)'),
          ),
          const SizedBox(height: 8),
          Text('سجّل الدفعة بعد إتمام التحويل فعلياً. لا يمكن التراجع عنها من هنا.',
              style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسجيل')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    if (amount <= 0 || amount > available + 0.0001) {
      ScaffoldMessenger.of(context)
          .showSnackBar(OrderUi.snack(context, 'المبلغ غير صالح (الحد الأقصى المتاح).', error: true));
      return;
    }
    final r = await OrdersApi.adminPayout(
        sellerId: sellerId, currency: currency, amount: amount, reference: refCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        OrderUi.snack(context, r.ok ? 'تم تسجيل الدفعة' : r.message, error: !r.ok));
  }

  Future<void> _settle(String sellerId, String name, String currency, double due, double available) async {
    final amountCtrl = TextEditingController(
        text: due == due.roundToDouble() ? due.toStringAsFixed(0) : due.toStringAsFixed(2));
    final refCtrl = TextEditingController();
    bool offset = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('تسوية عمولة الدفع عند الاستلام'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$name\nالمستحق للمنصة: ${OrderUi.money(due, currency)}',
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('سدّدها البائع')),
              ButtonSegment(value: true, label: Text('خصم من رصيده')),
            ],
            selected: {offset},
            onSelectionChanged: (v) => setS(() => offset = v.first),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'المبلغ ($currency)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: refCtrl,
            decoration: const InputDecoration(labelText: 'رقم العملية/المرجع (اختياري)'),
          ),
          if (offset)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('الحد الأقصى من الرصيد المتاح: ${OrderUi.money(available, currency)}',
                  style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسجيل')),
        ],
      )),
    );
    if (ok != true || !mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final max = offset ? (due < available ? due : available) : due;
    if (amount <= 0 || amount > max + 0.0001) {
      ScaffoldMessenger.of(context)
          .showSnackBar(OrderUi.snack(context, 'المبلغ غير صالح (الحد الأقصى ${OrderUi.money(max, currency)}).', error: true));
      return;
    }
    final r = await OrdersApi.adminSettleCommission(
        sellerId: sellerId, currency: currency, amount: amount, offset: offset, reference: refCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        OrderUi.snack(context, r.ok ? 'تمت التسوية' : r.message, error: !r.ok));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('مستحقات البائعين')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('seller_balances').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('تعذّر التحميل', style: TextStyle(color: c.error)));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          // (بائع، عملة) ← المتاح > 0 فقط
          final rows = <_Row>[];
          for (final d in snap.data!.docs) {
            final bal = Map<String, dynamic>.from((d.data()['balances'] as Map?) ?? {});
            bal.forEach((cur, v) {
              final m = Map<String, dynamic>.from(v as Map);
              final avail = (m['available'] as num?)?.toDouble() ?? 0;
              final paid = (m['paidOut'] as num?)?.toDouble() ?? 0;
              final due  = (m['commissionDue'] as num?)?.toDouble() ?? 0;
              if (avail > 0.0001 || due > 0.0001) rows.add(_Row(d.id, cur, avail, paid, due));
            });
          }
          rows.sort((a, b) => b.available.compareTo(a.available));

          if (rows.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.account_balance_wallet_outlined, size: 56, color: c.textHint),
                const SizedBox(height: 10),
                Text('لا توجد مستحقات بانتظار التحويل', style: TextStyle(color: c.textSecondary)),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = rows[i];
              return FutureBuilder<String>(
                future: _nameOf(r.sellerId),
                builder: (_, ns) {
                  final name = ns.data ?? '...';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 8),
                        _line(c, 'المتاح للدفع', OrderUi.money(r.available, r.currency), c.success),
                        if (r.due > 0)
                          _line(c, 'عمولة مستحقة للمنصة', OrderUi.money(r.due, r.currency), c.warning),
                        if (r.paidOut > 0)
                          _line(c, 'سُدّد سابقاً', OrderUi.money(r.paidOut, r.currency), null),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          if (r.available > 0.0001)
                            ElevatedButton(
                              onPressed: () => _payout(r.sellerId, name, r.currency, r.available),
                              child: const Text('تسجيل دفعة'),
                            ),
                          if (r.due > 0.0001)
                            OutlinedButton(
                              onPressed: () => _settle(r.sellerId, name, r.currency, r.due, r.available),
                              child: const Text('تسوية العمولة'),
                            ),
                        ]),
                      ]),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

Widget _line(SougaColors c, String label, String value, Color? color) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: c.textSecondary))),
        Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color)),
      ]),
    );

class _Row {
  final String sellerId, currency;
  final double available, paidOut, due;
  _Row(this.sellerId, this.currency, this.available, this.paidOut, this.due);
}
