// lib/screens/customer/checkout_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/notifications_service.dart';
import '../../utils/app_colors.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl   = TextEditingController();
  bool   _isLoading  = false;

  // ✅ موقع المشتري من الخريطة "lat,lng"
  String _locationLatLng = '';

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _nameCtrl.text  = user.name;
      _phoneCtrl.text = user.phone;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();   _phoneCtrl.dispose();
    _addressCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  // ── فتح خرائط جوجل لتحديد الموقع (يعيد lat,lng من رابط المشاركة) ──────────
  Future<void> _pickLocationOnMap() async {
    // نفتح Google Maps لتحديد الموقع
    // المستخدم يختار موقعه ثم يشارك الرابط/الإحداثيات
    // بما أننا لا نملك حزمة geolocator، نستخدم حل مبسّط:
    // نفتح Google Maps مع زر تحديد الموقع الحالي
    final uri = Uri.parse('https://maps.google.com/maps?q=&output=classic');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    // نعرض نافذة لإدخال الإحداثيات يدوياً بعد نسخها من Maps
    if (!mounted) return;
    _showCoordinatesDialog();
  }

  void _showCoordinatesDialog() {
    final colors = context.colors;

    // حقل واحد بصيغة "lat,lng" — نفس طريقة موقع المتجر
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
            onPressed: () { coordCtrl.dispose(); Navigator.pop(context); },
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
                  SnackBar(content: const Text('✅ تم تحديد موقعك'),
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

  Future<void> _confirmOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = context.read<AuthProvider>().currentUser!;
      final cart = context.read<CartProvider>();

      // ✅ إصلاح باغ تعدد العملات: التجميع الآن بمفتاح مركّب
      // "sellerId|currencySymbol" بدل sellerId فقط، حتى لو باع نفس البائع
      // منتجات بعملات مختلفة، يُنشأ طلب منفصل لكل عملة بمبلغ صحيح رياضياً.
      final Map<String, List<dynamic>> bySellerCurrency = {};
      for (final item in cart.items) {
        final key = '${item.sellerId}|${item.currencySymbol}';
        bySellerCurrency.putIfAbsent(key, () => []);
        bySellerCurrency[key]!.add(item);
      }

      for (final entry in bySellerCurrency.entries) {
        final items      = entry.value;
        final first       = items.first;
        final sellerId    = first.sellerId as String;
        final sellerName  = first.sellerName as String;
        final currencyCode   = first.currencyCode as String;
        final currencySymbol = first.currencySymbol as String;
        final total       = items.fold<double>(0.0, (acc, item) => acc + (item.total as double));

        final order = OrderModel(
          id:            '',
          customerId:    user.uid,
          customerName:  user.name,
          customerPhone: _phoneCtrl.text.trim(),
          sellerId:      sellerId,
          sellerName:    sellerName,
          products:      items.map((item) => OrderItem(
            productId: item.productId as String,
            name:      item.name      as String,
            quantity:  item.quantity  as int,
            price:     item.price     as double,
            image:     item.image     as String,
          )).toList(),
          totalAmount:  total,
          status:       OrderModel.pending,
          shippingAddress: ShippingAddress(
            fullName:       _nameCtrl.text.trim(),
            phone:          _phoneCtrl.text.trim(),
            address:        _addressCtrl.text.trim(),
            notes:          _notesCtrl.text.trim(),
            locationLatLng: _locationLatLng,   // ✅
          ),
          createdAt: DateTime.now(),
          currencyCode:   currencyCode,
          currencySymbol: currencySymbol,
        );

        final docRef = await FirebaseFirestore.instance
            .collection('orders')
            .add(order.toMap());

        await NotificationsService.notifyNewOrder(
          sellerId:     sellerId,
          customerName: user.name,
          orderId:      docRef.id,
          amount:       total,
        );
      }

      cart.clearCart();

      if (!mounted) return;
      Navigator.popUntil(context, (r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ تم تأكيد طلبك بنجاح!'),
          backgroundColor: context.colors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: context.colors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            // ── معلومات التوصيل ──────────────────────────────────────────────
            const _SectionTitle(title: 'معلومات التوصيل', icon: Icons.local_shipping_outlined),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                prefixIcon: Icon(Icons.person_outlined),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'أدخل الاسم' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'أدخل رقم الهاتف' : null,
            ),
            const SizedBox(height: 12),

            // ── حقل العنوان + زر الخريطة ─────────────────────────────────────
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
              validator: (v) => v == null || v.trim().isEmpty ? 'أدخل العنوان' : null,
            ),
            const SizedBox(height: 8),

            // ── زر تحديد الموقع على الخريطة ──────────────────────────────────
            OutlinedButton.icon(
              onPressed: _pickLocationOnMap,
              icon: Icon(
                _locationLatLng.isNotEmpty
                    ? Icons.location_on_rounded
                    : Icons.add_location_alt_outlined,
                color: _locationLatLng.isNotEmpty
                    ? colors.success : colors.primary,
              ),
              label: Text(
                _locationLatLng.isNotEmpty
                    ? '✅ تم تحديد الموقع — اضغط لتغييره'
                    : '📍 تحديد موقعك على الخريطة (اختياري)',
                style: TextStyle(
                  color: _locationLatLng.isNotEmpty
                      ? colors.success : colors.primary,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _locationLatLng.isNotEmpty
                      ? colors.success : colors.primary,
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

            // ── ملخص الطلب ───────────────────────────────────────────────────
            const _SectionTitle(title: 'ملخص الطلب', icon: Icons.receipt_outlined),
            const SizedBox(height: 12),

            ...cart.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text('${item.name} × ${item.quantity}',
                    style: const TextStyle(fontSize: 13))),
                Text(
                  '${item.total.toStringAsFixed(2)} ${item.currencySymbol}', // ✅ عملة صحيحة
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
                  border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: colors.warning),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    'ستُنشأ فاتورة منفصلة لكل عملة ضمن طلبك.',
                    style: TextStyle(fontSize: 11.5, color: colors.warning),
                  )),
                ]),
              ),
            ],
            ...cart.totalsByCurrency.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Text('الإجمالي (${e.key})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${e.value.toStringAsFixed(2)} ${e.key}',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.primary)),
              ]),
            )),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _confirmOrder,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 22, width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('تأكيد الطلب', style: TextStyle(fontSize: 16)),
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
    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  ]);
}
