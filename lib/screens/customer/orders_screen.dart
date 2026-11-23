// lib/screens/customer/orders_screen.dart
//
// ✅ طلباتي — دورة الشراء الكاملة للمشتري: الحالة، الدفع، رمز التسليم،
// الإلغاء، تأكيد الاستلام، الإبلاغ عن مشكلة، وسجل الطلب.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/orders_api.dart';
import '../../utils/app_colors.dart';
import '../../utils/order_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../seller/delivery_scan_screen.dart' show deliveryQrPayload;
import '../shared/chat_screen.dart';
import 'payment_proof_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _filter = 'all'; // all | active | done | cancelled

  @override
  void initState() {
    super.initState();
    // ينفّذ السيرفر المهل المنتهية (دفع/قبول/حماية) حتى لو كان نائماً.
    OrdersApi.sweep();
  }

  bool _match(OrderModel o) {
    switch (_filter) {
      case 'active':
        return !o.isFinal;
      case 'done':
        return o.status == OrderModel.completed;
      case 'cancelled':
        return o.status == OrderModel.cancelled || o.status == OrderModel.deliveryFailed;
      default:
        return true;
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
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final f in const [
                ['all', 'الكل'], ['active', 'جارية'], ['done', 'مكتملة'], ['cancelled', 'ملغاة'],
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
                .where('customerId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('تعذّر تحميل الطلبات', style: TextStyle(color: colors.textSecondary)));
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = (snap.data?.docs ?? [])
                  .map((d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                  .toList();
              final orders = all.where(_match).toList();
              if (orders.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.receipt_long_outlined, size: 100, color: colors.border),
                  const SizedBox(height: 16),
                  Text(all.isEmpty ? 'لا توجد طلبات بعد' : 'لا توجد طلبات في هذا التصنيف',
                      style: TextStyle(fontSize: 18, color: colors.textSecondary)),
                ]));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: orders.length,
                itemBuilder: (_, i) => _CustomerOrderCard(order: orders[i]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _CustomerOrderCard extends StatefulWidget {
  final OrderModel order;
  const _CustomerOrderCard({required this.order});
  @override
  State<_CustomerOrderCard> createState() => _CustomerOrderCardState();
}

class _CustomerOrderCardState extends State<_CustomerOrderCard> {
  bool _busy = false;
  OrderModel get o => widget.order;

  Future<void> _run(Future<OrdersApiResult> Function() action, String okMsg) async {
    if (_busy) return;
    setState(() => _busy = true);
    final res = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(res.ok
        ? OrderUi.snack(context, okMsg)
        : OrderUi.snack(context, res.message, error: true));
  }

  Future<void> _cancel() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(o.paymentStatus == 'paid_held' || o.paymentStatus == 'awaiting_verification'
              ? 'سيُسجَّل طلب استرداد لمبلغك المدفوع.'
              : 'هل تريد إلغاء هذا الطلب؟'),
          const SizedBox(height: 10),
          TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(labelText: 'السبب (اختياري)', isDense: true),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('إلغاء الطلب', style: TextStyle(color: ctx.colors.error)),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (ok == true) await _run(() => OrdersApi.cancel(o.id, reason: reason), 'تم إلغاء الطلب');
  }

  Future<void> _confirmReceipt() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الاستلام'),
        content: const Text('بعد التأكيد تُحوَّل مستحقات البائع ويُغلق الطلب ولا يمكنك الإبلاغ عن مشكلة. هل استلمت طلبك سليماً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('نعم، استلمته')),
        ],
      ),
    );
    if (ok == true) await _run(() => OrdersApi.confirmReceipt(o.id), 'شكراً! تم إغلاق الطلب');
  }

  Future<void> _dispute() async {
    String reason = 'not_as_described';
    String wanted = 'refund_full';
    final detailsCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('الإبلاغ عن مشكلة'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButtonFormField<String>(
              initialValue: reason,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'نوع المشكلة', isDense: true),
              items: OrderUi.disputeReasons.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setS(() => reason = v ?? reason),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: wanted,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'ما الذي تطلبه', isDense: true),
              items: const [
                DropdownMenuItem(value: 'refund_full', child: Text('استرداد كامل')),
                DropdownMenuItem(value: 'refund_partial', child: Text('استرداد جزئي')),
                DropdownMenuItem(value: 'replace', child: Text('استبدال')),
              ],
              onChanged: (v) => setS(() => wanted = v ?? wanted),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: detailsCtrl,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'اشرح المشكلة', alignLabelWithHint: true),
            ),
            Text('سيرد البائع، ثم تقرر الإدارة. مبلغك يبقى محجوزاً حتى صدور القرار.',
                style: TextStyle(fontSize: 11.5, color: ctx.colors.textSecondary)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال')),
        ],
      )),
    );
    final details = detailsCtrl.text.trim();
    detailsCtrl.dispose();
    if (ok == true) {
      await _run(() => OrdersApi.openDispute(
            orderId: o.id, reason: reason, details: details, wanted: wanted),
          'تم إرسال مشكلتك للمراجعة');
    }
  }

  Future<void> _chatSeller() async {
    final user = context.read<AuthProvider>().currentUser;
    final messenger = ScaffoldMessenger.of(context);
    if (user == null) {
      messenger.showSnackBar(const SnackBar(content: Text('سجّل دخولك أولاً للتواصل مع البائع')));
      return;
    }
    if (o.sellerId.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('بيانات البائع غير متاحة لهذا الطلب')));
      return;
    }
    try {
      final roomId = await ChatService.getOrCreateRoom(
        myUid: user.uid, myName: user.name, myImage: user.profileImage,
        otherUid: o.sellerId, otherName: o.sellerName, otherImage: '',
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(roomId: roomId, otherName: o.sellerName, otherImage: ''),
      ));
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذّر فتح المحادثة، حاول مجدداً')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sc = OrderUi.statusColor(colors, o);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('طلب #${o.id.substring(0, 8)}',
                style: const TextStyle(fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(OrderUi.statusIcon(o), size: 14, color: sc),
                const SizedBox(width: 4),
                Text(o.statusArabic, style: TextStyle(color: sc, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Text('المتجر: ${o.sellerName}', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          ...o.products.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('• ${p.name} × ${p.quantity}', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
              if (p.variantOptions != null && p.variantOptions!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    p.variantOptions!.entries.map((e) => '${e.key}: ${e.value}').join(' • '),
                    style: TextStyle(fontSize: 11, color: colors.textHint),
                  ),
                ),
            ]),
          )),
          const SizedBox(height: 8),
          if (o.shippingFee > 0)
            Text('المجموع ${OrderUi.money(o.subtotal, o.currencySymbol)} + توصيل ${OrderUi.money(o.shippingFee, o.currencySymbol)}',
                style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          Row(children: [
            Text('الإجمالي: ${OrderUi.money(o.totalAmount, o.currencySymbol)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
            const Spacer(),
            Icon(o.isHasab ? Icons.account_balance_wallet_outlined : Icons.payments_outlined,
                size: 16, color: colors.textSecondary),
            const SizedBox(width: 4),
            Text(o.paymentMethodArabic, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          ]),
          if (o.paymentStatusArabic.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('الدفع: ${o.paymentStatusArabic}',
                  style: TextStyle(fontSize: 11.5, color: colors.textHint)),
            ),

          ..._removedItemsNote(colors),
          ..._stateSection(colors),

          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (o.isHasab && o.status == OrderModel.pending && o.paymentStatus == 'unpaid' && o.paymentId.isNotEmpty)
              _btn('إكمال الدفع', Icons.payments_outlined, colors.primary, () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => PaymentProofScreen(paymentIds: [o.paymentId])))),
            if (o.status == OrderModel.delivered && o.inProtectionWindow) ...[
              _btn('تأكيد الاستلام', Icons.check_circle_outline, colors.success, _confirmReceipt),
              _btn('الإبلاغ عن مشكلة', Icons.report_gmailerrorred_outlined, colors.warning, _dispute),
            ],
            if (o.customerCanCancel)
              _btn('إلغاء الطلب', Icons.close_rounded, colors.error, _cancel),
            if (!o.isFinal || o.status == OrderModel.completed)
              _btn('تواصل مع البائع', Icons.chat_bubble_outline, colors.accent, _chatSeller),
          ]),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),

          if (o.timeline.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: Text('سجل الطلب', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                children: o.timeline.reversed.map((e) {
                  final at = (e['at'] as Timestamp?)?.toDate();
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.circle, size: 8, color: colors.textHint),
                    title: Text(_tlLabel(e), style: const TextStyle(fontSize: 12.5)),
                    trailing: at == null ? null
                        : Text(OrderUi.dateTime(at), style: TextStyle(fontSize: 11, color: colors.textHint)),
                  );
                }).toList(),
              ),
            ),
        ]),
      ),
    );
  }

  String _tlLabel(Map<String, dynamic> e) {
    const names = {
      'pending': 'تم إنشاء الطلب', 'confirmed': 'قبل البائع الطلب', 'shipped': 'تم الشحن',
      'delivered': 'تم التسليم', 'completed': 'اكتمل الطلب', 'cancelled': 'أُلغي الطلب',
      'delivery_failed': 'فشل التسليم', 'disputed': 'فُتحت مشكلة',
    };
    final base = names[e['status']] ?? (e['status'] ?? '').toString();
    final note = (e['note'] ?? '').toString();
    return note.isEmpty ? base : '$base — $note';
  }

  // أصناف أزالها البائع من الطلب (غير متوفرة) + حالة الاسترداد الجزئي
  List<Widget> _removedItemsNote(SougaColors colors) {
    if (o.removedItems.isEmpty) return const [];
    final lines = o.removedItems
        .map((e) => '• ${(e['name'] ?? '').toString()} × ${(e['quantity'] ?? 1)} — ${(e['reason'] ?? '').toString()}')
        .join('\n');
    final refund = o.partialRefundPending
        ? '\nسيُرد لك ${OrderUi.money(o.partialRefundDue, o.currencySymbol)} عن الأصناف المُزالة.'
        : '';
    return [
      Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.remove_shopping_cart_outlined, size: 18, color: colors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text('أُزيلت أصناف من طلبك:\n$lines$refund',
                style: TextStyle(fontSize: 12.5, height: 1.5, color: colors.textPrimary)),
          ),
        ]),
      ),
    ];
  }

  List<Widget> _stateSection(SougaColors colors) {
    Widget box(Color c, IconData icon, String text) => Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.withValues(alpha: 0.3)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: c),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.5, color: colors.textPrimary))),
          ]),
        );

    switch (o.status) {
      case OrderModel.pending:
        if (o.paymentStatus == 'unpaid') {
          return [box(colors.warning, Icons.hourglass_bottom,
              'بانتظار دفعك عبر حاسب. ${OrderUi.remaining(o.payDueAt)}')];
        }
        if (o.paymentStatus == 'awaiting_verification') {
          return [box(colors.info, Icons.fact_check_outlined, 'إثبات الدفع قيد المراجعة. سنؤكد دفعك قريباً.')];
        }
        return [box(colors.info, Icons.storefront_outlined,
            'بانتظار قبول البائع. ${OrderUi.remaining(o.acceptDueAt)}')];
      case OrderModel.confirmed:
        return [box(colors.info, Icons.inventory_2_outlined,
            'البائع يجهّز طلبك. ${o.shipDueAt != null && DateTime.now().isAfter(o.shipDueAt!) ? 'تأخر الشحن — يمكنك الإلغاء.' : OrderUi.remaining(o.shipDueAt)}')];
      case OrderModel.shipped:
        return [
          if (o.trackingNumber.isNotEmpty || o.carrierName.isNotEmpty)
            box(colors.primary, Icons.local_shipping_outlined,
                'طلبك في الطريق${o.carrierName.isNotEmpty ? ' عبر ${o.carrierName}' : ''}${o.trackingNumber.isNotEmpty ? ' — رقم التتبع: ${o.trackingNumber}' : ''}.')
          else
            box(colors.primary, Icons.local_shipping_outlined, 'طلبك في الطريق إليك.'),
          _DeliveryCode(orderId: o.id, isCod: o.isCod, total: OrderUi.money(o.totalAmount, o.currencySymbol)),
        ];
      case OrderModel.delivered:
        return [box(colors.success, Icons.done_all,
            'تم تسليم طلبك. إن لم تُبلغ عن مشكلة ${o.protectionUntil != null ? 'قبل ${OrderUi.dateTime(o.protectionUntil!)}' : 'خلال مهلة الحماية'} يُغلق الطلب تلقائياً.')];
      case OrderModel.disputed:
        return [box(colors.warning, Icons.gavel_outlined,
            'مشكلتك قيد المراجعة. مبلغك محجوز حتى صدور قرار الإدارة.')];
      case OrderModel.completed:
        return o.refundAmount > 0
            ? [box(colors.info, Icons.currency_exchange,
                'قرار المشكلة: استرداد ${OrderUi.money(o.refundAmount, o.currencySymbol)}.')]
            : [];
      case OrderModel.cancelled:
        return [box(colors.error, Icons.cancel_outlined,
            'أُلغي الطلب${o.cancelReason.isNotEmpty ? ': ${o.cancelReason}' : ''}.${o.paymentStatus == 'refund_pending' ? ' سيُرد لك مبلغك.' : ''}')];
      case OrderModel.deliveryFailed:
        return [box(colors.error, Icons.assignment_return_outlined,
            'تعذّر تسليم الطلب وأُعيد للبائع.${o.paymentStatus == 'refund_pending' ? ' سيُرد لك مبلغك.' : ''}')];
    }
    return [];
  }

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12.5)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 36),
      ),
    );
  }
}

/// رمز التسليم: يقرؤه المشتري وحده (order_secrets) — لا يراه البائع.
class _DeliveryCode extends StatelessWidget {
  final String orderId;
  final bool isCod;
  final String total;
  const _DeliveryCode({required this.orderId, required this.isCod, required this.total});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('order_secrets').doc(orderId).snapshots(),
      builder: (context, snap) {
        final code = (snap.data?.data()?['deliveryCode'] ?? '').toString();
        if (code.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.primary.withValues(alpha: 0.4)),
          ),
          child: Column(children: [
            Text('رمز التسليم', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            const SizedBox(height: 4),
            Text(code.split('').join(' '),
                textDirection: TextDirection.ltr,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 4, color: colors.primary)),
            const SizedBox(height: 6),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: QrImageView(
                data: deliveryQrPayload(orderId, code),
                version: QrVersions.auto,
                size: 150,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 6),
            Text('يمكن للبائع مسح هذا الباركود بدل كتابة الرمز',
                style: TextStyle(fontSize: 11, color: colors.textSecondary)),
            const SizedBox(height: 6),
            Text(
              isCod
                  ? 'تحقق من طلبك وادفع $total ثم أعطِ البائع هذا الرمز. لا تعطه قبل الاستلام.'
                  : 'تحقق من طلبك ثم أعطِ البائع هذا الرمز. لا تعطه قبل الاستلام.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, height: 1.5, color: colors.textSecondary),
            ),
          ]),
        );
      },
    );
  }
}
