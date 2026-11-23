// lib/screens/seller/seller_orders_screen.dart
//
// ✅ طلبات البائع — كل الإجراءات تمر عبر السيرفر (OrdersApi):
//   قبول/رفض ← شحن ← تسليم برمز المشتري ← (فشل تسليم) ← (رد على نزاع).
// لا يستطيع البائع قبول طلب لم يدفعه المشتري (حاسب)، ولا يرى رمز التسليم.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/orders_api.dart';
import '../../utils/app_colors.dart';
import '../../utils/order_ui.dart';
import '../shared/chat_screen.dart';
import 'delivery_scan_screen.dart';

class SellerOrdersScreen extends StatefulWidget {
  final String? filterStatus;
  const SellerOrdersScreen({super.key, this.filterStatus});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  @override
  void initState() {
    super.initState();
    OrdersApi.sweep(); // تنفيذ المهل المنتهية (قبول/شحن/حماية)
  }

  String _filterTitle(String s) {
    switch (s) {
      case 'pending': return 'جديدة';
      case 'confirmed': return 'قيد التجهيز';
      case 'shipped': return 'في الطريق';
      case 'delivered': return 'مسلّمة ومكتملة';
      case 'cancelled': return 'ملغاة';
      default: return s;
    }
  }

  Query _query(String uid) {
    Query q = FirebaseFirestore.instance.collection('orders').where('sellerId', isEqualTo: uid);
    final f = widget.filterStatus;
    if (f == 'delivered') {
      q = q.where('status', whereIn: ['delivered', 'completed']);
    } else if (f != null && f.isNotEmpty) {
      q = q.where('status', isEqualTo: f);
    }
    return q.orderBy('createdAt', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final colors = context.colors;
    final f = widget.filterStatus;

    return Scaffold(
      appBar: AppBar(
        title: Text(f != null && f.isNotEmpty ? 'طلبات: ${_filterTitle(f)}' : 'الطلبات'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _query(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('تعذّر تحميل الطلبات', style: TextStyle(color: colors.textSecondary)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.receipt_long_outlined, size: 80, color: colors.border),
              const SizedBox(height: 16),
              Text(f != null ? 'لا توجد طلبات بهذه الحالة' : 'لا توجد طلبات بعد',
                  style: TextStyle(fontSize: 16, color: colors.textSecondary)),
            ]));
          }
          final orders = snapshot.data!.docs
              .map((d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (_, i) => _SellerOrderCard(order: orders[i]),
          );
        },
      ),
    );
  }
}

class _SellerOrderCard extends StatefulWidget {
  final OrderModel order;
  const _SellerOrderCard({required this.order});
  @override
  State<_SellerOrderCard> createState() => _SellerOrderCardState();
}

class _SellerOrderCardState extends State<_SellerOrderCard> {
  bool _busy = false;
  OrderModel get o => widget.order;

  // إزالة أصناف: قبل الشحن، بعد تأكيد الدفع (أو عند الاستلام)، وبشرط وجود أكثر من صنف
  bool get _canRemoveLines =>
      o.products.length > 1 &&
      (o.paymentStatus == 'paid_held' || o.paymentStatus == 'cod_pending');

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

  Future<String?> _askText(String title, String label, {int min = 2, String? hint}) async {
    final ctrl = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('رجوع')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().length >= min) Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return r;
  }

  Future<void> _reject() async {
    final reason = await _askText(
        o.status == OrderModel.pending ? 'رفض الطلب' : 'إلغاء الطلب', 'السبب (يراه المشتري)',
        hint: 'مثال: نفد المخزون');
    if (reason == null) return;
    await _run(() => OrdersApi.cancel(o.id, reason: reason), 'تم إلغاء الطلب وإعادة المخزون');
  }

  /// إزالة صنف/أصناف غير متوفرة مع إبقاء بقية الطلب
  Future<void> _removeLines() async {
    final selected = <int>{};
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final remaining = o.products.length - selected.length;
          return AlertDialog(
            title: const Text('إزالة أصناف غير متوفرة'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('اختر الأصناف التي لا تستطيع توفيرها. يبقى باقي الطلب كما هو، ويُعاد حساب الإجمالي'
                    '${o.isHasab ? '، ويُرد للمشتري ثمن المُزال' : ''}.',
                    style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 8),
                for (var i = 0; i < o.products.length; i++)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(i),
                    onChanged: (v) => setS(() => v == true ? selected.add(i) : selected.remove(i)),
                    title: Text(o.products[i].name, style: const TextStyle(fontSize: 13.5)),
                    subtitle: Text('${o.products[i].quantity} × ${OrderUi.money(o.products[i].price, o.currencySymbol)}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'السبب (يراه المشتري)', hintText: 'مثال: نفد المخزون', isDense: true),
                ),
                if (remaining < 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('لا يمكن إزالة كل الأصناف — استخدم «رفض/إلغاء» بدلاً من ذلك.',
                        style: TextStyle(fontSize: 12, color: context.colors.error)),
                  ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
              TextButton(
                onPressed: (selected.isNotEmpty && remaining >= 1 && reasonCtrl.text.trim().length >= 2)
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: const Text('إزالة'),
              ),
            ],
          );
        },
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (ok != true) return;
    await _run(() => OrdersApi.removeLines(o.id, indexes: selected.toList()..sort(), reason: reason),
        'تمت إزالة الأصناف وتحديث الإجمالي');
  }

  Future<void> _ship() async {
    String method = 'seller';
    final trackCtrl = TextEditingController();
    final carrierCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('شحن الطلب'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: method,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'طريقة التوصيل', isDense: true),
              items: const [
                DropdownMenuItem(value: 'seller', child: Text('أوصّله بنفسي')),
                DropdownMenuItem(value: 'courier', child: Text('مندوب')),
                DropdownMenuItem(value: 'carrier', child: Text('شركة نقل')),
              ],
              onChanged: (v) => setS(() => method = v ?? method),
            ),
            if (method == 'carrier') ...[
              const SizedBox(height: 10),
              TextField(controller: carrierCtrl,
                  decoration: const InputDecoration(labelText: 'اسم شركة النقل', isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: trackCtrl,
                  decoration: const InputDecoration(labelText: 'رقم التتبع (اختياري)', isDense: true)),
            ],
            const SizedBox(height: 10),
            Text('عند التسليم سيعطيك المشتري رمزاً من 4 أرقام تدخله لإتمام التسليم.',
                style: TextStyle(fontSize: 11.5, color: ctx.colors.textSecondary)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تم الشحن')),
        ],
      )),
    );
    final track = trackCtrl.text.trim();
    final carrier = carrierCtrl.text.trim();
    trackCtrl.dispose();
    carrierCtrl.dispose();
    if (ok == true) {
      await _run(() => OrdersApi.ship(o.id,
          deliveryMethod: method, trackingNumber: track, carrierName: carrier), 'تم تحديث الحالة: في الطريق');
    }
  }

  Future<void> _deliver() async {
    final ctrl = TextEditingController();
    // '__scan__' = اختار البائع مسح الباركود
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد التسليم'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(o.isCod
              ? 'حصّل ${OrderUi.money(o.totalAmount, o.currencySymbol)} من المشتري ثم امسح باركود التسليم من هاتفه أو أدخل الرمز.'
              : 'امسح باركود التسليم من هاتف المشتري بعد استلامه طلبه، أو أدخل الرمز يدوياً.',
              style: const TextStyle(fontSize: 13, height: 1.5)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, '__scan__'),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('مسح الباركود'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('أو أدخل الرمز', style: TextStyle(fontSize: 12, color: ctx.colors.textSecondary)),
            ),
            const Expanded(child: Divider()),
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(counterText: '', hintText: '••••'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('رجوع')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().length == 4) Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || !mounted) return;

    String? code = result;
    if (result == '__scan__') {
      code = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => DeliveryScanScreen(orderId: o.id)),
      );
      if (code == null || !mounted) return; // اختار الإدخال اليدوي/رجع
    }
    await _run(() => OrdersApi.deliver(o.id, code!), 'تم التسليم ✅');
  }

  Future<void> _failDelivery() async {
    String reason = 'unreachable';
    bool isFinal = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('تعذّر التسليم'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: reason,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'السبب', isDense: true),
              items: OrderUi.failReasons.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setS(() => reason = v ?? reason),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إنهاء الطلب نهائياً', style: TextStyle(fontSize: 13)),
              subtitle: Text('وإلا تُسجَّل المحاولة ويبقى الطلب لمحاولة ثانية',
                  style: TextStyle(fontSize: 11, color: ctx.colors.textSecondary)),
              value: isFinal,
              onChanged: (v) => setS(() => isFinal = v),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('تسجيل', style: TextStyle(color: ctx.colors.error)),
          ),
        ],
      )),
    );
    if (ok == true) {
      await _run(() => OrdersApi.failDelivery(o.id, reason: reason, isFinal: isFinal), 'تم تسجيل المحاولة');
    }
  }

  Future<void> _replyDispute() async {
    final msg = await _askText('الرد على المشكلة', 'ردّك (يراه المشتري والإدارة)', min: 2);
    if (msg == null) return;
    await _run(() => OrdersApi.replyDispute(o.id, msg), 'تم إرسال ردّك');
  }

  Future<void> _openBuyerLocation(String latLng) async {
    if (latLng.isEmpty) return;
    final clean = latLng.replaceAll(' ', '');
    final parts = clean.split(',');
    final gmaps = Uri.parse('https://maps.google.com/?q=$clean');
    if (await canLaunchUrl(gmaps)) {
      await launchUrl(gmaps, mode: LaunchMode.externalApplication);
    } else if (parts.length == 2) {
      final osm = Uri.parse(
          'https://www.openstreetmap.org/?mlat=${parts[0]}&mlon=${parts[1]}#map=15/${parts[0]}/${parts[1]}');
      await launchUrl(osm, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _chat() async {
    final user = context.read<AuthProvider>().currentUser;
    final messenger = ScaffoldMessenger.of(context);
    if (user == null) return;
    if (o.customerId.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('بيانات المشتري غير متاحة لهذا الطلب')));
      return;
    }
    try {
      final roomId = await ChatService.getOrCreateRoom(
        myUid: user.uid,
        myName: user.storeName.isNotEmpty ? user.storeName : user.name,
        myImage: user.storeLogo.isNotEmpty ? user.storeLogo : user.profileImage,
        otherUid: o.customerId, otherName: o.customerName, otherImage: '',
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(roomId: roomId, otherName: o.customerName, otherImage: ''),
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
              child: Text(o.statusArabic,
                  style: TextStyle(color: sc, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.person_outlined, size: 14, color: colors.textSecondary),
            const SizedBox(width: 4),
            Flexible(child: Text(o.customerName,
                style: TextStyle(color: colors.textSecondary, fontSize: 13))),
            const SizedBox(width: 12),
            Icon(Icons.phone_outlined, size: 14, color: colors.textSecondary),
            const SizedBox(width: 4),
            Text(o.customerPhone, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          ]),
          const SizedBox(height: 6),
          // ✅ Variant-aware: خيارات التركيبة المشتراة (Snapshot ثابت وقت الطلب)
          ...o.products.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('• ${p.name} × ${p.quantity}',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary)),
              if (p.variantOptions != null && p.variantOptions!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    p.variantOptions!.entries.map((e) => '${e.key}: ${e.value}').join(' • '),
                    style: TextStyle(fontSize: 11, color: colors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
            ]),
          )),
          const SizedBox(height: 8),
          if (o.shippingAddress.address.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.location_on_outlined, size: 14, color: colors.textSecondary),
              const SizedBox(width: 4),
              Expanded(child: Text(o.shippingAddress.address,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary))),
              if (o.shippingAddress.locationLatLng.isNotEmpty)
                InkWell(
                  onTap: () => _openBuyerLocation(o.shippingAddress.locationLatLng),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.map_rounded, size: 13, color: colors.primary),
                      const SizedBox(width: 3),
                      Text('خريطة', style: TextStyle(fontSize: 11, color: colors.primary)),
                    ]),
                  ),
                ),
            ]),
            if (o.shippingAddress.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('ملاحظة: ${o.shippingAddress.notes}',
                    style: TextStyle(fontSize: 11.5, color: colors.textHint)),
              ),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Text(OrderUi.money(o.totalAmount, o.currencySymbol),
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary, fontSize: 16)),
            const Spacer(),
            Icon(o.isHasab ? Icons.account_balance_wallet_outlined : Icons.payments_outlined,
                size: 15, color: colors.textSecondary),
            const SizedBox(width: 4),
            Text(o.paymentMethodArabic, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          ]),
          if (o.paymentStatusArabic.isNotEmpty)
            Text('الدفع: ${o.paymentStatusArabic}', style: TextStyle(fontSize: 11.5, color: colors.textHint)),

          ..._notes(colors),
          if (o.status == OrderModel.disputed) _DisputeInfo(orderId: o.id),

          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _btn('تواصل', Icons.chat_bubble_outline, colors.accent, _chat),
            if (o.status == OrderModel.pending && !o.awaitingBuyerPayment) ...[
              _btn('قبول', Icons.check_rounded, colors.info,
                  () => _run(() => OrdersApi.accept(o.id), 'تم قبول الطلب')),
              _btn('رفض', Icons.close_rounded, colors.error, _reject),
              if (_canRemoveLines)
                _btn('إزالة صنف', Icons.remove_shopping_cart_outlined, colors.warning, _removeLines),
            ],
            if (o.status == OrderModel.confirmed) ...[
              if (_canRemoveLines)
                _btn('إزالة صنف', Icons.remove_shopping_cart_outlined, colors.warning, _removeLines),
              _btn('شحن', Icons.local_shipping_outlined, colors.primary, _ship),
              _btn('إلغاء', Icons.close_rounded, colors.error, _reject),
            ],
            if (o.status == OrderModel.shipped) ...[
              _btn('تسليم برمز', Icons.pin_outlined, colors.success, _deliver),
              _btn('تعذّر التسليم', Icons.assignment_return_outlined, colors.error, _failDelivery),
            ],
            if (o.status == OrderModel.disputed)
              _btn('الرد على المشكلة', Icons.reply_rounded, colors.warning, _replyDispute),
          ]),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        ]),
      ),
    );
  }

  List<Widget> _notes(SougaColors colors) {
    Widget note(Color c, IconData icon, String t) => Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 17, color: c),
            const SizedBox(width: 8),
            Expanded(child: Text(t, style: TextStyle(fontSize: 12.5, height: 1.5, color: colors.textPrimary))),
          ]),
        );

    switch (o.status) {
      case OrderModel.pending:
        if (o.awaitingBuyerPayment) {
          return [note(colors.textSecondary, Icons.hourglass_bottom,
              'بانتظار دفع المشتري عبر حاسب. لا تجهّز الطلب قبل أن يصلك إشعار تأكيد الدفع.')];
        }
        return [note(colors.warning, Icons.timer_outlined,
            'بانتظار قبولك. ${OrderUi.remaining(o.acceptDueAt)} — وإلا يُلغى تلقائياً ويُحسب عليك.')];
      case OrderModel.confirmed:
        return [note(colors.info, Icons.inventory_2_outlined,
            'جهّز الطلب واشحنه. ${OrderUi.remaining(o.shipDueAt)}${o.isHasab ? '\nالمبلغ محجوز لدى سوجا ويُحرَّر لك بعد التسليم وانتهاء مهلة الحماية.' : ''}')];
      case OrderModel.shipped:
        return [note(colors.primary, Icons.pin_outlined,
            'عند وصولك للمشتري اطلب منه رمز التسليم (4 أرقام).${o.deliveryAttempts > 0 ? ' محاولات خاطئة: ${o.deliveryAttempts}.' : ''}')];
      case OrderModel.delivered:
        return [note(colors.success, Icons.verified_outlined,
            'تم التسليم. ${o.isHasab ? 'تُحرَّر مستحقاتك بعد انتهاء مهلة الحماية' : 'يُغلق الطلب بعد انتهاء مهلة الحماية'}${o.protectionUntil != null ? ' (${OrderUi.dateTime(o.protectionUntil!)})' : ''}.')];
      case OrderModel.cancelled:
        return [note(colors.error, Icons.cancel_outlined,
            'أُلغي الطلب${o.cancelReason.isNotEmpty ? ': ${o.cancelReason}' : ''}.')];
      case OrderModel.deliveryFailed:
        return [note(colors.error, Icons.assignment_return_outlined, 'تعذّر تسليم الطلب وأُعيد المخزون.')];
      case OrderModel.completed:
        return o.paymentStatus == 'released'
            ? [note(colors.success, Icons.account_balance_wallet_outlined, 'تم تحرير مستحقات هذا الطلب إلى رصيدك.')]
            : [];
    }
    return [];
  }

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : onTap,
      icon: Icon(icon, size: 15, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 36),
      ),
    );
  }
}

/// تفاصيل مشكلة المشتري (disputes/{orderId}) للبائع.
class _DisputeInfo extends StatelessWidget {
  final String orderId;
  const _DisputeInfo({required this.orderId});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('disputes').doc(orderId).snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data();
        if (d == null) return const SizedBox.shrink();
        final reason = OrderUi.disputeReasons[d['reason']] ?? (d['reason'] ?? '').toString();
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مشكلة المشتري: $reason', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text((d['details'] ?? '').toString(), style: const TextStyle(fontSize: 12.5, height: 1.5)),
            if ((d['sellerReply'] ?? '').toString().isNotEmpty) ...[
              const Divider(height: 16),
              Text('ردّك: ${d['sellerReply']}', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
            ],
          ]),
        );
      },
    );
  }
}
