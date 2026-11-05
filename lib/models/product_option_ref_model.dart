// lib/models/product_option_ref_model.dart
//
// ✅ جزء من Universal Product Engine.
//
// يمثّل قيمة خيار واحدة *ضمن سياق منتج معيّن* (وليس تعريف الخاصية العام
// من attribute_model.dart). الفرق: AttributeOptionValue يقول "اللون
// الأحمر موجود كخيار ممكن في النظام"، بينما ProductOptionValueRef يقول
// "هذا المنتج تحديداً يعرض اللون الأحمر بدءاً من الصورة رقم 4 في معرضه".
//
// firstGalleryIndex هو ما يُتيح لـ ProductGalleryController القفز مباشرة
// عند الضغط على Thumbnail لون معيّن، وأيضاً معرفة "متى تغيّر activeColor
// أثناء السحب" بمقارنة رقم الصفحة الحالي بحدود كل مرجع.

class ProductOptionValueRef {
  final String valueId; // مطابق لـ AttributeOptionValue.id (مثال: 'red')
  final String label; // نسخة محلية من الاسم المعروض (تفادي جلب إضافي)
  final String? hex; // نسخة محلية من اللون إن وُجد
  final int firstGalleryIndex; // موضع أول صورة لهذه القيمة داخل gallery[]
  final bool isAvailable; // false = هذه القيمة نفدت لكل تركيباتها (Out of Stock)

  const ProductOptionValueRef({
    required this.valueId,
    required this.label,
    this.hex,
    required this.firstGalleryIndex,
    this.isAvailable = true,
  });

  factory ProductOptionValueRef.fromMap(Map<String, dynamic> map) {
    return ProductOptionValueRef(
      valueId: (map['valueId'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      hex: map['hex'] as String?,
      firstGalleryIndex: (map['firstGalleryIndex'] as num?)?.toInt() ?? 0,
      isAvailable: map['isAvailable'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
        'valueId': valueId,
        'label': label,
        if (hex != null) 'hex': hex,
        'firstGalleryIndex': firstGalleryIndex,
        'isAvailable': isAvailable,
      };
}
