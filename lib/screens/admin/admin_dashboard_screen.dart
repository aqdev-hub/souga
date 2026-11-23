// lib/screens/admin/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import 'admin_users_screen.dart';
import 'admin_products_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_payments_screen.dart';
import 'admin_payouts_screen.dart';
import 'admin_paused_sellers_screen.dart';
import '../../services/otp_api.dart';
import 'admin_reviews_screen.dart';
import 'seed_data_screen.dart';
import 'category_schema_setup_screen.dart';
import 'package:flutter/services.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم المدير'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('إحصائيات المنصة',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _ClickableStatCard(
              title: 'المستخدمون',
              icon: Icons.people_outline,
              color: colors.primary,
              future: fs
                  .collection('users')
                  .count()
                  .get()
                  .then((s) => s.count ?? 0),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _ClickableStatCard(
              title: 'البائعون',
              icon: Icons.store_outlined,
              color: colors.accentDark,
              future: fs
                  .collection('users')
                  .where('role', isEqualTo: 'seller')
                  .count()
                  .get()
                  .then((s) => s.count ?? 0),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const AdminUsersScreen(filterRole: 'seller'))),
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _ClickableStatCard(
              title: 'المنتجات',
              icon: Icons.inventory_2_outlined,
              color: colors.info,
              future: fs
                  .collection('products')
                  .count()
                  .get()
                  .then((s) => s.count ?? 0),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminProductsScreen())),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _ClickableStatCard(
              title: 'الطلبات',
              icon: Icons.receipt_long_outlined,
              color: colors.success,
              future: fs
                  .collection('orders')
                  .count()
                  .get()
                  .then((s) => s.count ?? 0),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminOrdersScreen())),
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _ClickableStatCard(
              title: 'طلبات انتظار',
              icon: Icons.hourglass_empty,
              color: colors.warning,
              future: fs
                  .collection('orders')
                  .where('status', isEqualTo: 'pending')
                  .count()
                  .get()
                  .then((s) => s.count ?? 0),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const AdminOrdersScreen(filterStatus: 'pending'))),
            )),
            const SizedBox(width: 12),
            // ✅ التقييمات الآن قابلة للنقر
            Expanded(
                child: _ClickableStatCard(
              title: 'التقييمات',
              icon: Icons.star_outline,
              color: colors.accent,
              future: fs
                  .collection('reviews')
                  .count()
                  .get()
                  .then((s) => s.count ?? 0),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminReviewsScreen())),
            )),
          ]),
          const SizedBox(height: 24),
          // ✅ دورة الشراء: التحقق من دفعات حاسب + النزاعات + الاستردادات
          Card(
            child: ListTile(
              leading: Icon(Icons.fact_check_outlined, color: colors.primary),
              title: const Text('المدفوعات والنزاعات',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text(
                  'تأكيد دفعات حاسب، فصل النزاعات، تسجيل الاستردادات'),
              trailing: Icon(Icons.chevron_left, color: colors.textHint),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminPaymentsScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading:
                  Icon(Icons.mark_email_read_outlined, color: colors.primary),
              title: const Text('اختبار إرسال البريد',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text(
                  'يرسل رسالة تجريبية ويعرض رد مزوّد البريد وأي خلل في الإعداد'),
              trailing: Icon(Icons.chevron_left, color: colors.textHint),
              onTap: () => _mailTest(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.pause_circle_outline, color: colors.primary),
              title: const Text('بائعون موقوفون تلقائياً',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle:
                  const Text('تكرر تجاوزهم مهلة قبول الطلبات — استئناف المتجر'),
              trailing: Icon(Icons.chevron_left, color: colors.textHint),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminPausedSellersScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.account_balance_wallet_outlined,
                  color: colors.primary),
              title: const Text('مستحقات البائعين',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('الأرصدة المتاحة وتسجيل دفعات التحويل'),
              trailing: Icon(Icons.chevron_left, color: colors.textHint),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminPayoutsScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.dataset_outlined, color: colors.primary),
              title: const Text('البيانات التجريبية',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('إضافة أو حذف منتجات تجريبية'),
              trailing: Icon(Icons.chevron_left, color: colors.textHint),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SeedDataScreen())),
            ),
          ),
          const SizedBox(height: 8),
          // ✅ جديد — المرحلة 1 من Universal Product Engine (بيانات فقط،
          // لا تغيير على أي وظيفة موجودة). يُشغَّل مرة واحدة فقط.
          Card(
            child: ListTile(
              leading: Icon(Icons.account_tree_outlined, color: colors.primary),
              title: const Text('إعداد شجرة الفئات والخصائص',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle:
                  const Text('يُشغَّل مرة واحدة — أساس نظام المنتج الجديد'),
              trailing: Icon(Icons.chevron_left, color: colors.textHint),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CategorySchemaSetupScreen())),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ClickableStatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Future<int> future;
  final VoidCallback onTap;

  const _ClickableStatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.future,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: color, size: 28),
              const Spacer(),
              Icon(Icons.arrow_forward_ios,
                  size: 12, color: color.withValues(alpha: 0.5)),
            ]),
            const SizedBox(height: 10),
            FutureBuilder<int>(
              future: future,
              builder: (_, snap) => Text(
                snap.hasData ? '${snap.data}' : '...',
                style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(
                    fontSize: 13, color: context.colors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

/// اختبار البريد: يطلب بريداً (افتراضياً بريد المشرف) ثم يعرض النتيجة التفصيلية
Future<void> _mailTest(BuildContext context) async {
  final me = context.read<AuthProvider>().currentUser?.email ?? '';
  final ctrl = TextEditingController(text: me);
  final to = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('اختبار إرسال البريد'),
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.emailAddress,
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(labelText: 'أرسل رسالة تجريبية إلى'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('إرسال')),
      ],
    ),
  );
  ctrl.dispose();
  if (to == null || to.isEmpty || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  final r = await OtpApi.adminMailTest(to);
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // إغلاق المؤشر

  final cfg = (r['config'] is Map)
      ? Map<String, dynamic>.from(r['config'] as Map)
      : <String, dynamic>{};
  final problems = (cfg['problems'] is List)
      ? List<String>.from((cfg['problems'] as List).map((e) => '$e'))
      : <String>[];
  final ok = r['success'] == true;
  final buf = StringBuffer()
    ..writeln(
        ok ? '✅ قبل المزوّد الرسالة (تحقق من الوارد وSpam).' : '❌ فشل الإرسال.')
    ..writeln(
        'المزوّد: ${cfg['provider'] ?? '-'}   المرسل: ${cfg['from'] ?? '-'}');
  if (!ok) {
    buf.writeln('الرمز: HTTP ${r['httpStatus']}  ${r['error'] ?? ''}');
    if ((r['message'] ?? '').toString().isNotEmpty) {
      buf.writeln('${r['message']}');
    }
    if ((r['detail'] ?? '').toString().isNotEmpty) {
      buf.writeln('\nرد المزوّد:\n${r['detail']}');
    }
  }
  if (problems.isNotEmpty) {
    buf.writeln('\n⚠️ مشاكل في الإعداد:');
    for (final p in problems) {
      buf.writeln('• $p');
    }
  }
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('نتيجة الاختبار'),
      content: SingleChildScrollView(
          child: SelectableText(buf.toString(),
              style: const TextStyle(fontSize: 13, height: 1.5))),
      actions: [
        TextButton.icon(
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: buf.toString())),
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('نسخ'),
        ),
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
      ],
    ),
  );
}
