// lib/screens/admin/admin_products_screen.dart
//
// ✅ Universal Product Engine — زر تعديل المنتج أصبح يفتح
// `ProductFormStepperScreen` نفسها المستخدَمة للبائع (بموافقة صريحة) —
// بدل BottomSheet التعديل المحدود القديم (اسم/وصف/صور/نسبة ظهور فقط).
// فرق الصلاحيات (الأدمن يستطيع تعديل منتج أي بائع) محسوم بالكامل عبر
// firestore.rules (isAdmin()) بلا أي فرع كود إضافي هنا — الشاشة الجديدة
// تحافظ تلقائياً على sellerId/sellerName الأصليين للمنتج عند التعديل
// (راجع AddEditProductController._hydrateFromExistingProduct).
//
// ⚠️ ملاحظة: _UploadImageButton (كانت تُستخدَم حصرياً داخل BottomSheet
// التعديل القديم) أُزيلت هنا كتنظيف Dead Code تبعاً لهذا الاستبدال.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../services/imagekit_service.dart';
import '../../services/marketing_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/seo_rebuild_service.dart';
import '../../services/share_options_sheet.dart'
    show showShareOptionsSheet, ShareProductData;
import '../../utils/app_colors.dart';
import '../seller/product_form_stepper_screen.dart';

// ── أسماء التصنيفات بالعربية — تُستخدم فقط لبناء سياق إعلان الذكاء الاصطناعي ──
const List<Map<String, String>> _kAdminProductCategories = [
  {'id': 'electronics', 'name': 'إلكترونيات'},
  {'id': 'clothes',     'name': 'ملابس'},
  {'id': 'food',        'name': 'طعام'},
  {'id': 'home',        'name': 'منزل'},
  {'id': 'sports',      'name': 'رياضة'},
  {'id': 'books',       'name': 'كتب'},
  {'id': 'other',       'name': 'أخرى'},
  {'id': 'perfumes',    'name': 'عطور'},
  {'id': 'accessories', 'name': 'اكسسوارات'},
];

String _categoryDisplayName(String id) {
  final match = _kAdminProductCategories.firstWhere(
    (c) => c['id'] == id,
    orElse: () => {'id': id, 'name': id},
  );
  return match['name'] ?? id;
}

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});
  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery    = '';
  String _filterCategory = '';

  final List<Map<String, String>> _categories = [
    {'id': '',            'name': 'الكل'},
    {'id': 'electronics', 'name': 'إلكترونيات'},
    {'id': 'clothes',     'name': 'ملابس'},
    {'id': 'food',        'name': 'طعام'},
    {'id': 'home',        'name': 'منزل'},
    {'id': 'sports',      'name': 'رياضة'},
    {'id': 'books',       'name': 'كتب'},
    {'id': 'other',       'name': 'أخرى'},
    {'id': 'perfumes',    'name': 'عطور'},
    {'id': 'accessories', 'name': 'اكسسوارات'},
  ];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المنتجات')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو اسم البائع...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        })
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final cat      = _categories[i];
                  final selected = _filterCategory == cat['id'];
                  return GestureDetector(
                    onTap: () => setState(() => _filterCategory = cat['id']!),
                    child: Container(
                      margin:  const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? colors.primary : colors.background,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: selected ? colors.primary : colors.border),
                      ),
                      child: Text(cat['name']!,
                          style: TextStyle(
                            fontSize:   13,
                            color:      selected ? Colors.white : colors.textPrimary,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          )),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: (() {
              Query q = FirebaseFirestore.instance.collection('products');
              if (_filterCategory.isNotEmpty) {
                q = q.where('category', isEqualTo: _filterCategory);
              }
              return q.orderBy('createdAt', descending: true).snapshots();
            })(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Center(child: Text('لا توجد منتجات'));
              }

              var products = snap.data!.docs
                  .map((d) => ProductModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                  .toList();

              if (_searchQuery.isNotEmpty) {
                products = products.where((p) =>
                  p.name.toLowerCase().contains(_searchQuery) ||
                  p.sellerName.toLowerCase().contains(_searchQuery)
                ).toList();
              }

              if (products.isEmpty) { return const Center(child: Text('لا توجد نتائج')); }

              return ListView.builder(
                padding:   const EdgeInsets.symmetric(horizontal: 12),
                itemCount: products.length,
                itemBuilder: (_, i) => _ProductAdminCard(product: products[i]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ProductAdminCard extends StatelessWidget {
  final ProductModel product;
  const _ProductAdminCard({required this.product});

  Future<void> _delete(BuildContext context) async {
    final colors = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('حذف "${product.name}"؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('حذف', style: TextStyle(color: colors.error))),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .delete();
      // ✅ إعادة بناء صفحات SEO الثابتة في الخلفية بعد الحذف.
      unawaited(SeoRebuildService.triggerRebuild(reason: 'product_deleted_by_admin:${product.id}'));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('✅ تم حذف المنتج'),
              backgroundColor: colors.success));
      }
    }
  }

  // ✅ استُبدلت BottomSheet التعديل المحدودة القديمة (اسم/وصف/صور/نسبة
  // ظهور فقط) بالشاشة الكاملة الموحَّدة — الأدمن يقدر الآن يعدّل الفئة/
  // السعر/المواصفات/المتغيرات لأي منتج، وليس فقط الحقول المحدودة سابقاً.
  void _editProduct(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ProductFormStepperScreen(product: product),
    ));
  }

  // ── فتح شاشة الإعلان التسويقي بالذكاء الاصطناعي ─────────────────────────
  void _openMarketingAd(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MarketingAdScreen(
        productId:          product.id,
        productName:        product.name,
        productDescription: product.description,
        productPrice:       product.price.toStringAsFixed(2),
        storeName:          product.sellerName,
        category:           _categoryDisplayName(product.category),
        productImageUrl:    product.firstImage.isNotEmpty
            ? ImageKitService.productUrl(product.firstImage) : '',
        currencyCode:       product.currencyCode,
      ),
    ));
  }

  // ── ✅ حملة إشعارات يدوية لهذا المنتج ────────────────────────────
  void _openNotificationCampaign(BuildContext context) {
    final colors = context.colors;
    final titleCtrl = TextEditingController(text: '🛍️ ${product.name}');
    final bodyCtrl  = TextEditingController(
        text: product.description.isNotEmpty
            ? (product.description.length > 100
                ? '${product.description.substring(0, 100)}...'
                : product.description)
            : 'تسوّق الآن من ${product.sellerName}');
    bool isSending = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.notifications_active_outlined, color: colors.primary),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('حملة إشعار', style: TextStyle(fontSize: 16))),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('سيصل هذا الإشعار لكل المستخدمين المسجّلين لديهم إذن استقبال إشعارات.',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'عنوان الإشعار', prefixIcon: Icon(Icons.title_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'نص الإشعار', prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: isSending ? null : () async {
                setDialogState(() => isSending = true);
                final result = await PushNotificationService.sendProductNotification(
                  productId: product.id,
                  title: titleCtrl.text,
                  body:  bodyCtrl.text,
                );
                if (!dialogCtx.mounted) { return; }
                Navigator.pop(dialogCtx);
                if (!context.mounted) { return; }
                if (result.isSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result.totalTokens == 0
                        ? 'لا يوجد مستخدمون لديهم إشعارات مفعّلة بعد'
                        : '✅ وصل الإشعار إلى ${result.sent} من ${result.totalTokens} مستخدم'),
                    backgroundColor: colors.success,
                  ));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('❌ تعذر إرسال الإشعار: ${result.errorMessage ?? ""}'),
                    backgroundColor: colors.error,
                  ));
                }
              },
              icon: isSending
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(isSending ? 'جاري الإرسال...' : 'إرسال'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: product.firstImage.isNotEmpty
              ? Image.network(
                  ImageKitService.productAdminUrl(product.firstImage),
                  width: 52, height: 52, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 52, height: 52, color: colors.border,
                    child: const Icon(Icons.image_outlined)))
              : Container(
                  width: 52, height: 52, color: colors.border,
                  child: Icon(Icons.image_outlined,
                      color: colors.textHint)),
        ),
        title: Text(product.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${product.price.toStringAsFixed(2)} ${product.currencySymbol} • ${product.sellerName}',
              style: const TextStyle(fontSize: 12)),
          Row(children: [
            Icon(Icons.photo_library_outlined,
                size: 12, color: colors.textHint),
            const SizedBox(width: 2),
            Text('${product.images.length} صورة',
                style: TextStyle(fontSize: 11, color: colors.textHint)),
            const SizedBox(width: 8),
            Icon(Icons.visibility_outlined,
                size: 12, color: colors.textHint),
            const SizedBox(width: 2),
            Text('${product.displayWeight}/10',
                style: TextStyle(fontSize: 11, color: colors.textHint)),
            if (product.hasVariants) ...[
              const SizedBox(width: 8),
              Icon(Icons.style_outlined, size: 12, color: colors.primary),
              const SizedBox(width: 2),
              Text('متغيرات', style: TextStyle(fontSize: 11, color: colors.primary)),
            ],
          ]),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFFE1306C), size: 20),
            tooltip: 'إعلان تسويقي بالذكاء الاصطناعي',
            onPressed: () => _openMarketingAd(context),
          ),
          IconButton(
            icon: Icon(Icons.notifications_active_outlined, color: colors.primary, size: 20),
            tooltip: 'إرسال إشعار للمستخدمين',
            onPressed: () => _openNotificationCampaign(context),
          ),
          IconButton(
            icon: const Icon(Icons.campaign_outlined, color: Color(0xFF7B2D8B), size: 20),
            tooltip: 'مشاركة',
            onPressed: () => _openShareOptions(context),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: colors.primary, size: 20),
            tooltip: 'تعديل المنتج',
            onPressed: () => _editProduct(context),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.error, size: 20),
            onPressed: () => _delete(context),
          ),
        ]),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _openShareOptions(BuildContext ctx) async {
    final imgs = product.images
        .map((i) => ImageKitService.productFullUrl(i))
        .toList();

    await showShareOptionsSheet(
      ctx,
      data: ShareProductData(
        productId:          product.id,
        productName:        product.name,
        productPrice:       product.price.toStringAsFixed(2),
        currencySymbol:     product.currencySymbol,
        storeName:          product.sellerName,
        sellerLogo:         product.sellerLogo,
        imageUrls:          imgs,
        adText:             '',
        productDescription: product.description,
      ),
    );
  }
}
