// lib/models/attribute_favorite.dart
//
// ✅ مفضلة بائع: خاصية مخصّصة أو لون أنشأه البائع، محفوظة لكل فئة رئيسية.
// تُخزّن التعريف والقيم فقط (لا أسعار ولا كميات ولا صور منتج).
// المسار: users/{uid}/attributeFavorites/{id} — خاصة بالبائع.

import '../utils/search_text.dart';

class FavoriteValue {
  final String label;
  final String? hex;
  const FavoriteValue(this.label, {this.hex});

  factory FavoriteValue.fromMap(Map<String, dynamic> m) =>
      FavoriteValue((m['label'] ?? '').toString(), hex: (m['hex'] as String?)?.isNotEmpty == true ? m['hex'] as String : null);

  Map<String, dynamic> toMap() => {'label': label, if (hex != null) 'hex': hex};
}

class AttributeFavorite {
  final String id;
  final String rootCategoryId;
  final String type; // 'attribute' | 'color'
  final String name; // اسم الخاصية، أو اسم اللون عند type == color
  final String kind; // للخاصية: 'options' | 'spec' | 'measure' | 'color'
  final List<FavoriteValue> values; // للون: قيمة واحدة بالـ hex
  final String? unitId; // وحدة القياس إن وُجدت

  const AttributeFavorite({
    required this.id,
    required this.rootCategoryId,
    required this.type,
    required this.name,
    this.kind = 'options',
    this.values = const [],
    this.unitId,
  });

  bool get isColor => type == 'color';
  String? get hex => values.isNotEmpty ? values.first.hex : null;

  /// معرّف حتمي يمنع التكرار: نفس (الفئة + النوع + الاسم/الـ hex) → نفس المستند.
  static String buildId(String rootCategoryId, String type, String name, {String? hex}) {
    final core = type == 'color' ? (hex ?? name).replaceAll('#', '').toLowerCase() : normalizeSearch(name);
    final safe = core.replaceAll(RegExp(r'[\s/\\.#\[\]*~`$]+'), '_');
    final id = '${type == 'color' ? 'c' : 'a'}__${rootCategoryId}__$safe';
    return id.length > 180 ? id.substring(0, 180) : id;
  }

  factory AttributeFavorite.fromMap(Map<String, dynamic> m, String id) => AttributeFavorite(
        id: id,
        rootCategoryId: (m['rootCategoryId'] ?? '').toString(),
        type: (m['type'] ?? 'attribute').toString(),
        name: (m['name'] ?? '').toString(),
        kind: (m['kind'] ?? 'options').toString(),
        values: [
          for (final v in (m['values'] as List<dynamic>? ?? const []))
            FavoriteValue.fromMap(Map<String, dynamic>.from(v as Map)),
        ],
        unitId: m['unitId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'rootCategoryId': rootCategoryId,
        'type': type,
        'name': name,
        'kind': kind,
        'values': values.map((v) => v.toMap()).toList(),
        if (unitId != null) 'unitId': unitId,
      };
}
