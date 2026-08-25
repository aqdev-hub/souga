// lib/models/category_model.dart
//
// ✅ جزء من Universal Product Engine — شجرة فئات حقيقية بدل قائمة مسطّحة
// كانت مكرَّرة سابقاً بنسخ غير متطابقة في 5 ملفات مختلفة (راجع تقرير
// المراجعة). لا يوجد حد لعدد المستويات — parentId فقط هو ما يحدد الشجرة.
//
// ملاحظة تصميم مهمة: لا يوجد حقل "isLeaf" مُخزَّن هنا عمداً — كون الفئة
// "ورقية" (بلا أبناء) هو خاصية مُشتقّة من الشجرة الكاملة وقت القراءة
// (راجع CategoryNode في category_repository.dart)، وليس حقلاً يُخزَّن قد
// يصبح غير متزامن مع الواقع (Stale) عند إضافة/حذف فئات فرعية لاحقاً.

class CategoryModel {
  final String id;
  final String name;
  // ✅ لا يمكن تخزين IconData في Firestore مباشرة — نخزّن مفتاحاً نصياً
  // ويُحلّ لأيقونة فعلية عبر خريطة صغيرة في طبقة العرض (utils/categories.dart)
  final String iconKey;
  final String? parentId; // null = فئة جذرية (رئيسية)
  final int order; // ترتيب العرض بين أخواتها
  // ✅ الخصائص (Attributes) المرتبطة بهذه الفئة تحديداً — هذا ما يجعل
  // الخصائص ديناميكية بالكامل حسب الفئة المختارة، بدل أي قائمة ثابتة في الكود.
  final List<String> attributeIds;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.iconKey,
    this.parentId,
    this.order = 0,
    this.attributeIds = const [],
  });

  bool get isRoot => parentId == null || parentId!.isEmpty;

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CategoryModel(
      id: id,
      name: (map['name'] ?? '').toString(),
      iconKey: (map['iconKey'] ?? 'category').toString(),
      parentId: (map['parentId'] as String?)?.trim().isEmpty == true
          ? null
          : map['parentId'] as String?,
      order: (map['order'] as num?)?.toInt() ?? 0,
      attributeIds: List<String>.from(map['attributeIds'] ?? const []),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'iconKey': iconKey,
        'parentId': parentId,
        'order': order,
        'attributeIds': attributeIds,
      };
}

/// عقدة شجرة — تُبنى في الذاكرة من القائمة المسطّحة (لا تُخزَّن في Firestore).
class CategoryNode {
  final CategoryModel category;
  final List<CategoryNode> children;
  final CategoryNode? parent;

  CategoryNode({required this.category, List<CategoryNode>? children, this.parent})
      : children = children ?? [];

  /// ✅ "ورقية" = لا تملك أبناءً — تُحسَب من الشجرة الفعلية وقت القراءة،
  /// فتبقى صحيحة دائماً حتى لو أُضيفت فئات فرعية جديدة لاحقاً.
  bool get isLeaf => children.isEmpty;

  int get depth => parent == null ? 0 : parent!.depth + 1;

  /// كل معرّفات الخصائص المتوارثة من الفئة نفسها + كل آبائها (فئة "هواتف"
  /// الفرعية ترث خصائص "إلكترونيات" الأب إن وُجدت، إضافة لخصائصها الخاصة).
  List<String> get inheritedAttributeIds {
    final ids = <String>{...category.attributeIds};
    var p = parent;
    while (p != null) {
      ids.addAll(p.category.attributeIds);
      p = p.parent;
    }
    return ids.toList();
  }
}
