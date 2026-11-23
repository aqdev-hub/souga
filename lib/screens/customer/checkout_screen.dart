// lib/screens/customer/checkout_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/orders_api.dart';
import '../../utils/app_colors.dart';
import '../../utils/order_ui.dart';
import 'payment_proof_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isLoading = false;

  // ✅ موقع المشتري من الخريطة "lat,lng"
  String _locationLatLng = '';

  // ✅ دورة الشراء: إعدادات الطلبات + طريقة الدفع + مفتاح عدم التكرار
  OrdersConfig _config = const OrdersConfig();
  String _method = OrderModel.payCod;
  String _idemKey = OrdersApi.newIdempotencyKey();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _nameCtrl.text = user.name;
      _phoneCtrl.text = user.phone;
    }
    OrdersConfig.load().then((c) {
      if (!mounted) return;
      setState(() {
        _config = c;
        if (!c.codEnabled && c.hasabReady) _method = OrderModel.payHasab;
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── فتح خرائط جوجل لتحديد الموقع (يعيد lat,lng من رابط المشاركة) ──────────
  Future<void> _pickLocationOnMap() async {
    final uri = Uri.parse('https://maps.google.com/maps?q=&output=classic');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (!mounted) return;
    _showCoordinatesDialog();
  }

  void _showCoordinatesDialog() {
    final colors = context.colors;
    final coordCtrl = TextEditingController(text: _locationLatLng);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.location_on_rounded, color: colors.primary),
          const SizedBox(width: 8),
          const Text('موقع التوصيل', style: TextStyle(fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'افتح Google Maps → اضغط مطولاً على موقعك → انسخ الإحداثيات (مثال: 15.3694,44.1910)',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: coordCtrl,
            keyboardType: TextInputType.text,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'الإحداثيات  lat,lng',
              prefixIcon: Icon(Icons.location_on_outlined),
              hintText: '15.3694,44.1910',
              isDense: true,
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              coordCtrl.dispose();
              Navigator.pop(context);
            },
            child: Text('إلغاء', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = coordCtrl.text.trim();
              if (val.contains(',')) {
                setState(() => _locationLatLng = val);
                coordCtrl.dispose();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: const Text('✅ تم تحديد موقعك'),
                      backgroundColor: colors.success),
                );
              }
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 36)),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  /// عدد البائعين المختلفين في السلة (يحدد أهلية الدفع عند الاستلام).
  int _sellerCount(CartProvider cart) =>
      cart.items.map((i) => i.sellerId).toSet().length;

  bool _codAllowed(CartProvider cart) =>
      _config.codEnabled && _sellerCount(cart) <= _config.codMaxSellers;

  Future<void> _confirmOrder() async {
    if (!_formKey.currentState!.validate()) return;
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) return;
    if (_method == OrderModel.payCod && !_codAllowed(cart)) {
      ScaffoldMessenger.of(context).showSnackBar(
          OrderUi.snack(context, 'اختر طريقة دفع متاحة لطلبك.', error: true));
      return;
    }
    setState(() => _isLoading = true);

    // ✅ كل شيء يتم من السيرفر: يعيد حساب الأسعار من قاعدة البيانات ويحجز
    // المخزون بمعاملة ويقسّم الطلب حسب البائع والعملة. التطبيق يرسل فقط
    // (المنتج، الخيار، الكمية) — أي سعر يأتي من العميل يُتجاهل.
    final res = await OrdersApi.create(
      idempotencyKey: _idemKey,
      paymentMethod: _method,
      address: {
        'fullName': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'locationLatLng': _locationLatLng,
      },
      items: cart.items
          .map((i) => <String, dynamic>{
                'productId': i.productId,
                'variantId': i.variantId,
                'quantity': i.quantity,
              })
          .toList(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!res.ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(OrderUi.snack(context, res.message, error: true));
      return;
    }

    _idemKey = OrdersApi.newIdempotencyKey();
    cart.clearCart();

    final payments = (res.data['payments'] as List? ?? const [])
        .map((e) => (e as Map)['id'].toString())
        .toList();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final colors = context.colors;

    if (_method == OrderModel.payHasab && payments.isNotEmpty) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => PaymentProofScreen(paymentIds: payments)),
        (r) => r.isFirst,
      );
    } else {
      nav.popUntil((r) => r.isFirst);
    }
    messenger.showSnackBar(SnackBar(
      content: Text(_method == OrderModel.payHasab
          ? 'تم إنشاء طلبك — أكمل الدفع وارفع الإثبات'
          : '✅ تم إرسال طلبك إلى البائع'),
      backgroundColor: colors.success,
    ));
  }

  Widget _methodTile({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
  }) {
    final colors = context.colors;
    final selected = _method == value && enabled;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? () => setState(() => _method = value) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.06)
                : colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: selected ? colors.primary : colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                            height: 1.4)),
                  ]),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? colors.primary : colors.textHint,
              size: 20,
            ),
          ]),
        ),
      ),
    );
  }

  /// المجموع لكل عملة، مع رسوم الشحن (تُحتسب لكل بائع داخل العملة) إن ضُبطت.
  List<Widget> _totalsRows(CartProvider cart, SougaColors colors) {
    final byCode = <String, List<dynamic>>{};
    for (final i in cart.items) {
      byCode.putIfAbsent(i.currencyCode, () => []).add(i);
    }
    final rows = <Widget>[];
    for (final e in byCode.entries) {
      final symbol = e.value.first.currencySymbol as String;
      final subtotal =
          e.value.fold<double>(0, (a, i) => a + (i.total as double));
      final sellers = e.value.map((i) => i.sellerId).toSet().length;
      final fee = (_config.shippingFee[e.key] ?? 0) * sellers;
      Widget line(String label, String value, {bool bold = false}) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Text(label,
                  style: TextStyle(
                      fontSize: bold ? 15 : 13,
                      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                      color: bold ? null : colors.textSecondary)),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      fontSize: bold ? 17 : 13,
                      fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                      color: bold ? colors.primary : null)),
            ]),
          );
      if (fee > 0) {
        rows.add(line('المجموع ($symbol)', OrderUi.money(subtotal, symbol)));
        rows.add(line(
            'رسوم التوصيل ($sellers ${sellers == 1 ? 'بائع' : 'بائعين'})',
            OrderUi.money(fee, symbol)));
      }
      rows.add(line('الإجمالي ($symbol)', OrderUi.money(subtotal + fee, symbol),
          bold: true));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('إتمام الطلب'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionTitle(
                title: 'معلومات التوصيل', icon: Icons.local_shipping_outlined),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                prefixIcon: Icon(Icons.person_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'أدخل الاسم' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'أدخل رقم الهاتف' : null,
            ),
            const SizedBox(height: 12),
            const Text('عنوان التوصيل',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'العنوان بالتفصيل',
                prefixIcon: Icon(Icons.location_on_outlined),
                hintText: 'المنطقة، الشارع، رقم المبنى...',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'أدخل العنوان' : null,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickLocationOnMap,
              icon: Icon(
                _locationLatLng.isNotEmpty
                    ? Icons.location_on_rounded
                    : Icons.add_location_alt_outlined,
                color: _locationLatLng.isNotEmpty
                    ? colors.success
                    : colors.primary,
              ),
              label: Text(
                _locationLatLng.isNotEmpty
                    ? '✅ تم تحديد الموقع — اضغط لتغييره'
                    : '📍 تحديد موقعك على الخريطة (اختياري)',
                style: TextStyle(
                  color: _locationLatLng.isNotEmpty
                      ? colors.success
                      : colors.primary,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _locationLatLng.isNotEmpty
                      ? colors.success
                      : colors.primary,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات إضافية (اختياري)',
                prefixIcon: Icon(Icons.note_outlined),
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle(
                title: 'طريقة الدفع', icon: Icons.payments_outlined),
            const SizedBox(height: 12),
            _methodTile(
              value: OrderModel.payCod,
              icon: Icons.money_outlined,
              title: 'الدفع عند الاستلام',
              subtitle: !_config.codEnabled
                  ? 'غير متاح حالياً'
                  : (_sellerCount(cart) > _config.codMaxSellers
                      ? 'متاح لحد أقصى ${_config.codMaxSellers} بائعين في الطلب — اختر حاسب أو قسّم طلبك'
                      : 'ادفع نقداً عند وصول طلبك. أعطِ البائع رمز التسليم بعد التحقق من طلبك.'),
              enabled: _codAllowed(cart),
            ),
            _methodTile(
              value: OrderModel.payHasab,
              icon: Icons.account_balance_wallet_outlined,
              title: 'محفظة حاسب (الكريمي)',
              subtitle: _config.hasabReady
                  ? 'حوّل المبلغ من تطبيق حاسب وارفع إثبات الدفع خلال ${_config.payHoldMinutes} دقيقة. مبلغك محجوز لدى سوجا ولا يصل البائع إلا بعد تسليمك طلبك.'
                  : 'غير متاح حالياً',
              enabled: _config.hasabReady,
            ),
            const SizedBox(height: 12),
            const _SectionTitle(
                title: 'ملخص الطلب', icon: Icons.receipt_outlined),
            const SizedBox(height: 12),
            ...cart.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.name} × ${item.quantity}',
                                    style: const TextStyle(fontSize: 13)),
                                // ✅ عرض خيارات التركيبة المختارة (إن وُجدت) تحت اسم المنتج
                                if (item.variantOptionValues != null &&
                                    item.variantOptionValues!.isNotEmpty)
                                  Text(
                                    item.variantOptionValues!.entries
                                        .map((e) => '${e.key}: ${e.value}')
                                        .join(' • '),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colors.textSecondary),
                                  ),
                              ]),
                        ),
                        Text(
                          '${item.total.toStringAsFixed(2)} ${item.currencySymbol}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ]),
                )),
            const Divider(height: 24),
            if (cart.hasMixedCurrencies) ...[
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: colors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: colors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(
                    'ستُنشأ فاتورة منفصلة لكل عملة ضمن طلبك.',
                    style: TextStyle(fontSize: 11.5, color: colors.warning),
                  )),
                ]),
              ),
            ],
            ..._totalsRows(cart, colors),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _confirmOrder,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      _method == OrderModel.payHasab
                          ? 'تأكيد الطلب ومتابعة الدفع'
                          : 'تأكيد الطلب',
                      style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: context.colors.primary, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]);
}
