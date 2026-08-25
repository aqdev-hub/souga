// lib/screens/admin/admin_products_screen.dart

import 'dart:async';
import 'dart:io';

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

  void _editProduct(BuildContext context) {
    final nameCtrl = TextEditingController(text: product.name);
    final descCtrl = TextEditingController(text: product.description);
    int displayWeight = product.displayWeight;
    // نسخة قابلة للتعديل من قائمة الصور
    final List<String> currentImages = List<String>.from(product.images);
    final colors = context.colors;

    showModalBottomSheet(
      context:          context,
      isScrollControlled: true,
      useSafeArea:      true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand:          false,
          initialChildSize: 0.85,
          minChildSize:     0.5,
          maxChildSize:     0.95,
          builder: (_, sc) => SingleChildScrollView(
            controller: sc,
            padding: EdgeInsets.only(
              left:   16, right: 16, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize:      MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // شريط السحب
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin:     const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color:        colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Text('تعديل: ${product.name}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // ── صور المنتج ─────────────────────────────────────────────
                const Text('صور المنتج',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),

                // عرض الصور الحالية
                if (currentImages.isNotEmpty)
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount:       currentImages.length,
                      itemBuilder: (_, idx) {
                        final imgUrl = currentImages[idx];
                        return Stack(
                          children: [
                            Container(
                              margin:       const EdgeInsets.only(left: 8),
                              width:        100,
                              height:       100,
                              decoration:   BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border:       Border.all(color: colors.border),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.network(
                                  ImageKitService.productAdminUrl(imgUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Icon(Icons.broken_image_outlined,
                                          color: colors.textHint),
                                ),
                              ),
                            ),
                            // زر حذف الصورة
                            Positioned(
                              top: 2, right: 2,
                              child: GestureDetector(
                                onTap: () => setModal(
                                    () => currentImages.removeAt(idx)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colors.error, shape: BoxShape.circle),
                                  padding: const EdgeInsets.all(3),
                                  child: const Icon(Icons.close,
                                      size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                            // رقم الصورة
                            Positioned(
                              bottom: 4, left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color:        Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('${idx + 1}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 10)),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 8),

                // زر إضافة صورة
                _UploadImageButton(
                  folder: 'products',
                  onUploaded: (url) => setModal(() => currentImages.add(url)),
                ),

                const SizedBox(height: 16),

                // ── معلومات المنتج ──────────────────────────────────────────
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText:  'اسم المنتج',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  maxLines:   3,
                  decoration: const InputDecoration(
                    labelText:          'الوصف',
                    prefixIcon:         Icon(Icons.description_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                Row(children: [
                  const Text('نسبة الظهور في الرئيسية:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Text('$displayWeight / 10',
                      style: TextStyle(
                          color: colors.primary, fontWeight: FontWeight.bold)),
                ]),
                Slider(
                  value:       displayWeight.toDouble(),
                  min: 1, max: 10, divisions: 9,
                  activeColor: colors.primary,
                  onChanged:   (v) => setModal(() => displayWeight = v.round()),
                ),
                Text(
                  displayWeight >= 8 ? '🔥 ظهور مرتفع جداً'
                      : displayWeight >= 5 ? '⭐ ظهور عادي'
                      : '👁️ ظهور منخفض',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('products')
                        .doc(product.id)
                        .update({
                      'name':          nameCtrl.text.trim(),
                      'description':   descCtrl.text.trim(),
                      'displayWeight': displayWeight,
                      'images':        currentImages,
                    });
                    // ✅ إعادة بناء صفحات SEO الثابتة في الخلفية بعد التعديل.
                    unawaited(SeoRebuildService.triggerRebuild(reason: 'product_updated_by_admin:${product.id}'));
                    if (!ctx.mounted) { return; }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: const Text('✅ تم تحديث المنتج'),
                          backgroundColor: colors.success),
                    );
                  },
                  child: const Text('حفظ التعديلات'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  // ── ✅ جديد — حملة إشعارات يدوية لهذا المنتج ────────────────────────────
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
          Text('${product.price.toStringAsFixed(2)} ر.س • ${product.sellerName}',
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
          ]),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFFE1306C), size: 20),
            tooltip: 'إعلان تسويقي بالذكاء الاصطناعي',
            onPressed: () => _openMarketingAd(context),
          ),
          // ✅ جديد — إرسال إشعار Push كحملة تسويقية
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
    // رابط المنتج يُحسب تلقائياً من ShareProductData.webLink
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
        adText:             '', // بدون نص Gemini — SougaAdText يبني نصاً احترافياً
        productDescription: product.description,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  زر رفع صورة مع شريط تقدم
// ─────────────────────────────────────────────────────────────────────────────
 

class _UploadImageButton extends StatefulWidget {
  final String                    folder;
  final void Function(String url) onUploaded;

  const _UploadImageButton({required this.folder, required this.onUploaded});

  @override
  State<_UploadImageButton> createState() => _UploadImageButtonState();
}

class _UploadImageButtonState extends State<_UploadImageButton> {
  double _progress = -1; // -1=idle, 0–1=uploading

  bool get _uploading => _progress >= 0 && _progress < 1;

  Future<void> _pick() async {
    // اختيار المصدر
    final source = await showModalBottomSheet<bool>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading:  Icon(Icons.photo_library_outlined, color: context.colors.primary),
            title:    const Text('من المعرض'),
            onTap:    () => Navigator.pop(context, false),
          ),
          ListTile(
            leading:  Icon(Icons.camera_alt_outlined, color: context.colors.primary),
            title:    const Text('من الكاميرا'),
            onTap:    () => Navigator.pop(context, true),
          ),
        ]),
      ),
    );
    if (source == null || !mounted) { return; }

    final File? file =
        await ImageKitService.pickImage(fromCamera: source);
    if (file == null || !mounted) { return; }

    setState(() => _progress = 0.0);

    final url = await ImageKitService.uploadImage(
      file,
      widget.folder,
      onProgress: (p) {
        if (mounted) { setState(() => _progress = p); }
      },
    );

    if (!mounted) { return; }

    if (url != null) {
      widget.onUploaded(url);
      setState(() => _progress = -1);
    } else {
      setState(() => _progress = -1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         const Text('❌ فشل رفع الصورة. تحقق من الاتصال.'),
          backgroundColor: context.colors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (_uploading) {
      return Column(children: [
        LinearProgressIndicator(
          value:           _progress,
          backgroundColor: colors.border,
          valueColor:
              AlwaysStoppedAnimation<Color>(colors.primary),
        ),
        const SizedBox(height: 4),
        Text('${(_progress * 100).round()}% — جاري رفع الصورة...',
            style: TextStyle(fontSize: 12, color: colors.textSecondary)),
      ]);
    }
    return OutlinedButton.icon(
      onPressed: _pick,
      icon:  const Icon(Icons.add_photo_alternate_outlined, size: 18),
      label: const Text('إضافة صورة'),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primary,
        side:            BorderSide(color: colors.primary),
      ),
    );
  }
}
