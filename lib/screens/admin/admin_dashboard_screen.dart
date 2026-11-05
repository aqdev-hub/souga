// lib/screens/admin/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import 'admin_users_screen.dart';
import 'admin_products_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_reviews_screen.dart';
import 'seed_data_screen.dart';
import 'category_schema_setup_screen.dart';

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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _ClickableStatCard(
              title: 'المستخدمون', icon: Icons.people_outline, color: colors.primary,
              future: fs.collection('users').count().get().then((s) => s.count ?? 0),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
            )),
            const SizedBox(width: 12),
            Expanded(child: _ClickableStatCard(
              title: 'البائعون', icon: Icons.store_outlined, color: colors.accentDark,
              future: fs.collection('users').where('role', isEqualTo: 'seller')
                  .count().get().then((s) => s.count ?? 0),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AdminUsersScreen(filterRole: 'seller'))),
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _ClickableStatCard(
              title: 'المنتجات', icon: Icons.inventory_2_outlined, color: colors.info,
              future: fs.collection('products').count().get().then((s) => s.count ?? 0),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminProductsScreen())),
            )),
            const SizedBox(width: 12),
            Expanded(child: _ClickableStatCard(
              title: 'الطلبات', icon: Icons.receipt_long_outlined, color: colors.success,
              future: fs.collection('orders').count().get().then((s) => s.count ?? 0),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminOrdersScreen())),
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _ClickableStatCard(
              title: 'طلبات انتظار', icon: Icons.hourglass_empty, color: colors.warning,
              future: fs.collection('orders').where('status', isEqualTo: 'pending')
                  .count().get().then((s) => s.count ?? 0),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AdminOrdersScreen(filterStatus: 'pending'))),
            )),
            const SizedBox(width: 12),
            // ✅ التقييمات الآن قابلة للنقر
            Expanded(child: _ClickableStatCard(
              title: 'التقييمات', icon: Icons.star_outline, color: colors.accent,
              future: fs.collection('reviews').count().get().then((s) => s.count ?? 0),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminReviewsScreen())),
            )),
          ]),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: Icon(Icons.dataset_outlined, color: colors.primary),
              title: const Text('البيانات التجريبية', style: TextStyle(fontWeight: FontWeight.bold)),
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
              title: const Text('إعداد شجرة الفئات والخصائص', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('يُشغَّل مرة واحدة — أساس نظام المنتج الجديد'),
              trailing: Icon(Icons.chevron_left, color: colors.textHint),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CategorySchemaSetupScreen())),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: color, size: 28),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 12, color: color.withValues(alpha: 0.5)),
            ]),
            const SizedBox(height: 10),
            FutureBuilder<int>(
              future: future,
              builder: (_, snap) => Text(
                snap.hasData ? '${snap.data}' : '...',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 13, color: context.colors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}
