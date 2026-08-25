// lib/models/product_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'gallery_item_model.dart';
import 'product_option_ref_model.dart';

class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final List<String> images;
  final int stock;
  final String sellerId;
  final String sellerName;
  final String sellerLogo;        // شعار المتجر
  final String storeDescription;  // وصف المتجر
  final double rating;
  final int reviewCount;
  final int displayWeight;
  final String currencyCode;
  final String currencySymbol;
  final DateTime createdAt;
  // ✅ جديد — اختياريان بالكامل (null افتراضياً)، لا يكسران أي منتج قديم:
  // originalPrice: السعر قبل الخصم (لعرض شارة الخصم في بطاقة المنتج).
  // dealEndsAt: نهاية عرض "صفقة اليوم" (لعرض عدّاد تنازلي في قسم العروض).
  final double? originalPrice;
  final DateTime? dealEndsAt;

  // ═══════════════════════════════════════════════════════════════════
  //  ✅ Universal Product Engine — حقول جديدة، كلها اختيارية بقيم
  //  افتراضية آمنة. أي منتج قديم في Firestore لا يملك هذه الحقول يُقرأ
  //  ويعمل بلا أي تغيير في السلوك (categoryId فارغ يعني استخدام category
  //  المسطّح القديم كما هو، hasVariants=false يعني منتج بسيط تقليدي).
  // ═══════════════════════════════════════════════════════════════════

  /// معرّف الفئة الجديد (شجرة هرمية). فارغ = لم يُهاجَر بعد، استخدم
  /// [category] المسطّح القديم كـ fallback (نفس السلوك الحالي تماماً).
  final String categoryId;

  /// خصائص وصفية فقط (isVariant=false) — مثال: {'ram': '8GB', 'battery': '5000mAh'}.
  /// {} افتراضياً = لا يظهر قسم Specifications إطلاقاً (Conditional Rendering).
  final Map<String, String> attributes;

  /// محرك المعرض الكامل (فيديو + صور بأدوارها). [] افتراضياً يعني: استخدم
  /// [images] القديمة كصور Hero/Item عادية (يُبنى تلقائياً عبر [effectiveGallery]).
  final List<GalleryItemModel> gallery;

  /// لكل خاصية "متغيّر" (مثال 'color')، قائمة القيم الفعلية المعروضة لهذا
  /// المنتج تحديداً مع فهرس أول صورة لها في gallery. {} افتراضياً = بلا متغيرات.
  final Map<String, List<ProductOptionValueRef>> optionSets;

  /// هل لهذا المنتج تركيبات SKU حقيقية (subcollection variants)؟
  final bool hasVariants;

  /// أسماء الخصائص المستخدمة كمتغيرات لهذا المنتج، بالترتيب (مثال: ['color','size']).
  final List<String> variantKeys;

  /// ✅ تمثّل صور[images] القديمة كعناصر Gallery (role=hero لأول صورة،
  /// item للباقي) عندما لا يوجد [gallery] فعلي بعد — يضمن عمل شاشة تفاصيل
  /// المنتج الجديدة مع كل منتج قديم دون أي ترحيل بيانات يدوي.
  List<GalleryItemModel> get effectiveGallery {
    if (gallery.isNotEmpty) return gallery;
    if (images.isEmpty) return const [];
    return [
      GalleryItemModel(url: images.first, role: GalleryItemRole.hero),
      for (final img in images.skip(1))
        GalleryItemModel(url: img, role: GalleryItemRole.item),
    ];
  }

  /// معرّف الفئة الفعلي المستخدَم للفلترة/العرض — يفضّل الجديد الهرمي إن
  /// وُجد، وإلا يسقط تلقائياً (Fallback) لحقل category المسطّح القديم.
  String get effectiveCategoryId => categoryId.isNotEmpty ? categoryId : category;

  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  int get discountPercent =>
      hasDiscount ? (((originalPrice! - price) / originalPrice!) * 100).round() : 0;
  bool get isActiveDeal =>
      hasDiscount && dealEndsAt != null && dealEndsAt!.isAfter(DateTime.now());

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.images,
    required this.stock,
    required this.sellerId,
    required this.sellerName,
    this.sellerLogo        = '',
    this.storeDescription  = '',
    this.rating = 0.0,
    this.reviewCount = 0,
    this.displayWeight   = 5,
    this.currencyCode   = "SAR",
    this.currencySymbol = "RS",
    required this.createdAt,
    this.originalPrice,
    this.dealEndsAt,
    this.categoryId = '',
    this.attributes = const {},
    this.gallery = const [],
    this.optionSets = const {},
    this.hasVariants = false,
    this.variantKeys = const [],
  });

  String get firstImage => images.isNotEmpty ? images[0] : '';

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime createdAt;
    final raw = map['createdAt'];
    if (raw is Timestamp) {
      createdAt = raw.toDate();
    } else if (raw is DateTime) {
      createdAt = raw;
    } else {
      createdAt = DateTime.now();
    }

    return ProductModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      stock: map['stock'] ?? 0,
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      sellerLogo: (map['sellerLogo'] ?? '').toString(),
      storeDescription: (map['storeDescription'] ?? '').toString(),
      rating: (map['rating'] ?? 0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      displayWeight:   (map['displayWeight'] as num?)?.toInt() ?? 5,
      currencyCode:   (map['currencyCode']   ?? 'SAR').toString(),
      currencySymbol: (map['currencySymbol'] ?? 'RS').toString(),
      createdAt: createdAt,
      originalPrice: map['originalPrice'] != null ? (map['originalPrice'] as num).toDouble() : null,
      dealEndsAt: map['dealEndsAt'] is Timestamp ? (map['dealEndsAt'] as Timestamp).toDate() : null,
      categoryId: (map['categoryId'] ?? '').toString(),
      attributes: Map<String, String>.from(
        (map['attributes'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? const {},
      ),
      gallery: (map['gallery'] as List<dynamic>? ?? const [])
          .map((e) => GalleryItemModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      optionSets: (map['optionSets'] as Map<String, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>? ?? const [])
              .map((e) => ProductOptionValueRef.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList(),
        ),
      ),
      hasVariants: map['hasVariants'] == true,
      variantKeys: List<String>.from(map['variantKeys'] ?? const []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'images': images,
      'stock': stock,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'rating': rating,
      'reviewCount': reviewCount,
      'displayWeight':  displayWeight,
      'currencyCode':   currencyCode,
      'currencySymbol': currencySymbol,
      'createdAt': createdAt,
      if (originalPrice != null) 'originalPrice': originalPrice,
      if (dealEndsAt != null) 'dealEndsAt': dealEndsAt,
      if (categoryId.isNotEmpty) 'categoryId': categoryId,
      if (attributes.isNotEmpty) 'attributes': attributes,
      if (gallery.isNotEmpty) 'gallery': gallery.map((e) => e.toMap()).toList(),
      if (optionSets.isNotEmpty)
        'optionSets': optionSets.map(
          (key, values) => MapEntry(key, values.map((e) => e.toMap()).toList()),
        ),
      'hasVariants': hasVariants,
      if (variantKeys.isNotEmpty) 'variantKeys': variantKeys,
    };
  }

  ProductModel copyWith({
    String? name, String? description, double? price,
    String? category, List<String>? images, int? stock,
    double? rating, int? reviewCount, int? displayWeight,
  }) {
    return ProductModel(
      id: id, sellerId: sellerId, sellerName: sellerName, createdAt: createdAt,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      images: images ?? this.images,
      stock: stock ?? this.stock,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      displayWeight: displayWeight ?? this.displayWeight,
    );
  }
}
