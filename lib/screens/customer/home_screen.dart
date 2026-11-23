// lib/screens/customer/home_screen.dart
//
// ✅ إعادة تصميم كاملة (v3) — مستوحاة من مرجع تصميمي احترافي عالمي المستوى
// مع الحفاظ الكامل على هوية سوجا (الأحمر القرمزي/الذهبي) ونظام الألوان
// الديناميكي (SougaColors) بحيث يعمل بلا أي مشكلة في الوضع الليلي.
//
// ✅ إصلاحات أداء جوهرية ضمن نفس الملف (لم تكن موجودة سابقاً):
//   - قسم "جميع المنتجات" أصبح مُقسَّماً على صفحات (limit + تحميل المزيد)
//     بدل تحميل المجموعة كاملة دفعة واحدة في كل مرة تُفتح فيها الصفحة —
//     كانت هذه أخطر مشكلة أداء/تكلفة في المشروع بحسب تقرير المراجعة.
//   - التصنيفات موحَّدة الآن من مصدر واحد (utils/categories.dart) بدل
//     نسخة محلية منفصلة كانت مصدر ازدواجية مع باقي الشاشات.
//
// ✅ ميزة جديدة اختيارية بالكامل: قسم "عروض اليوم" (Flash Deals) يظهر فقط
// إن وُجدت فعلياً منتجات عليها خصم فعّال (originalPrice > price) خلال
// نافذة زمنية (dealEndsAt) — لا يظهر القسم إطلاقاً إن لم توجد عروض حقيقية،
// حتى لا نعرض عدّاداً زائفاً بلا محتوى.

// lib/screens/customer/home_screen.dart  (v4 — أسرع وأجمل)
//
// ✅ الأداء:
//   • طلب واحد مُخزَّن (HomeFeedService) بدل 5 مستمعين حيّين كانت تُعاد
//     الاشتراكات فيها مع كل إعادة بناء (Stream جديد في build) — توفير كبير في القراءات
//   • تحميل المزيد تلقائياً عند الاقتراب من نهاية القائمة + RepaintBoundary للصفوف
//   • هياكل تحميل (Skeleton) بدل دوّامات التحميل
// ✅ التجربة:
//   • سحب للتحديث، زر السلة يعمل، النقر على تصنيف في "تصفّح حسب التصنيف" يفلتر الرئيسية
//   • رسالة خطأ مع إعادة المحاولة عند فشل الشبكة
// ✅ الشكل: بانر أنظف بنقاط، عناوين أقسام موحّدة، حركة دخول خفيفة
// نفس الهوية (أحمر/ذهبي عبر context.colors) والوضع الليلي.

import 'dart:async';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/home_feed_service.dart';
import '../../services/notifications_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/categories.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';
import 'search_screen.dart';
import '../shared/notifications_screen.dart';
import '../../widgets/product_card.dart';
import '../../widgets/onboarding_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = '';
  HomeFeed? _feed;
  bool _feedError = false;
  int _refreshTick = 0;
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<int> _loadMoreSignal = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 700) {
        _loadMoreSignal.value++;
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _loadMoreSignal.dispose();
    super.dispose();
  }

  Future<void> _loadFeed({bool force = false}) async {
    final cat = _selectedCategory;
    if (mounted) setState(() { _feedError = false; });
    try {
      final feed = await HomeFeedService.load(cat, force: force);
      if (!mounted || cat != _selectedCategory) return; // تغيّر التصنيف أثناء التحميل
      setState(() { _feed = feed; });
    } catch (_) {
      if (!mounted || cat != _selectedCategory) return;
      setState(() { _feedError = true; });
    }
  }

  void _selectCategory(String id) {
    if (id == _selectedCategory) return;
    setState(() { _selectedCategory = id; _feed = null; });
    _loadFeed();
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshTick++);
    await _loadFeed(force: true);
  }

  void _openProduct(BuildContext context, ProductModel product) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final feed = _feed;
    return OnboardingOverlay(
      tutorialKey: 'home_screen',
      steps: const [
        OnboardingStep(
          icon:        Icons.storefront_rounded,
          title:       'مرحباً في سوجا! 🎉',
          description: 'سوقك المحلي لشراء وبيع المنتجات بسهولة وأمان',
        ),
        OnboardingStep(
          icon:        Icons.search_rounded,
          title:       'ابحث وصفّح',
          description: 'اضغط على التصنيفات لتصفية المنتجات، أو ابحث عن ما تريد',
        ),
        OnboardingStep(
          icon:        Icons.shopping_cart_rounded,
          title:       'أضف للسلة واطلب',
          description: 'اضغط على أي منتج، أضفه للسلة، وأتم طلبك بسهولة',
        ),
        OnboardingStep(
          icon:        Icons.chat_rounded,
          title:       'راسل البائع مباشرة',
          description: 'في صفحة أي منتج يمكنك مراسلة البائع للاستفسار قبل الشراء',
        ),
      ],
      child: Scaffold(
        backgroundColor: colors.background,
        body: RefreshIndicator(
          color: colors.primary,
          edgeOffset: 80,
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            // ignore: deprecated_member_use
            cacheExtent: 800,
            slivers: [
              SliverToBoxAdapter(child: _HomeHeader(
                selectedCategory: _selectedCategory,
                onCategoryChanged: _selectCategory,
              )),

              SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 16),
                const _PremiumBanner(),

                if (_feedError && feed == null) ...[
                  const SizedBox(height: 40),
                  _ErrorRetry(onRetry: () => _loadFeed(force: true)),
                ] else if (feed == null) ...[
                  const SizedBox(height: 22),
                  const _SectionHeader(title: 'الأحدث', emoji: '✨'),
                  const SizedBox(height: 12),
                  const _RowSkeleton(),
                ] else ...[
                  // ── عروض اليوم (تظهر فقط إن وُجدت) ──
                  if (feed.deals.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _FlashDealsSection(deals: feed.deals, onTap: _openProduct),
                  ],

                  // ── الأحدث ──
                  const SizedBox(height: 22),
                  const _SectionHeader(title: 'الأحدث', emoji: '✨'),
                  const SizedBox(height: 12),
                  _ProductsRow(products: feed.newest, onTap: _openProduct,
                      emptyText: 'لا توجد منتجات في هذا التصنيف'),

                  // ── الأعلى تقييماً ──
                  if (feed.topRated.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const _SectionHeader(title: 'الأعلى تقييماً', emoji: '⭐'),
                    const SizedBox(height: 12),
                    _ProductsRow(products: feed.topRated, onTap: _openProduct),
                  ],

                  // ── الأكثر مبيعاً (مؤشر: عدد التقييمات) ──
                  if (feed.popular.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const _SectionHeader(title: 'الأكثر مبيعاً', emoji: '🏆'),
                    const SizedBox(height: 12),
                    _ProductsRow(products: feed.popular, onTap: _openProduct),
                  ],
                ],

                // ── التصنيفات ──
                const SizedBox(height: 22),
                const _SectionHeader(title: 'تصفّح حسب التصنيف', emoji: '🗂️'),
                const SizedBox(height: 12),
                _CategoriesShowcase(onSelect: _selectCategory),

                // ── لماذا سوجا؟ ──
                const SizedBox(height: 22),
                const _TrustBadgesRow(),

                // ── جميع المنتجات ──
                const SizedBox(height: 22),
                const _SectionHeader(title: 'جميع المنتجات', emoji: '🛍️'),
                const SizedBox(height: 12),
              ])),

              _PaginatedProductsGrid(
                key: ValueKey('grid_${_selectedCategory}_$_refreshTick'),
                category: _selectedCategory,
                loadMoreSignal: _loadMoreSignal,
                onTap: _openProduct,
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  الهيدر: تحية + موقع + إشعارات + سلة + شريط بحث + تصنيفات
// ═══════════════════════════════════════════════════════════════════════
class _HomeHeader extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  const _HomeHeader({required this.selectedCategory, required this.onCategoryChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user   = context.watch<AuthProvider>().currentUser;
    final uid    = user?.uid ?? 'guest';
    final cartCount = context.watch<CartProvider>().itemCount;
    final firstName = (user?.name ?? '').trim().isEmpty
        ? 'زائر' : user!.name.trim().split(' ').first;

    return Container(
      decoration: BoxDecoration(gradient: colors.primaryGradient),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              backgroundImage: (user?.profileImage.isNotEmpty ?? false)
                  ? NetworkImage(user!.profileImage) : null,
              child: (user?.profileImage.isEmpty ?? true)
                  ? Text(firstName.isNotEmpty ? firstName[0].toUpperCase() : '؟',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مرحباً 👋', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
              Text(firstName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ])),
            // إشعارات
            _HeaderIconButton(
              icon: Icons.notifications_none_rounded,
              badgeStream: uid == 'guest' ? null : NotificationsService.getUnreadCount(uid),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
            const SizedBox(width: 8),
            // السلة
            _HeaderIconButton(
              icon: Icons.shopping_cart_outlined,
              badgeCount: cartCount,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
            ),
          ]),
          const SizedBox(height: 14),
          // شريط البحث
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                const SizedBox(width: 14),
                Icon(Icons.search_rounded, color: colors.textHint, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text('ابحث عن منتجات، متاجر، ماركات...',
                    style: TextStyle(color: colors.textHint, fontSize: 13.5))),
                Container(
                  margin: const EdgeInsets.all(5),
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // التصنيفات
          SizedBox(
            height: 78,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _CategoryChip(
                  label: 'الكل', icon: Icons.apps_rounded,
                  selected: selectedCategory.isEmpty,
                  onTap: () => onCategoryChanged(''),
                ),
                ...kSougaCategories.map((c) => _CategoryChip(
                  label: c.name, icon: c.icon,
                  selected: selectedCategory == c.id,
                  onTap: () => onCategoryChanged(c.id),
                )),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final Stream<int>? badgeStream;
  final int? badgeCount;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, this.badgeStream, this.badgeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 20),
    );

    Widget withBadge(int count) {
      if (count <= 0) return iconWidget;
      return Badge(
        label: Text('$count', style: const TextStyle(fontSize: 10)),
        backgroundColor: const Color(0xFFFFB300),
        child: iconWidget,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: badgeStream != null
          ? StreamBuilder<int>(
              stream: badgeStream,
              builder: (_, snap) => withBadge(snap.data ?? 0),
            )
          : withBadge(badgeCount ?? 0),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        margin: const EdgeInsets.only(left: 8),
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: selected ? const Color(0xFFC8102E) : Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.white.withValues(alpha: selected ? 1 : 0.85),
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              )),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  البانر الرئيسي الفاخر (Slider)
// ═══════════════════════════════════════════════════════════════════════
class _PremiumBanner extends StatefulWidget {
  const _PremiumBanner();
  @override
  State<_PremiumBanner> createState() => _PremiumBannerState();
}

class _PremiumBannerState extends State<_PremiumBanner> {
  static const List<Map<String, dynamic>> _slides = [
    {'title': 'عروض سوجا الكبرى', 'sub': 'خصومات تصل إلى 50% لفترة محدودة', 'icon': Icons.local_fire_department_rounded},
    {'title': 'بدون أي عمولة',    'sub': 'فترة تجريبية كاملة للبائعين والمشترين', 'icon': Icons.card_giftcard_rounded},
    {'title': 'الدفع عند الاستلام', 'sub': 'اطلب بأمان وادفع عند وصول طلبك',      'icon': Icons.local_shipping_rounded},
  ];

  int _index = 0;
  late final PageController _ctrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.94);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_ctrl.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _ctrl.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() { _timer?.cancel(); _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(children: [
      SizedBox(
        height: 168,
        child: PageView.builder(
          controller: _ctrl,
          itemCount: _slides.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) {
            final s = _slides[i];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [colors.primaryDark, colors.primary],
                  begin: Alignment.topRight, end: Alignment.bottomLeft,
                ),
                boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: Stack(children: [
                Positioned(
                  left: -10, bottom: -30,
                  child: Icon(s['icon'] as IconData, size: 130, color: Colors.white.withValues(alpha: 0.12)),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(s['title'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(s['sub'] as String,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 12.5, height: 1.4)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(12)),
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                      child: Text('تسوّق الآن',
                          style: TextStyle(color: colors.primaryDark, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ]),
              ]),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_slides.length, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: active ? 22 : 7, height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active ? colors.primary : colors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      })),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  عنوان قسم بنمط موحّد + "عرض الكل"
// ═══════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String title;
  final String emoji;
  const _SectionHeader({required this.title, required this.emoji});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Text('$title $emoji', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: colors.textPrimary)),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          child: Row(children: [
            Text('عرض الكل', style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w600)),
            Icon(Icons.chevron_left_rounded, size: 16, color: colors.primary),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  صف أفقي من بطاقات المنتجات (يُستخدم لعدة أقسام)
// ═══════════════════════════════════════════════════════════════════════
class _ProductsRow extends StatelessWidget {
  final List<ProductModel> products;
  final void Function(BuildContext, ProductModel) onTap;
  final String? emptyText;
  const _ProductsRow({required this.products, required this.onTap, this.emptyText});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (products.isEmpty) {
      if (emptyText == null) return const SizedBox();
      return Center(child: Padding(padding: const EdgeInsets.all(24),
          child: Text(emptyText!, style: TextStyle(color: colors.textSecondary))));
    }
    return RepaintBoundary(
      child: SizedBox(
        height: 232,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: products.length,
          itemBuilder: (_, i) => ProductCard(product: products[i], onTap: () => onTap(context, products[i])),
        ),
      ),
    );
  }
}

// هيكل تحميل (نبض) لصف منتجات
class _RowSkeleton extends StatefulWidget {
  const _RowSkeleton();
  @override
  State<_RowSkeleton> createState() => _RowSkeletonState();
}

class _RowSkeletonState extends State<_RowSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 232,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 4,
          itemBuilder: (_, __) => Container(
            width: 158, margin: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              color: Color.lerp(colors.border.withValues(alpha: 0.35), colors.border.withValues(alpha: 0.75), _c.value),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorRetry({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(child: Column(children: [
      Icon(Icons.wifi_off_rounded, size: 52, color: colors.textHint),
      const SizedBox(height: 10),
      Text('تعذّر تحميل المنتجات', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('تحقق من الاتصال ثم أعد المحاولة', style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
    ]));
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  قسم عروض اليوم (Flash Deals) — يظهر فقط عند وجود صفقات فعلية
// ═══════════════════════════════════════════════════════════════════════
class _FlashDealsSection extends StatelessWidget {
  final List<ProductModel> deals;
  final void Function(BuildContext, ProductModel) onTap;
  const _FlashDealsSection({required this.deals, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final withCountdown = deals.where((p) => p.dealEndsAt != null && p.dealEndsAt!.isAfter(DateTime.now())).toList();
    final earliestEnd = withCountdown.isEmpty ? null : withCountdown
        .map((p) => p.dealEndsAt!)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Text('عروض اليوم 🔥', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const Spacer(),
          if (earliestEnd != null) _CountdownChip(endsAt: earliestEnd),
        ]),
      ),
      const SizedBox(height: 12),
      _ProductsRow(products: deals, onTap: onTap),
    ]);
  }
}

class _CountdownChip extends StatefulWidget {
  final DateTime endsAt;
  const _CountdownChip({required this.endsAt});
  @override
  State<_CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<_CountdownChip> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final diff = widget.endsAt.difference(DateTime.now());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: colors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_outlined, size: 13, color: colors.error),
        const SizedBox(width: 4),
        Text('$h:$m:$s', style: TextStyle(fontSize: 11.5, color: colors.error, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  عرض سريع للتصنيفات (شبكة أيقونات + عدد المنتجات)
// ═══════════════════════════════════════════════════════════════════════
class _CategoriesShowcase extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const _CategoriesShowcase({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 12, childAspectRatio: 0.85,
        children: kSougaCategories.map((c) => GestureDetector(
          onTap: () => onSelect(c.id),
          child: Column(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
              child: Icon(c.icon, color: colors.primary, size: 24),
            ),
            const SizedBox(height: 6),
            Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: colors.textSecondary)),
          ]),
        )).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  شارات الثقة "لماذا سوجا؟"
// ═══════════════════════════════════════════════════════════════════════
class _TrustBadgesRow extends StatelessWidget {
  const _TrustBadgesRow();
  static const _items = [
    {'icon': Icons.verified_user_outlined, 'label': 'دفع آمن'},
    {'icon': Icons.local_shipping_outlined, 'label': 'توصيل سريع'},
    {'icon': Icons.workspace_premium_outlined, 'label': 'منتجات مضمونة'},
    {'icon': Icons.support_agent_outlined, 'label': 'دعم 24/7'},
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: _items.map((it) => Column(children: [
        Icon(it['icon'] as IconData, color: colors.primary, size: 22),
        const SizedBox(height: 6),
        Text(it['label'] as String, style: TextStyle(fontSize: 10.5, color: colors.textSecondary)),
      ])).toList()),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  ✅ شبكة "جميع المنتجات" مُقسَّمة على صفحات — إصلاح مشكلة الأداء الأخطر
//  في المشروع (كانت تُحمِّل المجموعة كاملة بلا حدّ في كل مرة).
// ═══════════════════════════════════════════════════════════════════════
class _PaginatedProductsGrid extends StatefulWidget {
  final String category;
  final ValueListenable<int> loadMoreSignal;
  final void Function(BuildContext, ProductModel) onTap;
  const _PaginatedProductsGrid({
    super.key, required this.category, required this.loadMoreSignal, required this.onTap});

  @override
  State<_PaginatedProductsGrid> createState() => _PaginatedProductsGridState();
}

class _PaginatedProductsGridState extends State<_PaginatedProductsGrid> {
  static const int _pageSize = 12;
  final List<ProductModel> _products = [];
  DocumentSnapshot? _lastDoc;
  bool _loading = false;
  bool _hasMore = true;

  bool _error = false;
  bool _first = true; // قبل انتهاء أول تحميل: مؤشر بدل «لا توجد منتجات»

  @override
  void initState() {
    super.initState();
    widget.loadMoreSignal.addListener(_onSignal);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _loadMore(); });
  }

  @override
  void dispose() {
    widget.loadMoreSignal.removeListener(_onSignal);
    super.dispose();
  }

  // التمرير قرب النهاية → حمّل الصفحة التالية تلقائياً (لا تُعاد المحاولة تلقائياً بعد خطأ)
  void _onSignal() { if (!_error) _loadMore(); }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() { _loading = true; _error = false; });
    try {
      Query q = FirebaseFirestore.instance.collection('products');
      if (widget.category.isNotEmpty) { q = q.where('category', isEqualTo: widget.category); }
      q = q.orderBy('createdAt', descending: true).limit(_pageSize);
      if (_lastDoc != null) { q = q.startAfterDocument(_lastDoc!); }
      final snap = await q.get();
      if (snap.docs.isNotEmpty) { _lastDoc = snap.docs.last; }
      _hasMore = snap.docs.length == _pageSize;
      _products.addAll(snap.docs.map((d) => ProductModel.fromMap(d.data() as Map<String, dynamic>, d.id)));
    } catch (_) {
      _error = true;
    }
    if (mounted) setState(() { _loading = false; _first = false; });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_products.isEmpty) {
      if (_loading || _first) {
        return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
      }
      return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(24),
          child: Center(child: _error
              ? _ErrorRetry(onRetry: _loadMore)
              : Text('لا توجد منتجات', style: TextStyle(color: colors.textSecondary)))));
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverMainAxisGroup(slivers: [
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 0.62, crossAxisSpacing: 10, mainAxisSpacing: 10,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, i) => ProductCard(product: _products[i], isGrid: true, onTap: () => widget.onTap(context, _products[i])),
            childCount: _products.length,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: !_hasMore
                  ? Text('وصلت لنهاية القائمة', style: TextStyle(fontSize: 12, color: colors.textHint))
                  : OutlinedButton.icon(
                      onPressed: _loading ? null : _loadMore,
                      icon: _loading
                          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
                          : Icon(Icons.expand_more_rounded, color: colors.primary),
                      label: Text(_loading ? 'جاري التحميل...' : 'تحميل المزيد'),
                    ),
            ),
          ),
        ),
      ]),
    );
  }
}
