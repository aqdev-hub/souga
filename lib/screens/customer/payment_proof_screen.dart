// lib/screens/customer/payment_proof_screen.dart
//
// ✅ شاشة إكمال الدفع عبر محفظة حاسب (المرحلة الأولى: إثبات يدوي).
// المشتري يحوّل المبلغ من تطبيق حاسب إلى حساب سوجا، ثم يُدخل رقم العملية
// ويرفع صورة الإيصال. مشرف المنصة يطابقها مع كشف الحساب ويؤكد الدفع.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/imagekit_service.dart';
import '../../services/orders_api.dart';
import '../../utils/app_colors.dart';
import '../../utils/order_ui.dart';

class PaymentProofScreen extends StatefulWidget {
  final List<String> paymentIds;
  const PaymentProofScreen({super.key, required this.paymentIds});

  @override
  State<PaymentProofScreen> createState() => _PaymentProofScreenState();
}

class _PaymentProofScreenState extends State<PaymentProofScreen> {
  OrdersConfig _config = const OrdersConfig();

  @override
  void initState() {
    super.initState();
    OrdersConfig.load().then((c) {
      if (mounted) setState(() => _config = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('إكمال الدفع عبر حاسب')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.info.withValues(alpha: 0.3)),
            ),
            child: Text(
              'حوّل المبلغ بالضبط من تطبيق حاسب إلى الحساب أدناه، واكتب «مرجع الدفع» في ملاحظة التحويل، '
              'ثم ارجع هنا وأدخل رقم العملية وارفع صورة الإيصال. '
              'مبلغك محجوز لدى سوجا ولا يُحوَّل للبائع إلا بعد تسليمك طلبك.',
              style: TextStyle(fontSize: 12.5, height: 1.6, color: colors.textPrimary),
            ),
          ),
          const SizedBox(height: 14),
          for (final id in widget.paymentIds) _PaymentCard(paymentId: id, config: _config),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatefulWidget {
  final String paymentId;
  final OrdersConfig config;
  const _PaymentCard({required this.paymentId, required this.config});

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  final _txCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  File? _image;
  bool _busy = false;
  bool _phoneInit = false;

  @override
  void dispose() {
    _txCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(OrderUi.snack(context, 'تم نسخ $what'));
  }

  Future<void> _pick() async {
    final f = await ImageKitService.pickImage();
    if (f != null && mounted) setState(() => _image = f);
  }

  Future<void> _submit() async {
    final tx = _txCtrl.text.trim();
    if (tx.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
          OrderUi.snack(context, 'أدخل رقم العملية كما يظهر في حاسب.', error: true));
      return;
    }
    setState(() => _busy = true);
    String proofUrl = '';
    if (_image != null) {
      proofUrl = await ImageKitService.uploadImage(_image!, 'payment_proofs') ?? '';
      if (proofUrl.isEmpty) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(OrderUi.snack(
            context, 'تعذّر رفع صورة الإيصال. أعد المحاولة أو أرسل رقم العملية فقط.', error: true));
        return;
      }
    }
    final res = await OrdersApi.submitProof(
      paymentId: widget.paymentId,
      transactionRef: tx,
      proofUrl: proofUrl,
      payerPhone: _phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(res.ok
        ? OrderUi.snack(context, 'تم إرسال الإثبات — سنراجعه ونؤكد الدفع قريباً')
        : OrderUi.snack(context, res.message, error: true));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cfg = widget.config;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .doc(widget.paymentId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final p = snap.data!.data();
        if (p == null) return const SizedBox.shrink();
        final status = (p['status'] ?? '').toString();
        final amount = (p['amount'] as num?)?.toDouble() ?? 0;
        final cur = (p['currencyCode'] ?? '').toString();
        final ref = (p['reference'] ?? '').toString();
        final created = (p['createdAt'] as Timestamp?)?.toDate();
        final due = created?.add(Duration(minutes: cfg.payHoldMinutes));
        final canSubmit = status == 'unpaid' || status == 'rejected';

        if (!_phoneInit) {
          _phoneInit = true;
          _phoneCtrl.text = context.read<AuthProvider>().currentUser?.phone ?? '';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.account_balance_wallet_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('المبلغ المطلوب: ${OrderUi.money(amount, cur)}',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: colors.primary)),
                ),
              ]),
              const SizedBox(height: 10),
              _copyRow('اسم الحساب', cfg.hasabName, colors),
              _copyRow('رقم الحساب / الجوال', cfg.hasabNumber, colors),
              _copyRow('مرجع الدفع (اكتبه في الملاحظة)', ref, colors),
              if (cfg.hasabNote.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(cfg.hasabNote,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              ],
              const Divider(height: 24),
              if (status == 'awaiting_verification')
                _banner(colors.info, Icons.hourglass_top_rounded,
                    'تم استلام إثبات الدفع (${p['transactionRef'] ?? ''}) وهو قيد المراجعة.'),
              if (status == 'verified')
                _banner(colors.success, Icons.verified_rounded,
                    'تم تأكيد دفعك — وصل طلبك إلى البائع.'),
              if (status == 'rejected')
                _banner(colors.error, Icons.error_outline,
                    'تعذّر التحقق: ${p['rejectReason'] ?? ''}. ارفع إثباتاً صحيحاً.'),
              if (canSubmit) ...[
                if (due != null && status == 'unpaid')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('⏳ ${OrderUi.remaining(due)} — وبعدها يُلغى الطلب تلقائياً',
                        style: TextStyle(fontSize: 12, color: colors.warning)),
                  ),
                TextField(
                  controller: _txCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'رقم العملية في حاسب',
                    prefixIcon: Icon(Icons.tag),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'رقم جوال الدافع (اختياري)',
                    prefixIcon: Icon(Icons.phone_outlined),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: Icon(_image == null ? Icons.add_photo_alternate_outlined : Icons.check_circle,
                      color: _image == null ? colors.primary : colors.success),
                  label: Text(_image == null ? 'إرفاق صورة الإيصال (يُفضّل)' : 'تم اختيار الصورة — اضغط للتغيير'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 46)),
                  child: _busy
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('إرسال إثبات الدفع'),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }

  Widget _banner(Color c, IconData icon, String text) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: c))),
        ]),
      );

  Widget _copyRow(String label, String value, SougaColors colors) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
            const SizedBox(height: 2),
            SelectableText(value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
        IconButton(
          tooltip: 'نسخ',
          icon: Icon(Icons.copy_rounded, size: 18, color: colors.primary),
          onPressed: () => _copy(value, label),
        ),
      ]),
    );
  }
}
