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
    show showShareOptionsSheet, ShareProductData, sougaFirstVideoUrl;
import '../../utils/app_colors.dart';
import '../../utils/search_text.dart';
import '../../widgets/product_sort_menu.dart';
import '../../widgets/product/product_gallery_view.dart' show ProductImageFrame;
import '../seller/product_form_stepper_screen.dart';
import '../../utils/currencies.dart';

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
  ProductSort _sort = ProductSort.newest;

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
            Row(children: [
            Expanded(child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
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
            )),
            const SizedBox(width: 8),
            ProductSortButton(sort: _sort, onChanged: (s) => setState(() => _sort = s)),
            ]),
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

              final q = normalizeSearch(_searchQuery);
              if (q.isNotEmpty) {
                products = products.where((p) =>
                  searchMatches(p.name, q) || searchMatches(p.sellerName, q)
                ).toList();
              }
              products = sortProducts(products, _sort);

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
        productVideoUrl:    sougaFirstVideoUrl(product.gallery),
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

  // ✅ تخطيط البطاقة: صف علوي (صورة + بيانات المنتج بعرض كامل) ثم صف سفلي
  // لأزرار الإجراءات — بدل حشر 5 أزرار بجانب النص (كان يضغط الاسم والسعر
  // حتى ينكسر النص حرفاً حرفاً).
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasImage = product.firstImage.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hasImage
                  ? ProductImageFrame(
                      url: ImageKitService.productAdminUrl(product.firstImage),
                      width: 68, height: 68, blurBackdrop: false, memCacheWidth: 200,
                      fallback: Container(
                          width: 68, height: 68, color: colors.border,
                          child: const Icon(Icons.image_outlined)))
                  : Container(
                      width: 68, height: 68, color: colors.border,
                      child: Icon(Icons.image_outlined, color: colors.textHint)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${formatMoney(product.price)} ${product.currencySymbol}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: colors.primary)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.storefront_outlined, size: 13, color: colors.textHint),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(product.sellerName,
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 12, runSpacing: 4, children: [
                  _meta(Icons.photo_library_outlined, '${product.images.length} صورة', colors.textHint),
                  _meta(Icons.visibility_outlined, '${product.displayWeight}/10', colors.textHint),
                  if (product.hasVariants) _meta(Icons.style_outlined, 'متغيرات', colors.primary),
                ]),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Divider(height: 1, color: colors.divider),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _AdminActionButton(
              icon: Icons.auto_awesome, color: const Color(0xFFE1306C), label: 'إعلان',
              tooltip: 'إعلان تسويقي بالذكاء الاصطناعي',
              onTap: () => _openMarketingAd(context),
            ),
            _AdminActionButton(
              icon: Icons.notifications_active_outlined, color: colors.primary, label: 'إشعار',
              tooltip: 'إرسال إشعار للمستخدمين',
              onTap: () => _openNotificationCampaign(context),
            ),
            _AdminActionButton(
              icon: Icons.campaign_outlined, color: const Color(0xFF7B2D8B), label: 'مشاركة',
              tooltip: 'مشاركة', onTap: () => _openShareOptions(context),
            ),
            _AdminActionButton(
              icon: Icons.edit_outlined, color: colors.info, label: 'تعديل',
              tooltip: 'تعديل المنتج', onTap: () => _editProduct(context),
            ),
            _AdminActionButton(
              icon: Icons.delete_outline, color: colors.error, label: 'حذف',
              tooltip: 'حذف المنتج', onTap: () => _delete(context),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _meta(IconData icon, String text, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11.5, color: color)),
      ]);

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
        videoUrl:           sougaFirstVideoUrl(product.gallery),
      ),
    );
  }
}

// زر إجراء بأيقونة ونص صغير تحتها — مساحة لمس مريحة (≥ 48×44)
class _AdminActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  const _AdminActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
