// lib/screens/admin/admin_payments_screen.dart
//
// ✅ لوحة المشرف للتحقق من دفعات حاسب، وفصل النزاعات، ومتابعة الاستردادات.
// المرحلة الأولى (إثبات يدوي): يطابق المشرف رقم العملية والمبلغ مع كشف حساب
// سوجا في حاسب قبل الضغط على «تأكيد الدفع».

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/order_model.dart';
import '../../services/imagekit_service.dart';
import '../../services/orders_api.dart';
import '../../utils/app_colors.dart';
import '../../utils/order_ui.dart';

class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المدفوعات والنزاعات'),
          bottom: const TabBar(tabs: [
            Tab(text: 'دفعات حاسب'),
            Tab(text: 'نزاعات'),
            Tab(text: 'استردادات'),
          ]),
        ),
        body: const TabBarView(children: [
          _PaymentsTab(),
          _DisputesTab(),
          _RefundsTab(),
        ]),
      ),
    );
  }
}

void _toast(BuildContext context, OrdersApiResult r, String ok) {
  ScaffoldMessenger.of(context).showSnackBar(r.ok
      ? OrderUi.snack(context, ok)
      : OrderUi.snack(context, r.message, error: true));
}

Future<String?> _askReason(
    BuildContext context, String title, String label) async {
  final ctrl = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: InputDecoration(labelText: label)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('رجوع')),
        TextButton(
          onPressed: () {
            if (ctrl.text.trim().length >= 2) {
              Navigator.pop(ctx, ctrl.text.trim());
            }
          },
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return r;
}

void _showImage(BuildContext context, String url) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      child: InteractiveViewer(
        child: Image.network(ImageKitService.productFullUrl(url),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('تعذّر تحميل الصورة'))),
      ),
    ),
  );
}

// ── دفعات حاسب ───────────────────────────────────────────────────────────
class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .where('status', isEqualTo: 'awaiting_verification')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = (snap.data?.docs ?? []).toList()
          ..sort((a, b) {
            final x = ((a.data() as Map)['submittedAt'] as Timestamp?)
                    ?.millisecondsSinceEpoch ??
                0;
            final y = ((b.data() as Map)['submittedAt'] as Timestamp?)
                    ?.millisecondsSinceEpoch ??
                0;
            return x.compareTo(y);
          });
        if (docs.isEmpty) {
          return const Center(child: Text('لا توجد دفعات بانتظار التحقق'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final proof = (d['proofUrl'] ?? '').toString();
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            OrderUi.money(
                                (d['amount'] as num?)?.toDouble() ?? 0,
                                (d['currencyCode'] ?? '').toString()),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colors.primary)),
                        const SizedBox(height: 6),
                        Text('مرجع سوجا: ${d['reference'] ?? ''}'),
                        Text('رقم العملية: ${d['transactionRef'] ?? ''}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        if ((d['payerPhone'] ?? '').toString().isNotEmpty)
                          Text('جوال الدافع: ${d['payerPhone']}'),
                        Text(
                            'عدد الطلبات المرتبطة: ${(d['orderIds'] as List?)?.length ?? 0}',
                            style: TextStyle(
                                color: colors.textSecondary, fontSize: 12.5)),
                        if (proof.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _showImage(context, proof),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                  ImageKitService.productUrl(proof),
                                  height: 140,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                      height: 40,
                                      child: Text('تعذّر تحميل الإيصال'))),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: colors.success),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('تأكيد الدفع'),
                            onPressed: () async {
                              final r = await OrdersApi.adminVerifyPayment(id,
                                  approve: true);
                              if (context.mounted) {
                                _toast(
                                    context, r, 'تم تأكيد الدفع وإشعار البائع');
                              }
                            },
                          )),
                          const SizedBox(width: 8),
                          Expanded(
                              child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: colors.error,
                                side: BorderSide(color: colors.error)),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('رفض'),
                            onPressed: () async {
                              final reason = await _askReason(context,
                                  'رفض الإثبات', 'السبب (يراه المشتري)');
                              if (reason == null) return;
                              final r = await OrdersApi.adminVerifyPayment(id,
                                  approve: false, reason: reason);
                              if (context.mounted) {
                                _toast(context, r, 'تم رفض الإثبات');
                              }
                            },
                          )),
                        ]),
                      ])),
            );
          },
        );
      },
    );
  }
}

// ── النزاعات ──────────────────────────────────────────────────────────────
class _DisputesTab extends StatelessWidget {
  const _DisputesTab();

  Future<void> _resolve(
      BuildContext context, String orderId, double total, String symbol) async {
    String decision = 'refund_full';
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
                title: const Text('قرار النزاع'),
                content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<String>(
                      initialValue: decision,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                            value: 'refund_full',
                            child: Text('استرداد كامل للمشتري')),
                        DropdownMenuItem(
                            value: 'refund_partial',
                            child: Text('استرداد جزئي')),
                        DropdownMenuItem(
                            value: 'release',
                            child: Text('لصالح البائع (بلا استرداد)')),
                      ],
                      onChanged: (v) => setS(() => decision = v ?? decision),
                    ),
                    if (decision == 'refund_partial')
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: 'مبلغ الاسترداد ($symbol)',
                            helperText:
                                'أقل من ${OrderUi.money(total, symbol)}'),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                        controller: noteCtrl,
                        maxLines: 2,
                        decoration:
                            const InputDecoration(labelText: 'ملاحظة للطرفين')),
                  ]),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('رجوع')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('إصدار القرار')),
                ],
              )),
    );
    final amount = double.tryParse(amountCtrl.text.trim());
    final note = noteCtrl.text.trim();
    amountCtrl.dispose();
    noteCtrl.dispose();
    if (ok != true) return;
    final r = await OrdersApi.adminResolveDispute(orderId,
        decision: decision,
        amount: decision == 'refund_partial' ? amount : null,
        note: note);
    if (context.mounted) _toast(context, r, 'تم إصدار القرار');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('disputes')
          .where('status', isEqualTo: 'open')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('لا توجد نزاعات مفتوحة'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final amount = (d['amount'] as num?)?.toDouble() ?? 0;
            final cur = (d['currency'] ?? '').toString();
            final evidence = (d['evidence'] as List? ?? [])
                .map((e) => e.toString())
                .toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'طلب #${id.substring(0, 8)} — ${OrderUi.money(amount, cur)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            d['paymentMethod'] == OrderModel.payHasab
                                ? 'مدفوع عبر حاسب (محجوز)'
                                : 'دفع عند الاستلام',
                            style: TextStyle(
                                fontSize: 12.5, color: colors.textSecondary)),
                        const Divider(height: 18),
                        Text(
                            'المشتري: ${OrderUi.disputeReasons[d['reason']] ?? d['reason']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text((d['details'] ?? '').toString(),
                            style: const TextStyle(height: 1.5)),
                        if (evidence.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                                spacing: 8,
                                children: evidence
                                    .map((u) => InkWell(
                                          onTap: () => _showImage(context, u),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: Image.network(
                                                ImageKitService.thumbnailUrl(u),
                                                width: 64,
                                                height: 64,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const SizedBox(
                                                        width: 64, height: 64)),
                                          ),
                                        ))
                                    .toList()),
                          ),
                        if ((d['sellerReply'] ?? '').toString().isNotEmpty) ...[
                          const Divider(height: 18),
                          Text('ردّ البائع: ${d['sellerReply']}',
                              style: const TextStyle(height: 1.5)),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('لم يرد البائع بعد',
                                style: TextStyle(
                                    fontSize: 12, color: colors.warning)),
                          ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.gavel_outlined, size: 18),
                          label: const Text('إصدار القرار'),
                          onPressed: () => _resolve(context, id, amount, cur),
                        ),
                      ])),
            );
          },
        );
      },
    );
  }
}

// ── الاستردادات المعلّقة ─────────────────────────────────────────────────
class _RefundEntry {
  final OrderModel order;
  final double amount;
  final bool partial; // استرداد جزئي بسبب إزالة أصناف قبل الشحن
  const _RefundEntry(this.order, this.amount, this.partial);
}

class _RefundsTab extends StatelessWidget {
  const _RefundsTab();

  List<OrderModel> _parse(AsyncSnapshot<QuerySnapshot> snap) =>
      (snap.data?.docs ?? [])
          .map(
              (d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    // استردادات كاملة (إلغاء/نزاع) + استردادات جزئية (إزالة أصناف) في قائمة واحدة
    return StreamBuilder<QuerySnapshot>(
      stream: fs
          .collection('orders')
          .where('paymentStatus', isEqualTo: 'refund_pending')
          .snapshots(),
      builder: (context, fullSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: fs
              .collection('orders')
              .where('partialRefundPending', isEqualTo: true)
              .snapshots(),
          builder: (context, partSnap) {
            if (fullSnap.connectionState == ConnectionState.waiting &&
                partSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final entries = <_RefundEntry>[
              for (final o in _parse(fullSnap))
                _RefundEntry(o,
                    o.refundAmount > 0 ? o.refundAmount : o.totalAmount, false),
              for (final o in _parse(partSnap))
                _RefundEntry(o, o.partialRefundDue, true),
            ];
            if (entries.isEmpty) {
              return const Center(child: Text('لا توجد استردادات معلّقة'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              itemBuilder: (_, i) => _card(context, entries[i]),
            );
          },
        );
      },
    );
  }

  Widget _card(BuildContext context, _RefundEntry e) {
    final colors = context.colors;
    final o = e.order;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
            '${e.partial ? 'رد جزئي ' : 'رد '}${OrderUi.money(e.amount, o.currencySymbol)} إلى ${o.customerName}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
            'طلب #${o.id.substring(0, 8)} — ${o.customerPhone}\n${o.paymentMethodArabic}'
            '${e.partial ? ' — أصناف أُزيلت قبل الشحن' : ''}',
            style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
        isThreeLine: true,
        trailing: ElevatedButton(
          child: const Text('تم الرد'),
          onPressed: () async {
            final ctrl = TextEditingController();
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('تأكيد رد المبلغ'),
                content: TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(
                        labelText: 'مرجع التحويل (اختياري)')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('رجوع')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تأكيد')),
                ],
              ),
            );
            final ref = ctrl.text.trim();
            ctrl.dispose();
            if (ok != true) return;
            final r = e.partial
                ? await OrdersApi.adminMarkPartialRefunded(o.id, reference: ref)
                : await OrdersApi.adminMarkRefunded(o.id, reference: ref);
            if (context.mounted) _toast(context, r, 'تم تسجيل الاسترداد');
          },
        ),
      ),
    );
  }
}
