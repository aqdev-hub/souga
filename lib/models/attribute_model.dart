// lib/models/attribute_model.dart
//
// ✅ جزء من Universal Product Engine.
//
// الفرق الجوهري الذي يحكم كل النظام: isVariant.
//   isVariant == true   → خاصية "متغيّر" (اللون، المقاس...) — أي اختيار
//                          لقيمة منها يُنتج تركيبة SKU مستقلة بسعر/مخزون
//                          خاص بها (راجع variant_repository.dart).
//   isVariant == false  → خاصية "مواصفة" وصفية بحتة (الرام، البطارية...)
//                          تُعرض فقط في قسم Specifications، ولا علاقة لها
//                          بالمخزون أو السعر أو المعرض.
//
// هذا الفصل هو ما يمنع النظام من افتراض "أن كل خاصية = لون أو مقاس" كما
// كان الوضع سابقاً — كل خاصية مستقلة تماماً، وأي خاصية جديدة (Voltage,
// Length...) تُضاف من قاعدة البيانات فقط بلا أي تعديل على كود Dart.

enum AttributeType {
  select, // قائمة اختيار نصية (مثل: نوع القماش)
  colorSwatch, // قائمة اختيار بعينات لونية (يعرض دائرة لونية بدل نص فقط)
  text, // نص حر (مثال: نص وصفي قصير كخاصية)
  number, // رقم (مثال: سنة الصنع)
  boolean; // نعم/لا (مثال: مقاوم للماء)

  String get storageKey => name;

  static AttributeType fromStorageKey(String? key) {
    return AttributeType.values.firstWhere(
      (t) => t.storageKey == key,
      // ✅ توافق مستقبلي — نوع غير معروف يُعامَل كنص حر بدل كسر التطبيق.
      orElse: () => AttributeType.text,
    );
  }
}

class AttributeOptionValue {
  final String id; // معرّف ثابت يُستخدم داخل optionValues/SKU (مثال: 'red')
  final String label; // الاسم المعروض (مثال: 'أحمر')
  final String? hex; // للون فقط — مثال: '#DC143C'

  const AttributeOptionValue({required this.id, required this.label, this.hex});

  factory AttributeOptionValue.fromMap(Map<String, dynamic> map) => AttributeOptionValue(
        id: (map['id'] ?? '').toString(),
        label: (map['label'] ?? '').toString(),
        hex: map['hex'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        if (hex != null) 'hex': hex,
      };
}

class AttributeDefinitionModel {
  final String id;
  final String key; // مفتاح مستقر يُستخدم برمجياً (مثال: 'color', 'ram')
  final String name; // الاسم المعروض بالعربية (مثال: 'اللون', 'الرام')
  final AttributeType type;
  final bool isVariant;
  final List<AttributeOptionValue> predefinedValues;
  final int order;

  const AttributeDefinitionModel({
    required this.id,
    required this.key,
    required this.name,
    required this.type,
    required this.isVariant,
    this.predefinedValues = const [],
    this.order = 0,
  });

  factory AttributeDefinitionModel.fromMap(Map<String, dynamic> map, String id) {
    return AttributeDefinitionModel(
      id: id,
      key: (map['key'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      type: AttributeType.fromStorageKey(map['type'] as String?),
      isVariant: map['isVariant'] == true,
      predefinedValues: (map['predefinedValues'] as List<dynamic>? ?? [])
          .map((e) => AttributeOptionValue.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'key': key,
        'name': name,
        'type': type.storageKey,
        'isVariant': isVariant,
        'predefinedValues': predefinedValues.map((e) => e.toMap()).toList(),
        'order': order,
      };
}
