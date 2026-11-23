// lib/models/product_variant_model.dart
//
// ✅ جزء من Universal Product Engine.
//
// كل تركيبة (SKU) هي مستند مستقل داخل subcollection وليست عنصراً في
// مصفوفة داخل مستند المنتج — القرار المعماري وموجباته موثَّقان في خطة
// التنفيذ المعتمدة (تعديل سعر/مخزون تركيبة واحدة لا يعيد كتابة المنتج
// بالكامل، ويسمح لاحقاً باستعلامات مباشرة على المخزون).

class ProductVariantModel {
  final String id; // معرّف المستند في Firestore (نفس sku عادةً)
  final String sku;
  // مثال: {'color': 'red', 'size': 'xl'} — المفاتيح هي attribute.key
  // والقيم هي AttributeOptionValue.id
  final Map<String, String> optionValues;
  final double price; // سعر خاص بهذه التركيبة (يُبنى افتراضياً من سعر المنتج الأساسي)
  final double originalPrice; // السعر قبل الخصم لهذه التركيبة (0 = بلا خصم)
  final int stock;
  final bool isActive; // يسمح بإخفاء تركيبة نفدت نهائياً بدل حذفها

  const ProductVariantModel({
    required this.id,
    required this.sku,
    required this.optionValues,
    required this.price,
    required this.stock,
    this.isActive = true,
    this.originalPrice = 0,
  });

  factory ProductVariantModel.fromMap(Map<String, dynamic> map, String id) {
    return ProductVariantModel(
      id: id,
      sku: (map['sku'] ?? id).toString(),
      optionValues: Map<String, String>.from(map['optionValues'] ?? const {}),
      price: (map['price'] ?? 0).toDouble(),
      originalPrice: (map['originalPrice'] ?? 0).toDouble(),
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
        'sku': sku,
        'optionValues': optionValues,
        'price': price,
        // 0 يُكتب صراحة عند إزالة الخصم حتى لا يبقى سعر قديم بسبب merge
        'originalPrice': originalPrice,
        'stock': stock,
        'isActive': isActive,
      };

  ProductVariantModel copyWith({double? price, double? originalPrice, int? stock, bool? isActive}) {
    return ProductVariantModel(
      id: id,
      sku: sku,
      optionValues: optionValues,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
    );
  }
}
