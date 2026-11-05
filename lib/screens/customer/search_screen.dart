// lib/screens/customer/search_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_model.dart';
import '../../services/ai_assistant_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/categories.dart';
import '../../widgets/product_card.dart';
import 'product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<ProductModel> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _sortBy = 'newest';
  String _selectedCategory = '';

  // ✅ جديد — البحث الذكي (فهم اللغة الطبيعية/العامية العربية)
  // مبدأ العمل: البحث النصي الأساسي يعمل فوراً كما كان تماماً (بدون أي
  // تغيير)، والبحث الذكي يُطلَق بعد توقف الكتابة (debounce) ليُعيد ترتيب
  // النتائج فقط — لا يستبدل البحث الأساسي ولا يُعطّله عند فشله.
  Timer? _aiDebounce;
  bool _aiSearching = false;
  Map<String, String> _aiReasons = {}; // productId -> سبب الترشيح
  List<ProductModel> _categoryPool = []; // كل منتجات الفئة الحالية (قبل فلترة النص) — سياق أوسع للذكاء الاصطناعي



  // ✅ Debounce للبحث النصي الأساسي — كان سابقاً يُطلق استعلام Firestore
  // كامل عند كل ضغطة حرف؛ الآن يُطلَق فقط بعد توقف الكتابة 400ms.
  Timer? _searchDebounce;

  // ✅ التصنيفات الآن من مصدر واحد موحّد (utils/categories.dart) بدل نسخة
  // محلية منفصلة كانت غير متطابقة مع بقية شاشات المشروع.
  List<Map<String, dynamic>> get _categories => [
    {'name': 'الكل', 'id': ''},
    ...kSougaCategories.map((c) => {'name': c.name, 'id': c.id}),
  ];

  @override
  void dispose() {
    _aiDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// ✅ جديد — يُستدعى مباشرة من onChanged لحقل البحث؛ لا يُنفّذ البحث
  /// الفعلي فوراً، بل يؤجّله حتى يتوقف المستخدم عن الكتابة.
  void _onQueryChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty && _selectedCategory.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _aiReasons = {};
        _categoryPool = [];
      });
      _aiDebounce?.cancel();
      return;
    }
    setState(() { _isLoading = true; _hasSearched = true; });
    try {
      Query q = FirebaseFirestore.instance.collection('products');
      if (_selectedCategory.isNotEmpty) {
        q = q.where('category', isEqualTo: _selectedCategory);
      }
      // ✅ حدّ أقصى دفاعي — يمنع تنزيل مجموعة كاملة غير محدودة الحجم لكل
      // عملية بحث؛ حل مؤقت ريثما يُدمَج محرك بحث خارجي حقيقي (Algolia/
      // Typesense) كما أوصى تقرير المراجعة.
      q = q.limit(300);
      final snap = await q.get();
      final categoryProducts = snap.docs
          .map((d) => ProductModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();

      var products = categoryProducts;
      if (query.trim().isNotEmpty) {
        products = products.where((p) =>
            p.name.toLowerCase().contains(query.toLowerCase()) ||
            p.description.toLowerCase().contains(query.toLowerCase())).toList();
      }
      switch (_sortBy) {
        case 'price_asc': products.sort((a, b) => a.price.compareTo(b.price)); break;
        case 'price_desc': products.sort((a, b) => b.price.compareTo(a.price)); break;
        case 'rating': products.sort((a, b) => b.rating.compareTo(a.rating)); break;
        default: products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      setState(() {
        _results = products;
        _categoryPool = categoryProducts;
        _aiReasons = {};
      });
    } catch (e) {
      setState(() { _results = []; _categoryPool = []; _aiReasons = {}; });
    }
    setState(() => _isLoading = false);

    // ✅ إطلاق البحث الذكي مؤجَّلاً — لا يُستدعى عند كل حرف، فقط بعد توقف
    // الكتابة، ولا يُستدعى إطلاقاً لنص قصير جداً (أقل من 3 أحرف).
    _scheduleSmartSearch(query);
  }

  void _scheduleSmartSearch(String query) {
    _aiDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 3 || _categoryPool.isEmpty) {
      setState(() => _aiReasons = {});
      return;
    }
    _aiDebounce = Timer(const Duration(milliseconds: 700), () => _runSmartSearch(trimmed));
  }

  Future<void> _runSmartSearch(String query) async {
    if (!mounted || _categoryPool.isEmpty) return;
    setState(() => _aiSearching = true);

    // حد أقصى دفاعي 120 منتج — يطابق الحد على السيرفر ويُقلّل حجم الطلب
    final pool = _categoryPool.take(120).toList();
    final candidates = pool.map((p) => {
      'id': p.id,
      'name': p.name,
      'category': p.category,
      'price': p.price,
      'currencySymbol': p.currencySymbol,
    }).toList();

    final result = await AiAssistantService.smartSearch(query: query, products: candidates);

    if (!mounted) return;

    if (!result.isSuccess || result.results.isEmpty) {
      // فشل أو لا توجد مطابقات ذكية إضافية — نُبقي نتائج البحث النصي كما هي
      setState(() => _aiSearching = false);
      return;
    }

    final idMap = { for (final p in _categoryPool) p.id: p };
    final reasonMap = <String, String>{};
    final matchedProducts = <ProductModel>[];

    for (final item in result.results) {
      final product = idMap[item.id];
      if (product != null) {
        matchedProducts.add(product);
        if (item.reason.trim().isNotEmpty) {
          reasonMap[item.id] = item.reason.trim();
        }
      }
    }

    if (matchedProducts.isEmpty) {
      setState(() => _aiSearching = false);
      return;
    }

    // ترتيب جديد: المطابقات الذكية أولاً (بترتيب الأهمية من الذكاء
    // الاصطناعي)، ثم بقية نتائج البحث النصي الأساسي كما هي.
    final matchedIds = matchedProducts.map((p) => p.id).toSet();
    final remaining = _results.where((p) => !matchedIds.contains(p.id)).toList();

    setState(() {
      _results = [...matchedProducts, ...remaining];
      _aiReasons = reasonMap;
      _aiSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('البحث')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'ابحث عن منتج... جرّب "أريد هدية رخيصة لأمي"',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _search(''); })
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory == cat['id'];
                return GestureDetector(
                  onTap: () { setState(() => _selectedCategory = cat['id'] as String); _search(_searchController.text); },
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? colors.primary : colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? colors.primary : colors.border),
                    ),
                    child: Text(cat['name'] as String,
                        style: TextStyle(color: isSelected ? Colors.white : colors.textSecondary, fontSize: 13)),
                  ),
                );
              },
            ),
          ),
          if (_hasSearched)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('${_results.length} نتيجة', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  const SizedBox(width: 8),
                  // ✅ مؤشرات البحث الذكي — تظهر فقط عند الحاجة، لا تُشوّش الحالة العادية
                  if (_aiSearching)
                    _AiStatusChip(
                      icon: Icons.auto_awesome_rounded,
                      label: 'سوجا يبحث بذكاء...',
                      color: colors.primary,
                      showSpinner: true,
                    )
                  else if (_aiReasons.isNotEmpty)
                    _AiStatusChip(
                      icon: Icons.auto_awesome_rounded,
                      label: 'نتائج مرتّبة بالذكاء الاصطناعي',
                      color: colors.primary,
                    ),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _sortBy,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'newest', child: Text('الأحدث')),
                      DropdownMenuItem(value: 'price_asc', child: Text('الأقل سعراً')),
                      DropdownMenuItem(value: 'price_desc', child: Text('الأعلى سعراً')),
                      DropdownMenuItem(value: 'rating', child: Text('الأعلى تقييماً')),
                    ],
                    onChanged: (val) { setState(() => _sortBy = val!); _search(_searchController.text); },
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.search, size: 80, color: colors.border),
                        const SizedBox(height: 16),
                        Text('ابحث عن أي منتج', style: TextStyle(color: colors.textSecondary, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text('يفهم سوجا العربية الدارجة أيضاً ✨',
                            style: TextStyle(color: colors.textHint, fontSize: 12)),
                      ]))
                    : _results.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.search_off, size: 80, color: colors.border),
                            const SizedBox(height: 16),
                            Text('لا توجد نتائج', style: TextStyle(color: colors.textSecondary, fontSize: 16)),
                          ]))
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 10, mainAxisSpacing: 10),
                            itemCount: _results.length,
                            itemBuilder: (_, i) {
                              final product = _results[i];
                              final reason = _aiReasons[product.id];
                              return Stack(children: [
                                ProductCard(
                                  product: product, isGrid: true,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product))),
                                ),
                                // ✅ شارة صغيرة تُظهر سبب الترشيح الذكي عند الضغط المطوّل
                                if (reason != null)
                                  Positioned(
                                    top: 6, left: 6,
                                    child: Tooltip(
                                      message: reason,
                                      triggerMode: TooltipTriggerMode.tap,
                                      decoration: BoxDecoration(
                                        color: colors.primaryDark,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      textStyle: const TextStyle(color: Colors.white, fontSize: 11),
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          gradient: colors.primaryGradient,
                                          shape: BoxShape.circle,
                                          boxShadow: [BoxShadow(
                                              color: colors.primary.withValues(alpha: 0.4),
                                              blurRadius: 4)],
                                        ),
                                        child: const Icon(Icons.auto_awesome_rounded,
                                            size: 11, color: Colors.white),
                                      ),
                                    ),
                                  ),
                              ]);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ── شارة حالة صغيرة لعرض مؤشرات البحث الذكي بجانب عداد النتائج ─────────────────
class _AiStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool showSpinner;
  const _AiStatusChip({
    required this.icon,
    required this.label,
    required this.color,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (showSpinner)
          SizedBox(
            width: 10, height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
          )
        else
          Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
