// lib/models/cart_model.dart

class CartItem {
  final String productId;
  final String name;
  // ✅ Snapshot: سعر الوحدة الفعلي وقت الإضافة إلى السلة — سواء كان سعر
  // المنتج الأساسي (منتج تقليدي بلا متغيرات) أو سعر التركيبة (variant)
  // المختارة تحديداً. لا يُعاد حسابه أو ربطه حياً بالمنتج/التركيبة بعد
  // الإضافة — يبقى ثابتاً حتى لو تغيّر سعر المنتج لاحقاً في Firestore،
  // تماماً كما هو مطلوب لسلامة عرض السلة.
  final double price;
  int quantity;
  final String image;
  final String sellerId;
  final String sellerName;
  final String currencySymbol;  // ✅ عملة المنتج الأصلية
  final String currencyCode;

  // ═══════════════════════════════════════════════════════════════════
  //  ✅ Variant-aware Cart — Universal Product Engine
  //  كلاهما null لمنتج تقليدي بلا متغيرات (السلوك القديم كما هو تماماً،
  //  توافق خلفي كامل — أي CartItem محفوظ سابقاً في SharedPreferences
  //  يُقرأ بلا أي مشكلة، الحقلان الجديدان يُصبحان null تلقائياً).
  // ═══════════════════════════════════════════════════════════════════

  /// معرّف التركيبة المختارة (= ProductVariantModel.id/sku وقت الإضافة).
  /// يُستخدَم كجزء من "المفتاح المنطقي" لسطر السلة في CartProvider، حتى لا
  /// يختلط "قميص أحمر S" مع "قميص أزرق XL" كسطر واحد بالخطأ.
  final String? variantId;

  /// Snapshot جاهز للعرض فقط — تسميات عربية وليست معرّفات (مثال:
  /// {'اللون': 'أحمر', 'المقاس': 'XL'})؛ عمداً تسميات وليست ids حتى لا
  /// يتأثر عرض عنصر في السلة بأي تعديل/حذف لاحق على تعريف الخاصية نفسها.
  final Map<String, String>? variantOptionValues;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.image,
    required this.sellerId,
    required this.sellerName,
    this.currencySymbol = 'RS',
    this.currencyCode   = 'SAR',
    this.variantId,
    this.variantOptionValues,
  });

  double get total => price * quantity;

  /// هل هذا السطر يخص منتجاً بمتغيرات؟ (تسهيل قراءة بدل `variantId != null` مباشرة)
  bool get hasVariant => variantId != null;

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productId:      map['productId']      ?? '',
      name:           map['name']           ?? '',
      price:          (map['price']         ?? 0).toDouble(),
      quantity:       map['quantity']       ?? 1,
      image:          map['image']          ?? '',
      sellerId:       map['sellerId']       ?? '',
      sellerName:     map['sellerName']     ?? '',
      currencySymbol: map['currencySymbol'] ?? 'RS',
      currencyCode:   map['currencyCode']   ?? 'SAR',
      variantId: (map['variantId'] as String?)?.trim().isNotEmpty == true
          ? map['variantId'] as String
          : null,
      variantOptionValues: map['variantOptionValues'] != null
          ? Map<String, String>.from(map['variantOptionValues'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId':      productId,
      'name':           name,
      'price':          price,
      'quantity':       quantity,
      'image':          image,
      'sellerId':       sellerId,
      'sellerName':     sellerName,
      'currencySymbol': currencySymbol,
      'currencyCode':   currencyCode,
      if (variantId != null) 'variantId': variantId,
      if (variantOptionValues != null) 'variantOptionValues': variantOptionValues,
    };
  }
}
