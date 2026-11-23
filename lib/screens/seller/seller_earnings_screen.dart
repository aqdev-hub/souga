// lib/screens/seller/seller_earnings_screen.dart
//
// ✅ مستحقات البائع: المتاح للسحب، المحجوز لدى المنصة (طلبات مدفوعة لم تُسلَّم/لم تنتهِ حمايتها)،
// عمولة الدفع عند الاستلام المستحقة للمنصة، ما دُفع لك، وسجل الحركات.
// القراءة فقط — الدفعات تتم من المشرف (POST /admin/payouts).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/order_ui.dart';

class SellerEarningsScreen extends StatelessWidget {
  const SellerEarningsScreen({super.key});

  static const _types = {
    'release': ['تحرير مستحقات', Icons.arrow_downward_rounded, 1],
    'commission': ['عمولة المنصة', Icons.percent_rounded, 0],
    'commission_due': ['عمولة مستحقة (دفع عند الاستلام)', Icons.receipt_long_outlined, 0],
    'commission_paid': ['سداد عمولة للمنصة', Icons.payments_outlined, 1],
    'commission_offset': ['عمولة خُصمت من رصيدك', Icons.swap_horiz_rounded, 0],
    'commission_reversal': ['عكس عمولة (استرداد)', Icons.replay_rounded, 1],
    'payout': ['دفعة مستلمة', Icons.account_balance_outlined, 1],
    'hold': ['مبلغ محجوز', Icons.lock_outline, 0],
    'refund_due': ['استرداد للمشتري', Icons.undo_rounded, 0],
    'refund': ['تم الاسترداد', Icons.undo_rounded, 0],
  };

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().currentUser!.uid;
    final colors = context.colors;
    final fs = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('مستحقاتي')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: fs.collection('seller_balances').doc(uid).snapshots(),
            builder: (context, balSnap) {
              final bal = Map<String, dynamic>.from(
                  (balSnap.data?.data()?['balances'] as Map?) ?? {});
              return StreamBuilder<QuerySnapshot>(
                stream: fs.collection('orders')
                    .where('sellerId', isEqualTo: uid)
                    .where('paymentStatus', isEqualTo: 'paid_held').snapshots(),
                builder: (context, heldSnap) {
                  final held = <String, double>{};
                  final sym = <String, String>{};
                  for (final d in heldSnap.data?.docs ?? []) {
                    final m = d.data() as Map<String, dynamic>;
                    final c = (m['currencyCode'] ?? '').toString();
                    final total = (m['totalAmount'] as num?)?.toDouble() ?? 0;
                    final comm = (m['commissionAmount'] as num?)?.toDouble() ?? 0;
                    // المحجوز = صافي البائع المتوقع (بعد عمولة المنصة)
                    held[c] = (held[c] ?? 0) + (total - (comm > total ? total : comm));
                    sym[c] = (m['currencySymbol'] ?? c).toString();
                  }
                  final codes = {...bal.keys, ...held.keys}.toList()..sort();
                  if (codes.isEmpty) {
                    return Card(child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('لا توجد مستحقات بعد. تظهر هنا بعد تسليم الطلبات المدفوعة عبر حاسب وانتهاء مهلة الحماية.',
                          style: TextStyle(color: colors.textSecondary, height: 1.6)),
                    ));
                  }
                  return Column(children: codes.map((c) {
                    final b = Map<String, dynamic>.from((bal[c] as Map?) ?? {});
                    double n(String k) => (b[k] as num?)?.toDouble() ?? 0;
                    final s = sym[c] ?? c;
                    Widget row(String label, double v, {Color? color, bool big = false}) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Text(label, style: TextStyle(fontSize: big ? 14 : 12.5, color: colors.textSecondary)),
                            const Spacer(),
                            Text(OrderUi.money(v, s), style: TextStyle(
                                fontSize: big ? 20 : 13.5, fontWeight: FontWeight.bold, color: color)),
                          ]),
                        );
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
                        Align(alignment: AlignmentDirectional.centerStart,
                            child: Text('العملة: $c', style: const TextStyle(fontWeight: FontWeight.bold))),
                        const Divider(height: 14),
                        row('المتاح للدفع لك', n('available'), color: colors.success, big: true),
                        row('محجوز لدى سوجا (صافي بعد العمولة)', held[c] ?? 0),
                        row('عمولة مستحقة للمنصة (دفع عند الاستلام)', n('commissionDue'), color: n('commissionDue') > 0 ? colors.warning : null),
                        if (n('commissionDue') > 0)
                          row('الصافي بعد خصم العمولة المستحقة', n('available') - n('commissionDue'),
                              color: (n('available') - n('commissionDue')) >= 0 ? colors.success : colors.error),
                        row('إجمالي عمولة سوجا حتى الآن', n('commissionCharged')),
                        row('ما استلمته سابقاً', n('paidOut')),
                      ])),
                    );
                  }).toList());
                },
              );
            },
          ),
          const SizedBox(height: 8),
          Text('آخر الحركات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: fs.collection('ledger').where('sellerId', isEqualTo: uid).limit(100).snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              }
              final docs = (snap.data?.docs ?? []).toList()
                ..sort((a, b) {
                  final x = ((a.data() as Map)['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                  final y = ((b.data() as Map)['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                  return y.compareTo(x);
                });
              if (docs.isEmpty) {
                return Padding(padding: const EdgeInsets.all(24),
                    child: Center(child: Text('لا توجد حركات بعد', style: TextStyle(color: colors.textSecondary))));
              }
              return Column(children: docs.map((d) {
                final m = d.data() as Map<String, dynamic>;
                final t = _types[m['type']];
                final label = t != null ? t[0] as String : (m['type'] ?? '').toString();
                final icon = t != null ? t[1] as IconData : Icons.circle_outlined;
                final credit = t != null && t[2] == 1;
                final at = (m['createdAt'] as Timestamp?)?.toDate();
                final oid = (m['orderId'] ?? '').toString();
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: Icon(icon, color: credit ? colors.success : colors.textSecondary),
                    title: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      if (oid.isNotEmpty) 'طلب #${oid.substring(0, oid.length < 8 ? oid.length : 8)}',
                      if (at != null) OrderUi.dateTime(at),
                    ].join(' • '), style: const TextStyle(fontSize: 11.5)),
                    trailing: Text(
                      '${credit ? '+' : ''}${(m['amount'] as num?)?.toDouble().toStringAsFixed(2) ?? ''} ${m['currency'] ?? ''}',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(fontWeight: FontWeight.bold, color: credit ? colors.success : null),
                    ),
                  ),
                );
              }).toList());
            },
          ),
        ],
      ),
    );
  }
}
