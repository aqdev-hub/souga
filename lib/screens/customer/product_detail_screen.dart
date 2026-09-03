// lib/screens/customer/product_detail_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/product_model.dart';
import '../../models/review_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/reviews_service.dart';
import '../../services/imagekit_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/product_card.dart';
import '../../services/chat_service.dart';
import '../shared/chat_screen.dart';
import '../../services/share_options_sheet.dart';

// ── ثوابت الروابط ─────────────────────────────────────────────────────────────


class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;
  const ProductDetailScreen({super.key, required this.product});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  // ✅ محرك المعرض الجديد — يحل محل _imgIndex اليدوي القديم بالكامل.
  // يعمل تلقائياً مع أي منتج (قديم بصورة واحدة، أو جديد بفيديو/متغيرات)
  // عبر product.effectiveGallery المبني في ProductModel نفسه.
  late final ProductGalleryController _galleryController;
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _galleryController = ProductGalleryController(product: widget.product);
    // ✅ منتج بلا أي تقييمات → توليد 10 تقييمات تمهيدية ذكية في الخلفية.
    // صامت تماماً من منظور المستخدم؛ الخادم يضمن عدم التكرار حتى لو فتح
    // عدة مستخدمين نفس المنتج في نفس اللحظة تقريباً، وتغطي هذه الخطوة
    // المنتجات القديمة (عند أول زيارة لها بعد هذه الميزة) والجديدة معاً.
    if (widget.product.reviewCount == 0) {
      unawaited(AiAssistantService.generateSeedReviews(productId: widget.product.id));
    }
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  void _requireLogin() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الدخول مطلوب'),
        content: const Text('للقيام بذلك يجب إنشاء حساب وتسجيل الدخول.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('لاحقاً')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); context.read<AuthProvider>().logout(); },
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36)),
            child: const Text('تسجيل الدخول'),
          ),
        ],
      ),
    );
  }



  // ── فتح نافذة خيارات المشاركة ────────────────────────────────────────────
  Future<void> _shareProduct() async {
    if (!mounted) return;
    final p = widget.product;
    await showShareOptionsSheet(
      context,
      data: ShareProductData(
        productId:          p.id,
        productName:        p.name,
        productPrice:       p.price.toStringAsFixed(2),
        currencySymbol:     p.currencySymbol,
        storeName:          p.sellerName,
        sellerLogo:         p.sellerLogo,
        imageUrls:          p.images
            .map((img) => ImageKitService.productFullUrl(img))
            .toList(),
        adText:             '', // لا يوجد نص من Gemini هنا — يُبنى تلقائياً
        productDescription: p.description,
      ),
    );
  }

  // ── فتح موقع المتجر على الخريطة ───────────────────────────────────────────
  // ── فتح محادثة مع البائع ────────────────────────────────────────────────
  Future<void> _openChat() async {
    final me = context.read<AuthProvider>().currentUser;
    if (me == null || me.uid == 'guest') {
      _requireLogin();
      return;
    }
    // لا يراسل البائع نفسه
    if (me.uid == widget.product.sellerId) return;

    final product = widget.product;
    // ignore: use_build_context_synchronously
    final messenger = ScaffoldMessenger.of(context);

    try {
      final roomId = await ChatService.getOrCreateRoom(
        myUid:      me.uid,
        myName:     me.name,
        myImage:    me.profileImage,
        otherUid:   product.sellerId,
        otherName:  product.sellerName,
        otherImage: product.sellerLogo,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            roomId:     roomId,
            otherName:  product.sellerName,
            otherImage: product.sellerLogo,
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر فتح المحادثة، حاول مجدداً')),
      );
    }
  }

  Future<void> _openStoreOnMap(String location) async {
    if (location.isEmpty) return;
    final clean = location.replaceAll(' ', '');
    final uri   = Uri.parse('https://maps.google.com/?q=$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final parts  = clean.split(',');
      final lat    = parts[0];
      final lng    = parts.length > 1 ? parts[1] : '';
      final osmUri = Uri.parse(
          'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=15/$lat/$lng');
      await launchUrl(osmUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user    = context.watch<AuthProvider>().currentUser;
    final isGuest = user == null || user.uid == 'guest';
    final uid     = user?.uid ?? 'guest';
    final cart    = context.watch<CartProvider>();
    final favs    = context.watch<FavoritesProvider>();
    final inCart  = cart.isInCart(widget.product.id);
    final colors  = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(slivers: [
        // ─── صور المنتج ──────────────────────────────────
        SliverAppBar(
          expandedHeight: 380, pinned: true, backgroundColor: colors.primary,
          actions: [
            // زر المشاركة
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              tooltip: 'مشاركة المنتج',
              onPressed: _shareProduct,
            ),
            // زر المفضلة
            StreamBuilder<bool>(
              stream: favs.isFavoriteStream(uid, widget.product.id),
              builder: (_, snap) {
                final isFav = snap.data ?? false;
                return IconButton(
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_outline,
                      color: isFav ? Colors.red : Colors.white),
                  onPressed: () {
                    if (isGuest) { _requireLogin(); return; }
                    favs.toggleFavorite(
                      uid: uid, productId: widget.product.id,
                      productName: widget.product.name,
                      productImage: widget.product.firstImage,
                    );
                  },
                );
              },
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            // ✅ محرك المعرض الجديد بالكامل — يحل محل PageView اليدوي و
            // _imgIndex. يعمل تلقائياً مع صورة واحدة (منتج قديم)، أو
            // فيديو+صور+ألوان+مقاسات (منتج جديد) دون أي فرع خاص هنا.
            background: GestureDetector(
              // ✅ أُبقيت خاصية "فتح رابط المنتج بالمتصفح" بالضغط المطوّل
              // كما كانت (مفيدة لمشاركة/نسخ الرابط). أزلت النقر العادي
              // القديم لفتح المتصفح لأنه كان يتعارض الآن مع نقرة تشغيل/
              // إيقاف الفيديو داخل المعرض الجديد، ولم يكن ضرورياً أصلاً
              // (المستخدم بالفعل داخل صفحة المنتج في التطبيق).
              onLongPress: () {
                final url = 'https://souga-5fdb3.web.app/product/${widget.product.id}';
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              child: Stack(children: [
                ProductGalleryView(controller: _galleryController, height: 380),
                AnimatedBuilder(
                  animation: _galleryController,
                  builder: (context, _) {
                    final total = _galleryController.gallery.length;
                    if (total <= 1) return const SizedBox.shrink();
                    return Positioned(bottom: 16, left: 0, right: 0,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(total, (i) => Container(
                          width: i == _galleryController.currentPage ? 20 : 8, height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == _galleryController.currentPage ? Colors.white : Colors.white54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )),
                      ),
                    );
                  },
                ),
              ]),
            ),
          ),
        ),

        // ✅ شريط المصغرات الجديد — Hero + الألوان + المقاسات فقط (بلا صور
        // Item العامة كما اشترطت)، بتزامن ثنائي الاتجاه كامل مع المعرض أعلاه.
        SliverToBoxAdapter(
          child: ProductGalleryThumbnailBar(controller: _galleryController),
        ),

        SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ─── الاسم والسعر ─────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(widget.product.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Text('${widget.product.price.toStringAsFixed(2)} ${widget.product.currencySymbol}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors.primary)),
            ]),
            const SizedBox(height: 12),

            // ─── بطاقة معلومات المتجر المحسّنة ──────────────
            _SellerInfoCard(
              product:       widget.product,
              onMapPressed:  _openStoreOnMap,
              // زر المراسلة يظهر فقط للمشتري، لا للبائع على منتجاته
              onChatPressed: (user != null &&
                              user.uid != 'guest' &&
                              user.uid != widget.product.sellerId)
                  ? _openChat
                  : null,
            ),
            const SizedBox(height: 12),

            // ─── تقييم + مخزون ────────────────────────────
            Row(children: [
              _RatingBadge(rating: widget.product.rating, count: widget.product.reviewCount),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.product.stock > 0
                      ? colors.success.withValues(alpha: 0.1)
                      : colors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(widget.product.stock > 0 ? 'متوفر (${widget.product.stock})' : 'غير متوفر',
                    style: TextStyle(fontSize: 12,
                        color: widget.product.stock > 0 ? colors.success : colors.error)),
              ),
            ]),
            const SizedBox(height: 12),

            // ─── أزرار الإعجاب والمشاركة ──────────────────
            Row(children: [
              StreamBuilder<int>(
                stream: favs.likesCountStream(widget.product.id),
                builder: (_, snap) {
                  final count = snap.data ?? 0;
                  return StreamBuilder<bool>(
                    stream: favs.isLikedStream(uid, widget.product.id),
                    builder: (_, likeSnap) {
                      final liked = likeSnap.data ?? false;
                      return GestureDetector(
                        onTap: () {
                          if (isGuest) { _requireLogin(); return; }
                          favs.toggleLike(uid: uid, productId: widget.product.id);
                        },
                        child: Row(children: [
                          Icon(liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                              color: liked ? colors.primary : colors.textSecondary, size: 20),
                          const SizedBox(width: 4),
                          Text('$count', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                        ]),
                      );
                    },
                  );
                },
              ),
              const SizedBox(width: 20),
              StreamBuilder<List<String>>(
                stream: favs.favoritesStream(uid),
                builder: (_, snap) {
                  final isFav = (snap.data ?? []).contains(widget.product.id);
                  return GestureDetector(
                    onTap: () {
                      if (isGuest) { _requireLogin(); return; }
                      favs.toggleFavorite(uid: uid, productId: widget.product.id,
                          productName: widget.product.name, productImage: widget.product.firstImage);
                    },
                    child: Row(children: [
                      Icon(isFav ? Icons.bookmark : Icons.bookmark_outline,
                          color: isFav ? colors.accent : colors.textSecondary, size: 20),
                      const SizedBox(width: 4),
                      Text(isFav ? 'محفوظ' : 'حفظ',
                          style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    ]),
                  );
                },
              ),
              const Spacer(),
              // زر مشاركة مدمج في الصف
              GestureDetector(
                onTap: _shareProduct,
                child: Row(children: [
                  Icon(Icons.share_outlined, color: colors.textSecondary, size: 20),
                  const SizedBox(width: 4),
                  Text('مشاركة', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),

            // ✅ زر "اسأل سوجا" الذكي: يفتح محادثة سريعة عن هذا المنتج تحديداً
            _AskSougaButton(product: widget.product),
            const SizedBox(height: 16),

            const Divider(),
            const SizedBox(height: 12),

            // ─── الوصف ────────────────────────────────────
            const Text('الوصف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.product.description,
                style: TextStyle(fontSize: 14, color: colors.textSecondary, height: 1.6)),
            const SizedBox(height: 20),

            // ─── الكمية ───────────────────────────────────
            Row(children: [
              const Text('الكمية:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.remove), iconSize: 20,
                      onPressed: _qty > 1 ? () => setState(() => _qty--) : null),
                  Text('$_qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.add), iconSize: 20,
                      onPressed: _qty < widget.product.stock ? () => setState(() => _qty++) : null),
                ]),
              ),
            ]),
            const SizedBox(height: 20),

            // ─── أزرار الشراء ─────────────────────────────
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: widget.product.stock > 0 ? () {
                  if (isGuest) { _requireLogin(); return; }
                  cart.addItem(widget.product, quantity: _qty);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('✅ تم إضافة المنتج للسلة'),
                    backgroundColor: colors.success));
                } : null,
                icon: Icon(inCart ? Icons.shopping_cart : Icons.shopping_cart_outlined),
                label: Text(inCart ? 'في السلة' : 'إضافة للسلة'),
                style: OutlinedButton.styleFrom(foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary), minimumSize: const Size(0, 48)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: widget.product.stock > 0 ? () {
                  if (isGuest) { _requireLogin(); return; }
                  cart.addItem(widget.product, quantity: _qty);
                  Navigator.pop(context);
                } : null,
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('شراء الآن'),
              )),
            ]),
          ])),

          Divider(thickness: 8, color: colors.divider),

          // ─── التقييمات (تعكس العدد الحي فور توفّر تقييمات جديدة) ────
          _ReviewsSection(product: widget.product, uid: uid, isGuest: isGuest, user: user),

          Divider(thickness: 8, color: colors.divider),

          // ─── منتجات من نفس البائع ─────────────────────────
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('منتجات من نفس البائع',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary))),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('products')
                .where('sellerId', isEqualTo: widget.product.sellerId).limit(6).snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const SizedBox();
              final products = snap.data!.docs
                  .map((d) => ProductModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                  .where((p) => p.id != widget.product.id).toList();
              if (products.isEmpty) return const SizedBox(height: 16);
              return SizedBox(height: 220, child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: products.length,
                itemBuilder: (_, i) => ProductCard(product: products[i],
                    onTap: () => Navigator.pushReplacement(ctx, MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: products[i])))),
              ));
            },
          ),
          const SizedBox(height: 24),
        ])),
      ]),
    );
  }
}

// ── بطاقة معلومات المتجر المحسّنة ──────────────────────────────────────────────
// تعرض: شعار المتجر الكبير + اسمه + وصفه + زر الخريطة (إن توفر الموقع)
class _SellerInfoCard extends StatelessWidget {
  final ProductModel product;
  final void Function(String location) onMapPressed;
  final VoidCallback? onChatPressed;

  const _SellerInfoCard({
    required this.product,
    required this.onMapPressed,
    this.onChatPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // ── شعار المتجر الكبير ──────────────────────────────────────────────
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: colors.border,
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset:     const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: product.sellerLogo.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl:    ImageKitService.avatarUrl(product.sellerLogo),
                  fit:         BoxFit.cover,
                  placeholder: (_, __) => const _StorePlaceholder(),
                  errorWidget: (_, __, ___) => const _StorePlaceholder(),
                )
              : const _StorePlaceholder(),
          ),
        ),
        const SizedBox(width: 12),

        // ── اسم المتجر + وصفه ──────────────────────────────────────────────
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            product.sellerName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize:   14,
              color:      colors.textPrimary,
            ),
          ),
          if (product.storeDescription.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              product.storeDescription,
              maxLines:  2,
              overflow:  TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color:    colors.textSecondary,
                height:   1.4,
              ),
            ),
          ],
        ])),

        // ── أزرار: مراسلة + خريطة ─────────────────────────────────────────
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (onChatPressed != null)
            Tooltip(
              message: 'مراسلة البائع',
              child: InkWell(
                onTap: onChatPressed,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.chat_outlined,
                      color: colors.primary, size: 22),
                ),
              ),
            ),
          const SizedBox(width: 6),
          _MapButton(sellerId: product.sellerId, onMapPressed: onMapPressed),
        ]),
      ]),
    );
  }
}

// ── أيقونة placeholder للمتجر ──────────────────────────────────────────────────
class _StorePlaceholder extends StatelessWidget {
  const _StorePlaceholder();
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.primary.withValues(alpha: 0.08),
      child: Icon(Icons.store_rounded, color: colors.primary, size: 28),
    );
  }
}

// ── زر الخريطة — يجلب storeLocation من Firestore بـ sellerId ──────────────────
class _MapButton extends StatelessWidget {
  final String sellerId;
  final void Function(String location) onMapPressed;

  const _MapButton({required this.sellerId, required this.onMapPressed});

  @override
  Widget build(BuildContext context) {
    if (sellerId.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .snapshots(),
      builder: (_, snap) {
        final data     = snap.data?.data() as Map<String, dynamic>?;
        final location = (data?['storeLocation'] ?? '').toString().trim();

        if (location.isEmpty) return const SizedBox.shrink();

        return Tooltip(
          message: 'موقع المتجر على الخريطة',
          child: InkWell(
            onTap: () => onMapPressed(location),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:        colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: colors.primary,
                size: 22,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── قسم التقييمات ────────────────────────────────────────────────────────────
// ✅ مُعاد هيكلته: كل شيء (شارة التقييم في الهيدر، بطاقة ملخص Souga AI،
// وقائمة التقييمات) الآن مبني داخل نفس StreamBuilder الحي — بمجرد كتابة
// التقييمات التمهيدية (أو أي تقييم حقيقي جديد) في Firestore، يتحدّث العدد
// والمتوسط والبطاقات فوراً دون الحاجة لإعادة فتح الصفحة.
class _ReviewsSection extends StatefulWidget {
  final ProductModel product;
  final String uid;
  final bool isGuest;
  final dynamic user;
  const _ReviewsSection({required this.product, required this.uid, required this.isGuest, this.user});

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return StreamBuilder<List<ReviewModel>>(
      stream: ReviewsService.getProductReviews(widget.product.id),
      builder: (context, snap) {
        final hasLiveData = snap.hasData;
        final reviews      = snap.data ?? const <ReviewModel>[];

        // ✅ القيم الحية من التيار عند توفّرها، وإلا القيم الأصلية من المنتج
        // (تفادياً لوميض "0 تقييم" قبل وصول أول دفعة من Firestore).
        final liveCount = hasLiveData ? reviews.length : widget.product.reviewCount;
        final liveRating = reviews.isNotEmpty
            ? reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length
            : widget.product.rating;

        final shown = _showAll ? reviews : reviews.take(3).toList();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Row(children: [
            const Text('التقييمات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            _RatingBadge(rating: liveRating, count: liveCount),
            const Spacer(),
            if (!widget.isGuest)
              TextButton.icon(
                icon: const Icon(Icons.rate_review_outlined, size: 16),
                label: const Text('أضف تقييم', style: TextStyle(fontSize: 13)),
                onPressed: () => _showReviewDialog(context),
              ),
          ])),

          // ✅ بطاقة "ملخص Souga AI" — تُقاس بالعدد الحي، فتظهر فور اكتمال
          // التقييمات التمهيدية بدون الحاجة لإعادة فتح الصفحة.
          if (liveCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _AiReviewSummaryCard(
                productId:   widget.product.id,
                reviewCount: liveCount,
              ),
            ),

          if (!hasLiveData)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (reviews.isEmpty)
            Padding(padding: const EdgeInsets.all(16),
                child: Text('لا توجد تقييمات بعد. كن أول من يُقيّم!',
                    style: TextStyle(color: colors.textSecondary)))
          else
            Column(children: [
              ...shown.map((r) => _ReviewCard(review: r, uid: widget.uid, productId: widget.product.id)),
              if (reviews.length > 3 && !_showAll)
                TextButton(
                  onPressed: () => setState(() => _showAll = true),
                  child: Text('عرض كل التقييمات (${reviews.length})',
                      style: TextStyle(color: colors.primary)),
                ),
            ]),
        ]);
      },
    );
  }

  void _showReviewDialog(BuildContext context) async {
    double selectedRating = 5.0;
    final commentCtrl = TextEditingController();
    bool isSubmitting = false;

    final existing = await ReviewsService.getUserReview(widget.product.id, widget.uid);
    if (existing != null) {
      selectedRating = existing.rating;
      commentCtrl.text = existing.comment;
    }

    if (!context.mounted) return;
    final colors = context.colors;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(existing != null ? 'تعديل تقييمك' : 'إضافة تقييم',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('تقييمك:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(children: List.generate(5, (i) {
              final star = i + 1.0;
              return GestureDetector(
                onTap: () => setModalState(() => selectedRating = star),
                child: Padding(padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    star <= selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: colors.accent, size: 36,
                  )),
              );
            })),
            const SizedBox(height: 16),
            TextField(
              controller: commentCtrl, maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'اكتب تعليقك هنا...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                setModalState(() => isSubmitting = true);
                final result = await ReviewsService.submitReview(
                  productId: widget.product.id,
                  userId: widget.uid,
                  userName: widget.user?.name ?? 'مستخدم',
                  userImage: widget.user?.profileImage ?? '',
                  rating: selectedRating,
                  comment: commentCtrl.text.trim(),
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result == 'success' ? '✅ تم حفظ تقييمك' : '❌ حدث خطأ'),
                  backgroundColor: result == 'success' ? colors.success : colors.error,
                ));
              },
              child: isSubmitting
                  ? const SizedBox(height: 22, width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(existing != null ? 'تحديث التقييم' : 'إرسال التقييم'),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── بطاقة تقييم ───────────────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final String uid;
  final String productId;
  const _ReviewCard({required this.review, required this.uid, required this.productId});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isOwner = review.userId == uid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.primary.withValues(alpha: 0.1),
            backgroundImage: review.userImage.isNotEmpty ? NetworkImage(review.userImage) : null,
            child: review.userImage.isEmpty
                ? Text(review.userName.isNotEmpty ? review.userName[0] : 'م',
                    style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(review.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Row(children: List.generate(5, (i) => Icon(
              i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
              color: colors.accent, size: 14,
            ))),
          ])),
          if (isOwner)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: colors.error),
              onPressed: () async {
                final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                  title: const Text('حذف التقييم'),
                  content: const Text('هل تريد حذف تقييمك؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                    TextButton(onPressed: () => Navigator.pop(context, true),
                        child: Text('حذف', style: TextStyle(color: colors.error))),
                  ],
                ));
                if (confirm == true) {
                  await ReviewsService.deleteReview(review.id, productId);
                }
              },
            ),
        ]),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(review.comment,
              style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.5)),
        ],
      ]),
    );
  }
}

// ─── شارة التقييم ──────────────────────────────────────────────────────────────
class _RatingBadge extends StatelessWidget {
  final double rating;
  final int count;
  const _RatingBadge({required this.rating, required this.count});

  @override
  Widget build(BuildContext context) {
    if (rating == 0) return const SizedBox();
    final colors = context.colors;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.star_rounded, size: 15, color: colors.accent),
      const SizedBox(width: 2),
      Text(rating.toStringAsFixed(1),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      if (count > 0) ...[
        const SizedBox(width: 2),
        Text('($count)', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
      ],
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ✅ "اسأل سوجا": زر + محادثة ذكية عن المنتج المعروض تحديداً
// ═══════════════════════════════════════════════════════════════════════════

// ── الزر البارز فوق قسم الوصف ──────────────────────────────────────────────
class _AskSougaButton extends StatelessWidget {
  final ProductModel product;
  const _AskSougaButton({required this.product});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AskSougaSheet(product: product),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.primary, colors.primaryDark],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      colors.primary.withValues(alpha: 0.28),
              blurRadius: 14,
              offset:     const Offset(0, 5),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('اسأل سوجا عن هذا المنتج',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text('إجابات ذكية فورية بناءً على تفاصيل المنتج',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
          ])),
          const Icon(Icons.chevron_left_rounded, color: Colors.white70),
        ]),
      ),
    );
  }
}

// ── رسالة واحدة داخل المحادثة ────────────────────────────────────────────────
class _AskMessage {
  final bool isUser;
  final String text;
  final bool isLoading;
  final bool isError;
  const _AskMessage({
    required this.isUser,
    required this.text,
    this.isLoading = false,
    this.isError = false,
  });
}

// ── نافذة المحادثة السفلية ────────────────────────────────────────────────
class _AskSougaSheet extends StatefulWidget {
  final ProductModel product;
  const _AskSougaSheet({required this.product});

  @override
  State<_AskSougaSheet> createState() => _AskSougaSheetState();
}

class _AskSougaSheetState extends State<_AskSougaSheet> {
  final _questionCtrl = TextEditingController();
  final _scrollCtrl   = ScrollController();
  final List<_AskMessage> _messages = [];
  bool _isSending = false;

  static const List<String> _suggestedQuestions = [
    'هل يناسبني؟',
    'هل السعر مناسب؟',
    'بم أقارنه؟',
    'ما أبرز مميزاته؟',
  ];

  @override
  void dispose() {
    _questionCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? presetQuestion]) async {
    final question = (presetQuestion ?? _questionCtrl.text).trim();
    if (question.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_AskMessage(isUser: true, text: question));
      _messages.add(const _AskMessage(isUser: false, text: '', isLoading: true));
      _isSending = true;
      _questionCtrl.clear();
    });
    _scrollToBottom();

    final p = widget.product;
    final result = await AiAssistantService.askProduct(
      productId:          p.id,
      productName:        p.name,
      productDescription: p.description,
      productPrice:       p.price.toStringAsFixed(2),
      currencySymbol:     p.currencySymbol,
      category:           p.category,
      rating:             p.rating,
      reviewCount:        p.reviewCount,
      sellerName:         p.sellerName,
      question:           question,
    );

    if (!mounted) return;
    setState(() {
      if (_messages.isNotEmpty && _messages.last.isLoading) {
        _messages.removeLast();
      }
      _messages.add(_AskMessage(
        isUser:  false,
        text:    result.isSuccess ? result.answer! : (result.errorMessage ?? 'حدث خطأ غير متوقع'),
        isError: !result.isSuccess,
      ));
      _isSending = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final p = widget.product;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, sc) => Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(children: [
            // شريط السحب
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: colors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // هيدر
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(gradient: colors.primaryGradient, shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('اسأل سوجا',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                ])),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Divider(height: 1, color: colors.divider),

            // المحادثة
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState(colors)
                  : ListView.builder(
                      controller: sc,
                      padding: const EdgeInsets.all(14),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _buildBubble(_messages[i], colors),
                    ),
            ),

            // أسئلة مقترحة — تظهر فقط قبل أول سؤال لتفادي التشويش لاحقاً
            if (_messages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _suggestedQuestions.map((q) => ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 12)),
                    backgroundColor: colors.primary.withValues(alpha: 0.08),
                    side: BorderSide(color: colors.primary.withValues(alpha: 0.25)),
                    onPressed: _isSending ? null : () => _send(q),
                  )).toList(),
                ),
              ),

            // حقل الإدخال
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _questionCtrl,
                      minLines: 1, maxLines: 3,
                      textDirection: TextDirection.rtl,
                      enabled: !_isSending,
                      decoration: InputDecoration(
                        hintText: 'اكتب سؤالك عن المنتج...',
                        filled: true, fillColor: colors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : () => _send(),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _isSending ? colors.textHint : colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyState(SougaColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 46, color: colors.textHint),
          const SizedBox(height: 12),
          Text(
            'اسأل أي سؤال عن هذا المنتج، وسيجيبك سوجا فوراً بناءً على تفاصيله الفعلية.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.6),
          ),
        ]),
      ),
    );
  }

  Widget _buildBubble(_AskMessage msg, SougaColors colors) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser
              ? colors.primary
              : (msg.isError ? colors.error.withValues(alpha: 0.1) : colors.background),
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(isUser ? 4 : 16),
            bottomRight: Radius.circular(isUser ? 16 : 4),
          ),
          border: !isUser
              ? Border.all(color: msg.isError ? colors.error.withValues(alpha: 0.3) : colors.border)
              : null,
        ),
        child: msg.isLoading
            ? SizedBox(width: 34, height: 18, child: _TypingDots(color: colors.textSecondary))
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser) ...[
                    Icon(msg.isError ? Icons.error_outline : Icons.auto_awesome_rounded,
                        size: 14, color: msg.isError ? colors.error : colors.primary),
                    const SizedBox(width: 6),
                  ],
                  Flexible(child: Text(msg.text,
                      style: TextStyle(
                        fontSize: 13, height: 1.6,
                        color: isUser ? Colors.white : (msg.isError ? colors.error : colors.textPrimary),
                      ))),
                ],
              ),
      ),
    );
  }
}

// ── مؤشر "يكتب الآن..." — ثلاث نقاط متحركة بدون أي حزمة خارجية ─────────────
class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_ctrl.value + i * 0.2) % 1.0;
            final opacity = (0.3 + 0.7 * (1 - (t - 0.5).abs() * 2)).clamp(0.3, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ✅ بطاقة "ملخص Souga AI"
// ═══════════════════════════════════════════════════════════════════════════
class _AiReviewSummaryCard extends StatefulWidget {
  final String productId;
  final int reviewCount;
  const _AiReviewSummaryCard({required this.productId, required this.reviewCount});

  @override
  State<_AiReviewSummaryCard> createState() => _AiReviewSummaryCardState();
}

class _AiReviewSummaryCardState extends State<_AiReviewSummaryCard> {
  ReviewSummaryResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AiReviewSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reviewCount != widget.reviewCount) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final result = await AiAssistantService.summarizeReviews(productId: widget.productId);
    if (!mounted) return;
    setState(() {
      _result  = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_loading) {
      return _buildLoadingCard(colors);
    }

    final result = _result;
    if (result == null || !result.isSuccess) {
      return const SizedBox.shrink();
    }

    final s = result.summary!;
    final percentColor = s.satisfactionPercent >= 70
        ? colors.success
        : (s.satisfactionPercent >= 40 ? colors.warning : colors.error);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(gradient: colors.primaryGradient, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 8),
          Text('ملخص Souga AI',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: colors.textPrimary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: percentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.favorite_rounded, size: 12, color: percentColor),
              const SizedBox(width: 4),
              Text('${s.satisfactionPercent}% رضا',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: percentColor)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),

        if (s.summary.isNotEmpty)
          Text(s.summary,
              style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.6)),

        if (s.positives.isNotEmpty || s.negatives.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (s.positives.isNotEmpty)
            _SummaryPointsList(
              icon: Icons.thumb_up_rounded,
              color: colors.success,
              points: s.positives,
            ),
          if (s.positives.isNotEmpty && s.negatives.isNotEmpty)
            const SizedBox(height: 8),
          if (s.negatives.isNotEmpty)
            _SummaryPointsList(
              icon: Icons.thumb_down_rounded,
              color: colors.error,
              points: s.negatives,
            ),
        ],

        const SizedBox(height: 8),
        Text('تحليل تلقائي من تقييمات المستخدمين الفعلية',
            style: TextStyle(fontSize: 10, color: colors.textHint)),
      ]),
    );
  }

  Widget _buildLoadingCard(SougaColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(children: [
        SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
        ),
        const SizedBox(width: 10),
        Text('سوجا يحلّل التقييمات...',
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
      ]),
    );
  }
}

// ── قائمة نقاط مصغّرة (إيجابيات/سلبيات) داخل بطاقة الملخص ─────────────────────
class _SummaryPointsList extends StatelessWidget {
  final IconData icon;
  final Color color;
  final List<String> points;
  const _SummaryPointsList({required this.icon, required this.color, required this.points});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: points.map((point) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(point,
              style: TextStyle(fontSize: 12.5, color: context.colors.textPrimary, height: 1.4))),
        ]),
      )).toList(),
    );
  }
}
