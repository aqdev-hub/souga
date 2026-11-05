// lib/models/gallery_item_model.dart
//
// ✅ جزء من Universal Product Engine — Gallery Engine.
//
// كل عنصر في معرض المنتج يحمل "role" صريحاً (وليس فقط ربطاً بخاصية) —
// هذا هو الفرق الجوهري الذي شدَّدت عليه: الـ role يحدد أين يظهر العنصر في
// الـ Timeline (فيديو أولاً، ثم Hero، ثم صور المنتج العامة، ثم صور
// الألوان، ثم صور المقاسات...)، بينما optionKey/optionValueId يحدد فقط
// *أي قيمة خاصية* يتبعها هذا العنصر عندما يكون role من نوع مرتبط بخاصية
// (color/size/other) — الاثنان منفصلان تماماً ولا يُشتق أحدهما من الآخر.
//
// كل الحقول هنا تخدم بنداً محدداً من طلبك:
//  - role                → ترتيب الـ Timeline والانتماء لقسم الـ Thumbnail Bar
//  - optionKey/optionValueId → لتوليد firstGalleryIndex لكل Option مستقبلاً
//  - thumbnailUrl اختياري → لتحسين أداء شريط المصغرات (صورة أصغر مخصصة)

enum GalleryItemRole {
  video, // فيديو المنتج (اختياري، يظهر أولاً إن وُجد)
  hero, // الصورة الرئيسية (دائماً موجودة لأي منتج)
  item, // صور عامة إضافية للمنتج (لا تظهر في شريط المصغرات، تصفّح بالسحب فقط)
  color, // صورة مرتبطة بقيمة لون معيّنة
  size, // صورة مرتبطة بقيمة مقاس معيّنة
  other; // ✅ أي خاصية مستقبلية أخرى (Storage, Material...) بدون تعديل الكود —
  // يُستخدم optionKey لتحديد اسم الخاصية الفعلي عند هذا النوع.

  String get storageKey => name;

  static GalleryItemRole fromStorageKey(String? key) {
    return GalleryItemRole.values.firstWhere(
      (r) => r.storageKey == key,
      // ✅ توافق مستقبلي: أي قيمة role غير معروفة (أُضيفت بنسخة تطبيق أحدث
      // مثلاً) تُعامَل كـ "item" بدل رمي استثناء — لا يكسر التطبيق أبداً.
      orElse: () => GalleryItemRole.item,
    );
  }
}

class GalleryItemModel {
  final String url;
  final String? thumbnailUrl;
  final GalleryItemRole role;
  final String? optionKey; // مثال: 'color' — فقط عندما role مرتبط بخاصية
  final String? optionValueId; // مثال: 'red' — معرّف القيمة المحددة

  const GalleryItemModel({
    required this.url,
    this.thumbnailUrl,
    required this.role,
    this.optionKey,
    this.optionValueId,
  });

  bool get isVideo => role == GalleryItemRole.video;

  /// هل يظهر هذا العنصر في شريط المصغرات؟ (Hero + Color + Size + Other
  /// المرتبطة بخاصية فقط — وليس item العامة كما طلبت صراحة).
  bool get showsInThumbnailBar =>
      role == GalleryItemRole.hero ||
      role == GalleryItemRole.color ||
      role == GalleryItemRole.size ||
      (role == GalleryItemRole.other && optionKey != null);

  factory GalleryItemModel.fromMap(Map<String, dynamic> map) {
    return GalleryItemModel(
      url: (map['url'] ?? '').toString(),
      thumbnailUrl: (map['thumbnailUrl'] as String?)?.trim().isNotEmpty == true
          ? map['thumbnailUrl'] as String
          : null,
      role: GalleryItemRole.fromStorageKey(map['role'] as String?),
      optionKey: map['optionKey'] as String?,
      optionValueId: map['optionValueId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'url': url,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        'role': role.storageKey,
        if (optionKey != null) 'optionKey': optionKey,
        if (optionValueId != null) 'optionValueId': optionValueId,
      };

  GalleryItemModel copyWith({
    String? url,
    String? thumbnailUrl,
    GalleryItemRole? role,
    String? optionKey,
    String? optionValueId,
  }) {
    return GalleryItemModel(
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      role: role ?? this.role,
      optionKey: optionKey ?? this.optionKey,
      optionValueId: optionValueId ?? this.optionValueId,
    );
  }
}
