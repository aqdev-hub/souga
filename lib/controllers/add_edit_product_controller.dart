// lib/controllers/add_edit_product_controller.dart
//
// ✅ Universal Product Engine — المرحلة الأخيرة (State Management للـ
// Stepper الجديد ذي الست خطوات). كل المنطق هنا فقط (ChangeNotifier) — الـ
// UI (add_edit_product_stepper_screen.dart) لن يحتوي أي قرار بنيوي، فقط
// Rendering + استدعاء دوال هذا الكونترولر، بنفس فلسفة
// ProductGalleryController تماماً.
//
// خوارزمية "أي خطوات تظهر" (computeVisibleSteps) تحقّقت من صحتها بمحاكاة
// Python بـ 6 حالات اختبار (فئة بلا أي خصائص، وصفية فقط، متغيرات متاحة
// غير مفعّلة، متغيرات مفعّلة، الحالة الكاملة...) قبل ترجمتها هنا.
//
// الخطوات الست (بالترتيب الثابت — الفهرس هو المعرّف):
//   0) الفئة            — دائماً ظاهرة
//   1) معلومات أساسية   — دائماً ظاهرة (اسم/وصف/سعر/عملة/صور)
//   2) مواصفات وصفية    — شرطية: فقط إن كانت الفئة تملك خصائص isVariant=false
//   3) اختيار المتغيرات — شرطية: فقط إن كانت الفئة تملك خصائص isVariant=true
//   4) تركيبات SKU      — شرطية: فقط إن فعَّل البائع "له متغيرات" فعلياً واختار قيماً
//   5) المعرض والمراجعة — دائماً ظاهرة (تُبنى منها gallery/optionSets النهائية)

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/attribute_model.dart';
import '../models/category_model.dart';
import '../models/gallery_item_model.dart';
import '../models/product_model.dart';
import '../models/product_option_ref_model.dart';
import '../models/product_variant_model.dart';
import '../models/attribute_favorite.dart';
import '../repositories/attribute_favorites_repository.dart';
import '../repositories/attribute_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/variant_repository.dart';
import '../services/ai_assistant_service.dart';
import '../services/push_notification_service.dart';
import '../services/seo_rebuild_service.dart';
import '../utils/arabic_plural.dart';
import '../utils/currencies.dart';
import '../utils/measure_units.dart';
import '../utils/ready_colors.dart';

/// تركيبة SKU واحدة قيد التحرير — قبل الحفظ (لا تحمل id حقيقياً بعد، يُبنى
/// SKU الفعلي فقط عند save() لأنه يحتاج productId الحقيقي من Firestore).
class VariantDraft {
  final Map<String, String> optionValues; // مثال: {'color': 'red', 'size': 'xl'}
  double price;
  double originalPrice; // السعر قبل الخصم (0 = بلا خصم)
  int stock;
  bool isActive;

  VariantDraft({
    required this.optionValues,
    required this.price,
    this.originalPrice = 0,
    this.stock = 0,
    this.isActive = true,
  });

  /// نص وصفي قصير للعرض (مثال: "أحمر / XL") — يُبنى من labels وليس ids.
  String describeWith(Map<String, List<AttributeOptionValue>> valuesByKey) {
    final parts = <String>[];
    optionValues.forEach((key, valueId) {
      final match = (valuesByKey[key] ?? const []).where((v) => v.id == valueId);
      parts.add(match.isNotEmpty ? match.first.label : valueId);
    });
    return parts.join(' / ');
  }

  bool _sameOptions(Map<String, String> other) {
    if (other.length != optionValues.length) return false;
    for (final entry in optionValues.entries) {
      if (other[entry.key] != entry.value) return false;
    }
    return true;
  }
}

class AddEditProductController extends ChangeNotifier {
  final CategoryRepository categoryRepo;
  final AttributeRepository attributeRepo;
  final ProductRepository productRepo;
  final VariantRepository variantRepo;
  final AttributeFavoritesRepository favoritesRepo;

  /// null = وضع "إضافة منتج جديد"، غير null = وضع "تعديل".
  final ProductModel? existingProduct;

  // ✅ بيانات البائع تُمرَّر صراحة من الشاشة (مبنية من AuthProvider) بدل أن
  // يعتمد الكونترولر على Provider مباشرة — يبقيه قابلاً للاختبار بمعزل تام.
  final String sellerId;
  final String sellerName;
  final String sellerLogo;
  final String storeDescription;

  AddEditProductController({
    required this.sellerId,
    required this.sellerName,
    this.sellerLogo = '',
    this.storeDescription = '',
    this.existingProduct,
    CategoryRepository? categoryRepo,
    AttributeRepository? attributeRepo,
    ProductRepository? productRepo,
    VariantRepository? variantRepo,
    AttributeFavoritesRepository? favoritesRepo,
  })  : categoryRepo = categoryRepo ?? CategoryRepository(),
        attributeRepo = attributeRepo ?? AttributeRepository(),
        productRepo = productRepo ?? ProductRepository(),
        variantRepo = variantRepo ?? VariantRepository(),
        favoritesRepo = favoritesRepo ?? AttributeFavoritesRepository() {
    _initControllers();
    unawaited(_init());
  }

  bool get isEditing => existingProduct != null;

  /// ✅ إعادة بناء عامة — تُستخدَم عندما تُعدَّل قيمة TextEditingController
  /// مباشرة من الواجهة (مثال: حوار رابط الفيديو) بدل عبر دالة مخصَّصة في
  /// الكونترولر، فلا يُستدعى notifyListeners تلقائياً بخلاف ذلك.
  void refresh() => notifyListeners();

  // ═══════════════════════════════════════════════════════════════════
  //  الخطوة 0 — الفئة
  // ═══════════════════════════════════════════════════════════════════
  bool loadingCategories = true;
  String? categoriesError;
  List<CategoryNode> categoryTree = [];
  CategoryNode? selectedCategory;

  bool loadingAttributes = false;
  List<AttributeDefinitionModel> _categoryAttributes = const [];

  /// ✅ الخصائص الوصفية = خصائص الفئة + الخصائص التي أضافها البائع بنفسه
  /// (نوع "مواصفة ثابتة"). كلها تمر من نفس المسار فتُعرَض وتُحفَظ بالأسلوب ذاته.
  List<AttributeDefinitionModel> get descriptiveAttributes => [
        ..._categoryAttributes.where((a) => !a.isVariant),
        ...customAttributeDefs.where((a) => !a.isVariant),
      ];

  /// ✅ خصائص المتغيرات = خصائص الفئة + خصائص البائع من نوع "خيارات"/"ألوان".
  /// بما أنها هنا فهي تدخل تلقائياً في توليد التركيبات (SKU) والسعر والمخزون
  /// وmatrix الخيارات عند المشتري، تماماً كالخصائص الجاهزة.
  List<AttributeDefinitionModel> get variantAttributesAvailable => [
        ..._categoryAttributes.where((a) => a.isVariant),
        ...customAttributeDefs.where((a) => a.isVariant),
      ];

  Future<void> _init() async {
    loadingCategories = true;
    notifyListeners();
    try {
      final flat = await categoryRepo.fetchAll();
      categoryTree = CategoryRepository.buildTree(flat);
      categoriesError = null;

      // ✅ وضع التعديل: نحاول إيجاد الفئة الحالية للمنتج تلقائياً
      // (categoryId الجديد أولاً، وإلا category المسطّح القديم كـ fallback)
      // بدل إجبار البائع على إعادة اختيارها من الصفر.
      if (existingProduct != null) {
        final currentId = existingProduct!.effectiveCategoryId;
        final found = CategoryRepository.findById(categoryTree, currentId);
        if (found != null) {
          await selectCategory(found, resetDependents: false);
        }
      }
    } catch (e) {
      categoriesError = 'تعذّر تحميل الفئات: $e';
    }
    loadingCategories = false;
    notifyListeners();
  }

  Future<void> retryLoadCategories() => _init();

  /// اختيار فئة جديدة (يجب أن تكون ورقية — بلا أبناء — للاختيار النهائي).
  /// [resetDependents]: false فقط عند التحميل الأولي في وضع التعديل (لأن
  /// القيم الوصفية/المتغيرات تُهيَّأ لاحقاً من بيانات المنتج نفسه بدل تصفيرها).
  Future<void> selectCategory(CategoryNode node, {bool resetDependents = true}) async {
    selectedCategory = node;
    if (resetDependents) {
      customSubcategoryLabel = null; // اختيار فئة رسمية يلغي أي فئة فرعية مقترَحة
      attributeValues.clear();
      hasVariants = false;
      selectedVariantValueIds.clear();
      variantDrafts.clear();
      customAttributeDefs.clear();
      customOptionValues.clear();
    }
    loadingAttributes = true;
    notifyListeners();

    try {
      _categoryAttributes = await attributeRepo.fetchByIds(node.inheritedAttributeIds);
    } catch (e) {
      _categoryAttributes = const [];
    }

    // ✅ وضع التعديل عند أول تحميل: نُعيد بناء الحالة من بيانات المنتج
    // الفعلية بدل تركها فارغة — البائع يفتح شاشة التعديل ويجد كل شيء كما تركه.
    if (!resetDependents && existingProduct != null) {
      _hydrateFromExistingProduct();
    }

    loadingAttributes = false;
    notifyListeners();
  }

  void _hydrateFromExistingProduct() {
    final p = existingProduct!;
    customSubcategoryLabel = p.customSubcategory.isNotEmpty ? p.customSubcategory : null;
    attributeValues
      ..clear()
      ..addAll(p.attributes);
    // ✅ الخصائص المخفية عن المشتري تعود ظاهرة للبائع مع علامة "مخفية".
    hiddenFromBuyerKeys.clear();
    for (final e in p.hiddenAttributes.entries) {
      attributeValues[e.key] = e.value;
      hiddenFromBuyerKeys.add(e.key);
    }
    hasVariants = p.hasVariants;
    selectedVariantValueIds.clear();
    customOptionValues.clear();
    customAttributeDefs.clear();
    for (final entry in p.optionSets.entries) {
      selectedVariantValueIds[entry.key] = entry.value.map((v) => v.valueId).toSet();
      // ✅ إعادة بناء أي قيمة "مخصَّصة" (أُضيفت سابقاً عبر "+ لون/مقاس آخر"
      // ولا تنتمي لقائمة predefinedValues الرسمية للخاصية) من Snapshot
      // المنتج نفسه (label/hex محفوظان بالفعل في ProductOptionValueRef) —
      // بدون هذا، فتح المنتج للتعديل كان سيُظهر قيمة غير معروفة بلا تسمية.
      final attrMatch = _categoryAttributes.where((a) => a.isVariant && a.key == entry.key);
      if (attrMatch.isEmpty) {
        // خاصية أضافها البائع بنفسه ("+ إضافة خاصية أخرى"): نُعيد إنشاءها.
        final hasHex = entry.value.any((v) => (v.hex ?? '').isNotEmpty);
        customAttributeDefs.add(AttributeDefinitionModel(
          id: 'custom_${entry.key}',
          key: entry.key,
          name: _knownLabels[entry.key] ?? entry.key,
          type: (entry.key == 'color' || hasHex) ? AttributeType.colorSwatch : AttributeType.select,
          isVariant: true,
        ));
        for (final ref in entry.value) {
          customOptionValues.putIfAbsent(entry.key, () => []).add(
            AttributeOptionValue(id: ref.valueId, label: ref.label, hex: ref.hex),
          );
        }
        continue;
      }
      final officialIds = attrMatch.first.predefinedValues.map((v) => v.id).toSet();
      for (final ref in entry.value) {
        if (!officialIds.contains(ref.valueId)) {
          customOptionValues.putIfAbsent(entry.key, () => []).add(
            AttributeOptionValue(id: ref.valueId, label: ref.label, hex: ref.hex),
          );
        }
      }
    }
    // وحدة القياس تُستنتج من التسميات المحفوظة ("5 لتر") لتبقى الإضافة اللاحقة بنفس الوحدة.
    attributeUnits.clear();
    for (final entry in p.optionSets.entries) {
      final u = inferMeasureUnit(entry.value.map((v) => v.label));
      if (u != null) attributeUnits[entry.key] = u;
    }
    // ✅ مواصفات أضافها البائع (مفاتيح attributes غير المعرَّفة في الفئة):
    // كانت تُحفَظ لكنها تختفي من شاشة التعديل — نُعيدها الآن كخصائص ظاهرة.
    final knownDescriptive = _categoryAttributes.where((a) => !a.isVariant).map((a) => a.key).toSet();
    for (final entry in attributeValues.entries) {
      if (knownDescriptive.contains(entry.key)) continue;
      if (p.optionSets.containsKey(entry.key)) continue;
      customAttributeDefs.add(AttributeDefinitionModel(
        id: 'custom_${entry.key}',
        key: entry.key,
        name: _knownLabels[entry.key] ?? entry.key,
        type: AttributeType.select,
        isVariant: false,
      ));
      if (entry.value.trim().isNotEmpty) {
        customOptionValues.putIfAbsent(entry.key, () => []).add(
          AttributeOptionValue(id: 'custom_${entry.key}_0', label: entry.value),
        );
      }
    }
    // ✅ خطوة 5 (المعرض): نُعيد ترتيب الحقول من p.gallery الفعلية إن
    // وُجدت، وإلا من effectiveGallery (Fallback للمنتجات القديمة بصور فقط).
    final gallery = p.gallery.isNotEmpty ? p.gallery : p.effectiveGallery;
    for (final item in gallery) {
      switch (item.role) {
        case GalleryItemRole.video:
          videoUrlCtrl.text = item.url;
          break;
        case GalleryItemRole.hero:
          heroUrl = item.url;
          break;
        case GalleryItemRole.item:
          itemImageUrls.add(item.url);
          break;
        case GalleryItemRole.color:
          if (item.optionValueId != null) colorImageUrls[item.optionValueId!] = item.url;
          break;
        case GalleryItemRole.size:
          if (item.optionValueId != null) sizeImageUrls[item.optionValueId!] = item.url;
          break;
        case GalleryItemRole.other:
          if (item.optionValueId != null && item.optionKey != null) otherImageUrls[item.optionValueId!] = item.url;
          break;
      }
    }
    images = List.of(p.images);
    _regenerateDrafts(preserveExisting: false); // سنُعيد ملء الأسعار/المخزون من الـ variants الحقيقية أدناه
  }

  /// ✅ يُستدعى من الشاشة بعد التحميل الأولي عندما تصل بيانات
  /// subcollection/variants الحقيقية (عبر VariantRepository.fetchAll) —
  /// يملأ السعر/المخزون الحقيقيين بدل القيم الافتراضية في المسودات.
  void hydrateVariantDrafts(List<ProductVariantModel> realVariants) {
    for (final draft in variantDrafts) {
      final match = realVariants.where((v) => draft._sameOptions(v.optionValues));
      if (match.isNotEmpty) {
        draft.price = match.first.price;
        draft.originalPrice = match.first.originalPrice;
        draft.stock = match.first.stock;
        draft.isActive = match.first.isActive;
      }
    }
    notifyListeners();
  }

  /// جذر الفئة (يمشي للأعلى حتى فئة بلا أب) — يُستخدم لملء الحقل المسطّح
  /// القديم `category` بقيمة متوافقة مع كل الشاشات القديمة (الرئيسية/البحث)
  /// التي لا تزال تُصفّي بحقل category المسطّح بقيم جذرية فقط (electronics،
  /// clothes...)، بدل الفئات الفرعية الجديدة (electronics_phones) التي لا
  /// تُطابِق أي قيمة تصفية قديمة.
  static String rootCategoryId(CategoryNode node) {
    var n = node;
    while (n.parent != null) {
      n = n.parent!;
    }
    return n.category.id;
  }

  // ✅ جديد — "+ إضافة فئة فرعية أخرى" (مطابقة التصميم المعتمد): يسمح
  // للبائع باقتراح اسم فئة فرعية غير موجودة بعد في شجرة الفئات الرسمية،
  // بدل تعطيله عن نشر منتجه بانتظار أن تُضيف الإدارة الفئة الرسمية. هذا
  // اسم نصّي للعرض فقط (لا يُنشئ CategoryNode حقيقياً ولا يُغيّر
  // categoryId/category الفعليين المبنيين من selectedCategory الحالي).
  String? customSubcategoryLabel;

  /// الجذر الحالي للفئة المختارة (أو null).
  CategoryNode? get currentRootCategory {
    var n = selectedCategory;
    if (n == null) return null;
    while (n!.parent != null) {
      n = n.parent;
    }
    return n;
  }

  /// ✅ "+ إضافة فئة فرعية أخرى": الفئة الفرعية التي كتبها البائع (مثل
  /// "سماعات") **تحلّ محل** الفئة الفرعية الرسمية — يصير المنتج:
  /// الرئيسية = إلكترونيات، الفرعية = سماعات. (وليس إلكترونيات > هواتف > سماعات).
  /// تُعتمَد الفئة الجذرية فعلياً (categoryId/category) وتُحفَظ التسمية في
  /// customSubcategory، وتُستخدَم خصائص الجذر.
  Future<void> setCustomSubcategory(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      clearCustomSubcategory();
      return;
    }
    final root = currentRootCategory;
    if (root == null) return;
    if (selectedCategory != root) {
      await selectCategory(root); // يصفّر customSubcategoryLabel والقيم المعتمدة على الفئة
    }
    customSubcategoryLabel = trimmed;
    notifyListeners();
  }

  void clearCustomSubcategory() {
    customSubcategoryLabel = null;
    notifyListeners();
  }

  /// الفئة الفرعية بصيغة العرض: المخصَّصة إن وُجدت، وإلا الرسمية.
  String subcategoryDisplayName(CategoryNode? node) {
    if (customSubcategoryLabel != null && customSubcategoryLabel!.isNotEmpty) {
      return customSubcategoryLabel!;
    }
    return node?.category.name ?? '';
  }

  // ═══════════════════════════════════════════════════════════════════
  //  الخطوة 1 — معلومات أساسية
  // ═══════════════════════════════════════════════════════════════════
  late final TextEditingController nameCtrl;
  late final TextEditingController shortDescCtrl; // ✅ جديد — وصف مختصر سطر واحد (مطابقة التصميم المعتمد)
  late final TextEditingController descCtrl;
  late final TextEditingController priceCtrl;
  late final TextEditingController originalPriceCtrl;
  late final TextEditingController stockCtrl; // يُستخدم فقط عندما !hasVariants

  SougaCurrency selectedCurrency = kSougaCurrencies.first;
  List<String> images = []; // روابط مرفوعة (Legacy + تُستخدم كأساس لصور hero/item)
  bool uploadingImage = false;

  /// ✅ جديد — حالة المنتج: 'new' | 'used' (مطابقة التصميم المعتمد)
  String condition = 'new';
  void setCondition(String value) {
    condition = value;
    notifyListeners();
  }

  // ✅ إعادة تفعيل ميزة "تحسين الوصف بالذكاء الاصطناعي" (كانت موجودة في
  // الشاشة القديمة add_product_screen.dart وتوقّفت عن العمل بعد إعادة
  // بناء الشاشة الجديدة كـ Stepper — أُعيدت هنا بنفس السلوك تماماً).
  bool isEnhancingDescription = false;
  String? descriptionEnhanceError;

  /// يقصّ النص عند آخر نهاية جملة قبل [max] حرفاً (شبكة أمان: التحسين
  /// التسويقي يجب أن يبقى مختصراً حتى لو أطال النموذج).
  static String _capLength(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    final cut = t.substring(0, max);
    final end = [cut.lastIndexOf('.'), cut.lastIndexOf('!'), cut.lastIndexOf('؟'), cut.lastIndexOf('\n')]
        .reduce((x, y) => x > y ? x : y);
    return (end > max ~/ 2 ? cut.substring(0, end + 1) : cut).trim();
  }

  /// ✅ يحسّن الوصف المختصر والتفصيلي معاً (كل حقل بطول ≥ 5 أحرف) بأسلوب
  /// تسويقي موجز. الحقل الذي يفشل تحسينه يبقى كما كتبه البائع.
  Future<void> enhanceDescription({required String category, required String priceText}) async {
    if (isEnhancingDescription) return;
    final shortRaw = shortDescCtrl.text.trim();
    final longRaw = descCtrl.text.trim();
    if (shortRaw.length < 5 && longRaw.length < 5) return;

    isEnhancingDescription = true;
    descriptionEnhanceError = null;
    notifyListeners();

    final name = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'منتج';
    Future<String?> run(String raw, {required bool isShort}) async {
      final r = await AiAssistantService.enhanceDescription(
        mode: isShort ? 'short' : 'long',
        maxChars: isShort ? 110 : 380,
        productName: name,
        category: category,
        rawDescription: raw,
        price: priceText,
        currencySymbol: selectedCurrency.symbol,
      );
      if (r.isSuccess) return r.enhanced;
      descriptionEnhanceError = r.errorMessage ?? 'تعذّر تحسين الوصف';
      return null;
    }

    final results = await Future.wait<String?>([
      shortRaw.length >= 5 ? run(shortRaw, isShort: true) : Future.value(null),
      longRaw.length >= 5 ? run(longRaw, isShort: false) : Future.value(null),
    ]);

    if (results[0] != null) shortDescCtrl.text = _capLength(results[0]!, 110);
    if (results[1] != null) {
      descCtrl.text = _capLength(results[1]!, 380);
      descCtrl.selection = TextSelection.fromPosition(TextPosition(offset: descCtrl.text.length));
    }
    // نجاح جزئي كافٍ: لا نعرض خطأ إن تحسّن أحد الحقلين على الأقل.
    if (results[0] != null || results[1] != null) descriptionEnhanceError = null;
    isEnhancingDescription = false;
    notifyListeners();
  }

  void _initControllers() {
    final p = existingProduct;
    nameCtrl = TextEditingController(text: p?.name ?? '');
    shortDescCtrl = TextEditingController(text: p?.shortDescription ?? '');
    descCtrl = TextEditingController(text: p?.description ?? '');
    priceCtrl = TextEditingController(text: p != null ? p.price.toString() : '');
    originalPriceCtrl = TextEditingController(
      text: p?.originalPrice != null ? p!.originalPrice.toString() : '',
    );
    stockCtrl = TextEditingController(text: p != null ? p.stock.toString() : '');
    unifiedPriceCtrl = TextEditingController();
    unifiedOriginalCtrl = TextEditingController();
    unifiedStockCtrl = TextEditingController();
    videoUrlCtrl = TextEditingController(); // يُملأ لاحقاً في _hydrateFromExistingProduct إن وُجد فيديو
    if (p != null) {
      images = List.of(p.images);
      condition = p.condition;
      final matched = kSougaCurrencies.where((c) => c.code == p.currencyCode);
      selectedCurrency = matched.isNotEmpty ? matched.first : kSougaCurrencies.first;
    }
  }

  void setCurrency(SougaCurrency c) {
    selectedCurrency = c;
    notifyListeners();
  }

  void addImageUrl(String url) {
    images.add(url);
    heroUrl ??= url; // ✅ أول صورة تُرفَع تصبح Hero تلقائياً إن لم تُحدَّد واحدة بعد
    notifyListeners();
  }

  void removeImageUrl(String url) {
    images.remove(url);
    if (heroUrl == url) heroUrl = images.isNotEmpty ? images.first : null;
    itemImageUrls.remove(url);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  الخطوة 2 — مواصفات وصفية (isVariant == false)
  // ═══════════════════════════════════════════════════════════════════
  final Map<String, String> attributeValues = {}; // attribute.key -> النص/التسمية المختارة

  void setAttributeValue(String key, String value) {
    if (value.trim().isEmpty) {
      attributeValues.remove(key);
    } else {
      attributeValues[key] = value;
    }
    notifyListeners();
  }

  /// ✅ "+ إضافة خاصية أخرى": خاصية يعرّفها البائع بنفسه (الحجم، الرام،
  /// التخزين، المعالج، الموديل، بلد الصنع...). تتحوّل إلى [AttributeDefinitionModel]
  /// كاملة فتعمل تماماً كالخصائص الجاهزة: شرائح قيم + زر "إضافة قيمة" +
  /// (للخيارات) توليد تركيبات بسعر/مخزون لكل خيار.
  final List<AttributeDefinitionModel> customAttributeDefs = [];

  /// أسماء عربية للمفاتيح المعروفة (عند إعادة بناء خاصية من منتج محفوظ).
  static const Map<String, String> _knownLabels = {
    'color': 'اللون', 'size': 'المقاس', 'ram': 'الرام', 'storage': 'التخزين',
    'material': 'نوع القماش', 'processor': 'المعالج', 'battery': 'البطارية',
    'brand': 'العلامة التجارية',
  };

  bool isCustomAttribute(String key) => customAttributeDefs.any((a) => a.key == key);

  static final RegExp _illegalKeyChars = RegExp(r'[./\[\]*~`#$]');

  /// يضيف الخاصية. يُعيد null عند النجاح أو رسالة خطأ عربية.
  /// [kind]: 'options' (خيارات للمشتري بسعر/مخزون)، 'color' (عينات ألوان)،
  /// 'spec' (مواصفة ثابتة للمنتج بلا تأثير على السعر/المخزون).
  String? addCustomAttribute(String label, {String kind = 'options'}) {
    final name = label.trim().replaceAll(_illegalKeyChars, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (name.isEmpty) return 'اكتب اسم الخاصية';
    final isVariant = kind != 'spec';
    final isColor = kind == 'color';

    // تعيين لمفاتيح النظام عند التطابق التام حتى تعمل صور الألوان/المقاسات في
    // المعرض وعينات اللون عند المشتري (بشرط ألا تكون الفئة تعرّفها أصلاً).
    var key = name;
    var displayName = name;
    final taken = {
      ..._categoryAttributes.map((a) => a.key),
      ...customAttributeDefs.map((a) => a.key),
    };
    if (isColor && (name == 'اللون' || name == 'لون') && !taken.contains('color')) {
      key = 'color';
      displayName = 'اللون';
    } else if (isVariant && !isColor && (name == 'المقاس' || name == 'مقاس') && !taken.contains('size')) {
      key = 'size';
      displayName = 'المقاس';
    }

    final names = {
      ..._categoryAttributes.map((a) => a.name),
      ...customAttributeDefs.map((a) => a.name),
    };
    if (taken.contains(key) || names.contains(displayName)) {
      return 'هذه الخاصية موجودة بالفعل';
    }

    customAttributeDefs.add(AttributeDefinitionModel(
      id: 'custom_$key',
      key: key,
      name: displayName,
      type: isColor ? AttributeType.colorSwatch : AttributeType.select,
      isVariant: isVariant,
    ));
    notifyListeners();
    return null;
  }

  void removeCustomAttribute(String key) {
    customAttributeDefs.removeWhere((a) => a.key == key);
    attributeValues.remove(key);
    customOptionValues.remove(key);
    selectedVariantValueIds.remove(key);
    if (selectedVariantValueIds.isEmpty) hasVariants = false;
    _regenerateDrafts();
    notifyListeners();
  }

  /// قيمة جديدة لخاصية "مواصفة": تُضاف كشريحة وتُختار فوراً (اختيار واحد).
  void addCustomSpecValue(String attrKey, String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final list = customOptionValues.putIfAbsent(attrKey, () => []);
    if (!list.any((v) => v.label == trimmed)) {
      list.add(AttributeOptionValue(
        id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
        label: trimmed,
      ));
    }
    attributeValues[attrKey] = trimmed;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  الخطوة 3 — اختيار المتغيرات (isVariant == true)
  // ═══════════════════════════════════════════════════════════════════
  bool hasVariants = false;
  final Map<String, Set<String>> selectedVariantValueIds = {}; // key -> {valueId, ...}

  void setHasVariants(bool value) {
    hasVariants = value;
    if (!value) selectedVariantValueIds.clear();
    _regenerateDrafts();
    notifyListeners();
  }

  void toggleVariantValue(String attrKey, String valueId) {
    final set = selectedVariantValueIds.putIfAbsent(attrKey, () => <String>{});
    if (set.contains(valueId)) {
      set.remove(valueId);
    } else {
      set.add(valueId);
    }
    if (set.isEmpty) selectedVariantValueIds.remove(attrKey);
    _regenerateDrafts();
    notifyListeners();
  }

  bool isVariantValueSelected(String attrKey, String valueId) =>
      selectedVariantValueIds[attrKey]?.contains(valueId) ?? false;

  // ✅ جديد — "+ لون آخر" / "+ مقاس آخر" (مطابقة التصميم المعتمد): يسمح
  // للبائع بإضافة قيمة خيار (Option Value) خاصة بهذا المنتج تحديداً، غير
  // موجودة في القائمة المعرَّفة مسبقاً على مستوى النظام (attribute_definitions).
  // تُخزَّن محلياً فقط لهذا المنتج، وتُعامَل بنفس آلية القيم الرسمية تماماً
  // (SKU/optionSets/gallery) — الفرق الوحيد أنها لا تُضاف لقائمة الخيارات
  // العامة التي يراها بائعون آخرون.
  final Map<String, List<AttributeOptionValue>> customOptionValues = {};

  /// كل القيم المتاحة لعرضها لخاصية معيّنة = الرسمية المعرَّفة مسبقاً + أي
  /// قيم مخصَّصة أضافها البائع لهذا المنتج تحديداً.
  List<AttributeOptionValue> optionValuesFor(AttributeDefinitionModel attr) {
    final removed = _removedPredefined[attr.key] ?? const <String>{};
    final overrides = _valueOverrides[attr.key] ?? const <String, AttributeOptionValue>{};
    return [
      for (final v in attr.predefinedValues)
        if (!removed.contains(v.id)) overrides[v.id] ?? v,
      ...(customOptionValues[attr.key] ?? const []),
    ];
  }

  /// إيجاد القيمة (تسمية/لون) لأي valueId ضمن خاصية معيّنة — رسمية أو مخصَّصة.
  AttributeOptionValue? resolveOptionValue(AttributeDefinitionModel attr, String valueId) {
    final all = optionValuesFor(attr);
    final match = all.where((v) => v.id == valueId);
    return match.isNotEmpty ? match.first : null;
  }

  /// يضيف قيمة مخصَّصة ويختارها فوراً كخيار للمنتج.
  void addCustomOptionValue(String attrKey, String label, {String? hex}) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final id = 'custom_${DateTime.now().microsecondsSinceEpoch}';
    customOptionValues.putIfAbsent(attrKey, () => []).add(
      AttributeOptionValue(id: id, label: trimmed, hex: hex),
    );
    if (!hasVariants) hasVariants = true;
    selectedVariantValueIds.putIfAbsent(attrKey, () => <String>{}).add(id);
    _regenerateDrafts();
    notifyListeners();
  }

  /// وحدة القياس المعتمدة لكل خاصية (إن اختار البائع وحدة): key → وحدة.
  final Map<String, MeasureUnit> attributeUnits = {};

  /// ✅ إضافة عدة قيم دفعة واحدة لخاصية اختيارية (5، 7، 12 لتر) أو بلا وحدة
  /// (S، M، L). تُختار كلها فوراً. القيمة الموجودة مسبقاً (رسمية أو مخصَّصة) بنفس
  /// التسمية لا تتكرر — تُختار فقط. تُعيد عدد القيم التي أُضيفت/اختيرت.
  int addVariantValues(String attrKey, List<String> labels, {MeasureUnit? unit}) {
    if (unit != null) attributeUnits[attrKey] = unit;
    final attrMatches = variantAttributesAvailable.where((a) => a.key == attrKey);
    final known = attrMatches.isNotEmpty ? optionValuesFor(attrMatches.first) : (customOptionValues[attrKey] ?? const <AttributeOptionValue>[]);
    final list = customOptionValues.putIfAbsent(attrKey, () => []);
    final selected = selectedVariantValueIds.putIfAbsent(attrKey, () => <String>{});
    final stamp = DateTime.now().microsecondsSinceEpoch;
    var n = 0;
    for (var i = 0; i < labels.length; i++) {
      final label = labels[i].trim();
      if (label.isEmpty) continue;
      final dup = known.where((v) => v.label.trim().toLowerCase() == label.toLowerCase());
      if (dup.isNotEmpty) {
        selected.add(dup.first.id);
      } else {
        final id = 'custom_${stamp}_$i';
        list.add(AttributeOptionValue(id: id, label: label));
        selected.add(id);
      }
      n++;
    }
    if (selected.isEmpty) selectedVariantValueIds.remove(attrKey);
    if (n > 0 && !hasVariants) hasVariants = true;
    _regenerateDrafts();
    notifyListeners();
    return n;
  }

  /// تسميات القيم الموجودة لخاصية (للتحقق من التكرار في نافذة الإدخال).
  List<String> existingValueLabels(String attrKey) {
    final a = attributeByKey(attrKey);
    if (a == null) return [for (final v in customOptionValues[attrKey] ?? const <AttributeOptionValue>[]) v.label];
    return [for (final v in optionValuesFor(a)) v.label];
  }


  // ═══════════════════════════════════════════════════════════════════
  //  ✅ إدارة الخصائص والقيم (القسم 2): إعادة تسمية، حذف، تعطيل، إخفاء عن المشتري
  //  • خصائص الفئة الرسمية: تُعطَّل/تُفعَّل وتُدار قيمها (تعديل/حذف/تعطيل) لهذا المنتج فقط؛
  //    اسمها ثابت لأن المشتري والبحث يقرآن تعريفها من النظام.
  //  • خصائص البائع (المضافة/الجاهزة/المفضلة): إعادة تسمية وحذف كاملان.
  // ═══════════════════════════════════════════════════════════════════
  final Set<String> disabledAttrKeys = {};
  final Set<String> hiddenFromBuyerKeys = {};
  final Map<String, Set<String>> _removedPredefined = {};
  final Map<String, Map<String, AttributeOptionValue>> _valueOverrides = {};
  final Map<String, Set<String>> _stashedSelection = {};
  final Map<String, String> _stashedValue = {};

  AttributeDefinitionModel? attributeByKey(String key) {
    for (final a in [..._categoryAttributes, ...customAttributeDefs]) {
      if (a.key == key) return a;
    }
    return null;
  }

  bool isAttributeEnabled(String key) => !disabledAttrKeys.contains(key);

  /// تعطيل خاصية = لا تُحفظ ولا تدخل التركيبات، مع حفظ اختيارات البائع مؤقتاً لاسترجاعها عند إعادة التفعيل.
  void setAttributeEnabled(String key, bool enabled) {
    final attr = attributeByKey(key);
    if (attr == null) return;
    if (enabled) {
      disabledAttrKeys.remove(key);
      final sel = _stashedSelection.remove(key);
      if (sel != null && sel.isNotEmpty) {
        selectedVariantValueIds[key] = sel;
        hasVariants = true;
      }
      final v = _stashedValue.remove(key);
      if (v != null && v.isNotEmpty) attributeValues[key] = v;
    } else {
      disabledAttrKeys.add(key);
      final sel = selectedVariantValueIds.remove(key);
      if (sel != null && sel.isNotEmpty) _stashedSelection[key] = sel;
      final v = attributeValues.remove(key);
      if (v != null && v.isNotEmpty) _stashedValue[key] = v;
      if (selectedVariantValueIds.isEmpty) hasVariants = false;
    }
    _regenerateDrafts();
    notifyListeners();
  }

  /// إخفاء/إظهار خاصية وصفية عن المشتري (تبقى محفوظة للبائع).
  void setHiddenFromBuyer(String key, bool hidden) {
    if (hidden) {
      hiddenFromBuyerKeys.add(key);
    } else {
      hiddenFromBuyerKeys.remove(key);
    }
    notifyListeners();
  }

  /// إعادة تسمية خاصية البائع. المفتاح هو الاسم نفسه (كما تُحفظ وتُعرض للمشتري)،
  /// لذا تُنقل كل الارتباطات (قيم، اختيارات، تركيبات، وحدة) إلى المفتاح الجديد.
  String? renameAttribute(String oldKey, String newName) {
    final idx = customAttributeDefs.indexWhere((a) => a.key == oldKey);
    if (idx < 0) return 'لا يمكن إعادة تسمية خاصية الفئة الرسمية';
    final name = newName.trim().replaceAll(_illegalKeyChars, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (name.isEmpty) return 'اكتب اسم الخاصية';
    if (name == oldKey) return null;
    final taken = {
      ..._categoryAttributes.map((a) => a.key),
      ..._categoryAttributes.map((a) => a.name),
      ...customAttributeDefs.where((a) => a.key != oldKey).map((a) => a.key),
      ...customAttributeDefs.where((a) => a.key != oldKey).map((a) => a.name),
    };
    if (taken.contains(name)) return 'هذه الخاصية موجودة بالفعل';
    final old = customAttributeDefs[idx];
    customAttributeDefs[idx] = AttributeDefinitionModel(
      id: 'custom_$name', key: name, name: name, type: old.type, isVariant: old.isVariant,
      predefinedValues: old.predefinedValues, order: old.order,
    );
    T? mv<T>(Map<String, T> m) {
      if (!m.containsKey(oldKey)) return null;
      final v = m.remove(oldKey) as T;
      m[name] = v;
      return v;
    }
    mv(attributeValues);
    mv(customOptionValues);
    mv(selectedVariantValueIds);
    mv(attributeUnits);
    mv(_stashedSelection);
    mv(_stashedValue);
    mv(_removedPredefined);
    mv(_valueOverrides);
    if (disabledAttrKeys.remove(oldKey)) disabledAttrKeys.add(name);
    if (hiddenFromBuyerKeys.remove(oldKey)) hiddenFromBuyerKeys.add(name);
    for (final d in variantDrafts) {
      if (d.optionValues.containsKey(oldKey)) {
        final v = d.optionValues.remove(oldKey)!;
        d.optionValues[name] = v;
      }
    }
    notifyListeners();
    return null;
  }

  /// تعديل نص/لون قيمة. القيم الرسمية تُعدَّل لهذا المنتج فقط (الـ id ثابت فتبقى التركيبات سليمة).
  String? editOptionValue(String attrKey, String valueId, String newLabel, {String? hex}) {
    final label = newLabel.trim();
    if (label.isEmpty) return 'اكتب اسم القيمة';
    final attr = attributeByKey(attrKey);
    if (attr == null) return null;
    final clash = optionValuesFor(attr).any((v) => v.id != valueId && v.label.trim().toLowerCase() == label.toLowerCase());
    if (clash) return 'هذه القيمة موجودة بالفعل';
    final custom = customOptionValues[attrKey];
    final ci = custom?.indexWhere((v) => v.id == valueId) ?? -1;
    if (ci >= 0) {
      final old = custom![ci];
      final wasSpecSelected = attributeValues[attrKey] == old.label;
      custom[ci] = AttributeOptionValue(id: valueId, label: label, hex: hex ?? old.hex);
      if (wasSpecSelected) attributeValues[attrKey] = label;
    } else {
      final base = attr.predefinedValues.where((v) => v.id == valueId);
      if (base.isEmpty) return null;
      final wasSpecSelected = attributeValues[attrKey] == base.first.label;
      (_valueOverrides[attrKey] ??= {})[valueId] = AttributeOptionValue(id: valueId, label: label, hex: hex ?? base.first.hex);
      if (wasSpecSelected) attributeValues[attrKey] = label;
    }
    notifyListeners();
    return null;
  }

  /// حذف قيمة (للمنتج الحالي): المخصّصة تُمسح، والرسمية تُخفى. تُزال التركيبات المرتبطة بها.
  void removeOptionValue(String attrKey, String valueId) {
    final attr = attributeByKey(attrKey);
    final label = attr == null ? null : resolveOptionValue(attr, valueId)?.label;
    final custom = customOptionValues[attrKey];
    final removedCustom = custom?.any((v) => v.id == valueId) ?? false;
    if (removedCustom) {
      custom!.removeWhere((v) => v.id == valueId);
    } else {
      (_removedPredefined[attrKey] ??= {}).add(valueId);
    }
    final sel = selectedVariantValueIds[attrKey];
    if (sel != null) {
      sel.remove(valueId);
      if (sel.isEmpty) selectedVariantValueIds.remove(attrKey);
    }
    if (label != null && attributeValues[attrKey] == label) attributeValues.remove(attrKey);
    colorImageUrls.remove(valueId);
    sizeImageUrls.remove(valueId);
    otherImageUrls.remove(valueId);
    if (selectedVariantValueIds.isEmpty) hasVariants = false;
    _regenerateDrafts();
    notifyListeners();
  }

  /// تفعيل/تعطيل قيمة: للخيارات = إتاحتها للمشتري، وللمواصفات = اختيارها كقيمة المنتج.
  void setValueEnabled(String attrKey, String valueId, bool enabled) {
    final attr = attributeByKey(attrKey);
    if (attr == null) return;
    if (attr.isVariant) {
      if (isVariantValueSelected(attrKey, valueId) != enabled) {
        if (enabled && !hasVariants) hasVariants = true;
        toggleVariantValue(attrKey, valueId);
      }
    } else {
      final label = resolveOptionValue(attr, valueId)?.label;
      if (label == null) return;
      setAttributeValue(attrKey, enabled ? label : '');
    }
  }

  bool isValueEnabled(String attrKey, String valueId) {
    final attr = attributeByKey(attrKey);
    if (attr == null) return false;
    if (attr.isVariant) return isVariantValueSelected(attrKey, valueId);
    final label = resolveOptionValue(attr, valueId)?.label;
    return label != null && attributeValues[attrKey] == label;
  }

  /// يضيف قيماً لخاصية وصفية دون اختيارها (مكتبة قيم يختار منها البائع).
  int addSpecValues(String attrKey, List<String> labels) {
    final attr = attributeByKey(attrKey);
    final list = customOptionValues.putIfAbsent(attrKey, () => []);
    final known = attr == null ? list : optionValuesFor(attr);
    var n = 0;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < labels.length; i++) {
      final l = labels[i].trim();
      if (l.isEmpty || known.any((v) => v.label.trim().toLowerCase() == l.toLowerCase())) continue;
      if (list.any((v) => v.label.trim().toLowerCase() == l.toLowerCase())) continue;
      list.add(AttributeOptionValue(id: 'custom_${stamp}_$i', label: l));
      n++;
    }
    notifyListeners();
    return n;
  }

  /// ✅ ألوان جاهزة/مفضلة: تُضاف وتُختار دفعة واحدة (بلا تكرار بالـ hex أو الاسم).
  int addColors(String attrKey, List<ReadyColor> colors) {
    final attr = attributeByKey(attrKey);
    if (attr == null) return 0;
    var n = 0;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < colors.length; i++) {
      final c = colors[i];
      final existing = optionValuesFor(attr).where((v) =>
          (v.hex ?? '').toUpperCase() == c.hex.toUpperCase() || v.label.trim() == c.name.trim());
      if (existing.isNotEmpty) {
        // موجود: نختاره فقط إن لم يكن مختاراً.
        if (!isVariantValueSelected(attrKey, existing.first.id)) {
          if (!hasVariants) hasVariants = true;
          selectedVariantValueIds.putIfAbsent(attrKey, () => <String>{}).add(existing.first.id);
          n++;
        }
        continue;
      }
      final id = 'custom_${stamp}_$i';
      customOptionValues.putIfAbsent(attrKey, () => []).add(AttributeOptionValue(id: id, label: c.name, hex: c.hex));
      if (!hasVariants) hasVariants = true;
      selectedVariantValueIds.putIfAbsent(attrKey, () => <String>{}).add(id);
      n++;
    }
    _regenerateDrafts();
    notifyListeners();
    return n;
  }

  /// يضيف خاصية بائع من قالب جاهز/مفضلة مع قيمها. يعيد مفتاح الخاصية أو رسالة خطأ عبر [error].
  ({String? key, String? error}) addAttributeWithValues(String name, String kind, List<String> values,
      {List<ReadyColor> colors = const [], MeasureUnit? unit}) {
    final err = addCustomAttribute(name, kind: kind);
    if (err != null) return (key: null, error: err);
    final key = customAttributeDefs.last.key;
    if (kind == 'color') {
      addColors(key, colors);
    } else if (kind == 'spec') {
      addSpecValues(key, values);
    } else {
      if (values.isNotEmpty) addVariantValues(key, values, unit: unit);
    }
    return (key: key, error: null);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  ✅ مفضلات البائع (القسم 2.4) — حسب الفئة الرئيسية، خاصة وبلا تكرار
  // ═══════════════════════════════════════════════════════════════════
  List<AttributeFavorite> favorites = [];
  bool loadingFavorites = false;
  String? favoritesError;

  String? get currentRootId => selectedCategory == null ? null : rootCategoryId(selectedCategory!);

  Future<void> loadFavorites() async {
    final root = currentRootId;
    if (root == null || sellerId.isEmpty) return;
    loadingFavorites = true;
    favoritesError = null;
    notifyListeners();
    try {
      favorites = await favoritesRepo.fetchForRoot(sellerId, root);
    } catch (e) {
      favoritesError = 'تعذّر تحميل المفضلات';
    }
    loadingFavorites = false;
    notifyListeners();
  }

  /// يحفظ خاصية البائع (تعريف + قيم فقط، بلا أسعار/كميات) في مفضلاته. يعيد true عند النجاح.
  Future<bool> saveAttributeToFavorites(String attrKey) async {
    final root = currentRootId;
    final attr = attributeByKey(attrKey);
    if (root == null || attr == null || sellerId.isEmpty) return false;
    final isColor = attr.type == AttributeType.colorSwatch;
    final kind = isColor ? 'color' : (!attr.isVariant ? 'spec' : (attributeUnits.containsKey(attrKey) ? 'measure' : 'options'));
    final fav = AttributeFavorite(
      id: AttributeFavorite.buildId(root, 'attribute', attr.name),
      rootCategoryId: root,
      type: 'attribute',
      name: attr.name,
      kind: kind,
      unitId: attributeUnits[attrKey]?.id,
      values: [for (final v in optionValuesFor(attr)) FavoriteValue(v.label, hex: v.hex)],
    );
    try {
      await favoritesRepo.save(sellerId, fav);
      favorites = [...favorites.where((f) => f.id != fav.id), fav];
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> saveColorToFavorites(String name, String hex) async {
    final root = currentRootId;
    if (root == null || sellerId.isEmpty) return false;
    final fav = AttributeFavorite(
      id: AttributeFavorite.buildId(root, 'color', name, hex: hex),
      rootCategoryId: root,
      type: 'color',
      name: name,
      kind: 'color',
      values: [FavoriteValue(name, hex: hex)],
    );
    try {
      await favoritesRepo.save(sellerId, fav);
      favorites = [...favorites.where((f) => f.id != fav.id), fav];
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteFavorite(AttributeFavorite fav) async {
    try {
      await favoritesRepo.delete(sellerId, fav.id);
      favorites = favorites.where((f) => f.id != fav.id).toList();
      notifyListeners();
    } catch (_) {}
  }

  /// يضيف مفضلة للمنتج الحالي (لا تُضاف تلقائياً أبداً — فقط بطلب البائع). null = نجاح.
  String? applyFavorite(AttributeFavorite fav) {
    if (fav.isColor) {
      // اللون المفضّل يذهب لخاصية اللون (الرسمية إن وُجدت وإلا نُنشئها).
      var colorKey = variantAttributesAvailable.where((a) => a.type == AttributeType.colorSwatch || a.key == 'color').map((a) => a.key).firstOrNull;
      if (colorKey == null) {
        final r = addAttributeWithValues('اللون', 'color', const []);
        if (r.error != null) return r.error;
        colorKey = r.key;
      }
      if (fav.hex != null) addColors(colorKey!, [ReadyColor(fav.name, fav.hex!)]);
      return null;
    }
    final existing = attributeByKey(fav.name);
    if (existing != null) {
      // خاصية بنفس الاسم موجودة: ندمج القيم الناقصة بدل التكرار.
      if (existing.isVariant) {
        if (fav.kind == 'color') {
          addColors(existing.key, [for (final v in fav.values) if (v.hex != null) ReadyColor(v.label, v.hex!)]);
        } else {
          addVariantValues(existing.key, [for (final v in fav.values) v.label]);
        }
      } else {
        addSpecValues(existing.key, [for (final v in fav.values) v.label]);
      }
      return null;
    }
    final unit = fav.unitId == null ? null : measureUnitById(fav.unitId!);
    final r = addAttributeWithValues(
      fav.name, fav.kind, [for (final v in fav.values) v.label],
      colors: [for (final v in fav.values) if (v.hex != null) ReadyColor(v.label, v.hex!)], unit: unit,
    );
    return r.error;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  الخطوة 4 — تركيبات SKU (مُولَّدة تلقائياً من الخطوة 3)
  // ═══════════════════════════════════════════════════════════════════
  List<VariantDraft> variantDrafts = [];

  /// ✅ SKU Generator مطبَّق هنا فعلياً — كل تغيير في الاختيارات (تفعيل/
  /// تعطيل متغيرات، إضافة/إزالة قيمة) يُعيد توليد التركيبات فوراً، مع
  /// الحفاظ على سعر/مخزون أي تركيبة لا تزال موجودة (لا تُصفَّر بيانات
  /// أُدخلت يدوياً بسبب إضافة قيمة جديدة لخاصية أخرى، مثلاً).
  void _regenerateDrafts({bool preserveExisting = true}) {
    if (!hasVariants || selectedVariantValueIds.isEmpty) {
      variantDrafts = [];
      return;
    }
    final optionsByKey = <String, List<String>>{
      for (final entry in selectedVariantValueIds.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value.toList(),
    };
    final combos = VariantRepository.generateCombinations(optionsByKey);
    final basePrice = double.tryParse(priceCtrl.text) ?? 0;

    final newDrafts = <VariantDraft>[];
    for (final combo in combos) {
      VariantDraft? existing;
      if (preserveExisting) {
        final matches = variantDrafts.where((d) => d._sameOptions(combo));
        if (matches.isNotEmpty) existing = matches.first;
      }
      // ✅ التركيبة الجديدة (قيمة أضافها البائع لاحقاً) تأخذ القيم الموحَّدة إن كانت
      // مفعّلة، وإلا تبدأ بالسعر الأساسي (إن وُجد) وكمية فارغة. التركيبات الموجودة
      // تبقى بياناتها كما هي (لا تُفسَد ولا تُستبدل).
      newDrafts.add(existing ??
          VariantDraft(
            optionValues: combo,
            price: unifyPrice ? _unifiedPrice : basePrice,
            originalPrice: unifyPrice ? _unifiedOriginal : 0,
            stock: unifyStock ? _unifiedStock : 0,
          ));
    }
    variantDrafts = newDrafts;
  }

  double _lastBasePrice = 0;

  /// عند تغيير "السعر الأساسي": الخيارات التي لم يعدّل البائع سعرها يدوياً
  /// (صفر أو تساوي السعر الأساسي السابق) تتبع السعر الجديد تلقائياً.
  /// السعر المعروض في المراجعة: لمنتج بخيارات = أقل سعر نشط ("من X")، وإلا السعر المكتوب.
  String get displayPriceText {
    if (hasVariants && variantDrafts.isNotEmpty) {
      final prices = variantDrafts.where((d) => d.isActive && d.price > 0).map((d) => d.price).toList();
      if (prices.isNotEmpty) {
        final m = prices.reduce((a, b) => a < b ? a : b);
        final t = m == m.roundToDouble() ? m.round().toString() : m.toString();
        return prices.toSet().length > 1 ? 'من $t' : t;
      }
    }
    return priceCtrl.text;
  }

  void onBasePriceChanged() {
    final base = double.tryParse(priceCtrl.text.trim()) ?? 0;
    for (final d in variantDrafts) {
      if (d.price == 0 || d.price == _lastBasePrice) d.price = base;
    }
    _lastBasePrice = base;
    notifyListeners();
  }

  void updateDraftPrice(int index, double price) {
    if (index < 0 || index >= variantDrafts.length) return;
    variantDrafts[index].price = price;
    notifyListeners();
  }

  void updateDraftStock(int index, int stock) {
    if (index < 0 || index >= variantDrafts.length) return;
    variantDrafts[index].stock = stock;
    notifyListeners();
  }

  void toggleDraftActive(int index) {
    if (index < 0 || index >= variantDrafts.length) return;
    variantDrafts[index].isActive = !variantDrafts[index].isActive;
    notifyListeners();
  }

  /// ✅ يملأ كل تركيبات بسعر واحد دفعة واحدة — توفيراً لوقت البائع عند
  /// عشرات التركيبات المتطابقة السعر (يبقى بإمكانه تعديل أي تركيبة بعدها يدوياً).
  void applyPriceToAllDrafts(double price) {
    for (final d in variantDrafts) {
      d.price = price;
    }
    notifyListeners();
  }

  void updateDraftOriginalPrice(int index, double value) {
    if (index < 0 || index >= variantDrafts.length) return;
    variantDrafts[index].originalPrice = value;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  ✅ توحيد السعر والكمية لكل التركيبات (القسم 4)
  //  • "هل جميع [الألوان والمقاسات] لها نفس السعر؟" → السعر الأساسي (إلزامي) +
  //    السعر قبل الخصم (اختياري) يُنسخان لكل تركيبة.
  //  • "... نفس الكمية؟" → الكمية تُنسخ لكل تركيبة بصورة مستقلة (ليست مخزوناً مشتركاً).
  //  • إلغاء التفعيل لا يمسح ما في التركيبات؛ التعديل اليدوي ممكن دائماً،
  //    ولا يُكتب فوق بيانات البائع إلا حين يفعّل التوحيد أو يغيّر القيمة الموحَّدة.
  // ═══════════════════════════════════════════════════════════════════
  bool unifyPrice = false;
  bool unifyStock = false;
  late final TextEditingController unifiedPriceCtrl;
  late final TextEditingController unifiedOriginalCtrl;
  late final TextEditingController unifiedStockCtrl;

  double get _unifiedPrice => double.tryParse(unifiedPriceCtrl.text.trim()) ?? 0;
  double get _unifiedOriginal => double.tryParse(unifiedOriginalCtrl.text.trim()) ?? 0;
  int get _unifiedStock => int.tryParse(unifiedStockCtrl.text.trim()) ?? 0;

  /// أسماء الخصائص الاختيارية المضافة فعلاً (التي لها قيم مختارة) — ديناميكية.
  List<String> get selectedVariantAttrNames => [
        for (final a in variantAttributesAvailable)
          if ((selectedVariantValueIds[a.key] ?? const <String>{}).isNotEmpty) a.name,
      ];

  /// "الألوان" / "الألوان والمقاسات" ... لاستخدامها في نص سؤال التوحيد.
  String get unifyAttrsPhrase => joinAttrNames(selectedVariantAttrNames);

  void setUnifyPrice(bool v) {
    unifyPrice = v;
    if (v) _applyUnifiedPrice();
    notifyListeners();
  }

  void setUnifyStock(bool v) {
    unifyStock = v;
    if (v) _applyUnifiedStock();
    notifyListeners();
  }

  void _applyUnifiedPrice() {
    final price = _unifiedPrice;
    final original = _unifiedOriginal;
    // لا نمسح أسعار البائع بقيمة فارغة: التطبيق فقط عند وجود سعر أساسي صالح.
    if (price <= 0) return;
    for (final d in variantDrafts) {
      d.price = price;
      d.originalPrice = original > price ? original : 0;
    }
  }

  void _applyUnifiedStock() {
    if (unifiedStockCtrl.text.trim().isEmpty) return;
    final stock = _unifiedStock;
    for (final d in variantDrafts) {
      d.stock = stock;
    }
  }

  void onUnifiedPriceChanged() {
    if (unifyPrice) _applyUnifiedPrice();
    notifyListeners();
  }

  void onUnifiedStockChanged() {
    if (unifyStock) _applyUnifiedStock();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  الخطوة 5 — المعرض والمراجعة
  // ═══════════════════════════════════════════════════════════════════
  // ✅ حالة رفع الفيديو (الرفع الفعلي في الشاشة عبر ImageKitService.uploadVideo)
  bool uploadingVideo = false;
  double videoUploadProgress = 0;
  void setVideoUploadState({required bool uploading, double progress = 0}) {
    uploadingVideo = uploading;
    videoUploadProgress = progress;
    notifyListeners();
  }
  void setVideoUrl(String url) {
    videoUrlCtrl.text = url;
    notifyListeners();
  }
  void clearVideo() => setVideoUrl('');

  late TextEditingController videoUrlCtrl; // ⚠️ لا يوجد رفع فيديو فعلي بعد
  // (ImageKitService يدعم رفع صور فقط) — حقل نصي لرابط جاهز مؤقتاً، راجع
  // ملاحظة النطاق في HANDOFF.
  String? heroUrl;
  List<String> itemImageUrls = [];
  final Map<String, String> colorImageUrls = {}; // valueId -> url
  final Map<String, String> sizeImageUrls = {}; // valueId -> url
  final Map<String, String> otherImageUrls = {}; // valueId -> url (أي خاصية غير اللون والمقاس)

  /// ✅ صورة اختيارية لأي قيمة خيار (لون/مقاس/سعة/...): تُوجَّه للخريطة المناسبة.
  String? valueImageFor(String attrKey, String valueId) =>
      attrKey == 'color' ? colorImageUrls[valueId] : (attrKey == 'size' ? sizeImageUrls[valueId] : otherImageUrls[valueId]);

  void setValueImage(String attrKey, String valueId, String url) {
    if (attrKey == 'color') {
      colorImageUrls[valueId] = url;
    } else if (attrKey == 'size') {
      sizeImageUrls[valueId] = url;
    } else {
      otherImageUrls[valueId] = url;
    }
    if (!images.contains(url)) images.add(url);
    notifyListeners();
  }

  void clearValueImage(String attrKey, String valueId) {
    colorImageUrls.remove(valueId);
    sizeImageUrls.remove(valueId);
    otherImageUrls.remove(valueId);
    notifyListeners();
  }

  void setHeroUrl(String url) {
    final oldHero = heroUrl;
    heroUrl = url;
    // ✅ غلاف المنتج في القوائم/البطاقات = images[0] (ProductModel.firstImage)،
    // فيجب أن تكون الصورة الرئيسية الجديدة أولاً دائماً، وإلا بقي الغلاف القديم.
    images.remove(url);
    images.insert(0, url);
    // الصورة الرئيسية القديمة استُبدلت: نحذفها من القائمة القديمة إن لم تكن
    // مستخدمة كصورة عنصر أو لون أو مقاس حتى لا تتراكم صور يتيمة.
    if (oldHero != null && oldHero != url &&
        !itemImageUrls.contains(oldHero) &&
        !colorImageUrls.containsValue(oldHero) &&
        !sizeImageUrls.containsValue(oldHero) &&
        !otherImageUrls.containsValue(oldHero)) {
      images.remove(oldHero);
    }
    notifyListeners();
  }

  void addItemImage(String url) {
    itemImageUrls.add(url);
    if (!images.contains(url)) images.add(url);
    notifyListeners();
  }

  void removeItemImage(String url) {
    itemImageUrls.remove(url);
    notifyListeners();
  }

  void setColorImage(String valueId, String url) {
    colorImageUrls[valueId] = url;
    notifyListeners();
  }

  void setSizeImage(String valueId, String url) {
    sizeImageUrls[valueId] = url;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  رؤية الخطوات — الخوارزمية المُتحقَّق منها بـ Python (6 حالات)
  // ═══════════════════════════════════════════════════════════════════
  static const int stepCategory = 0;
  static const int stepBasicInfo = 1;
  static const int stepSpecifications = 2;
  static const int stepVariantSelection = 3;
  static const int stepVariantCombinations = 4;
  static const int stepGalleryReview = 5;

  static List<int> computeVisibleSteps({
    required bool hasDescriptive,
    required bool hasVariantAttrsAvailable,
    required bool hasVariantsEnabled,
  }) {
    final steps = <int>[stepCategory, stepBasicInfo];
    if (hasDescriptive) steps.add(stepSpecifications);
    if (hasVariantAttrsAvailable) steps.add(stepVariantSelection);
    if (hasVariantsEnabled) steps.add(stepVariantCombinations);
    steps.add(stepGalleryReview);
    return steps;
  }

  List<int> get visibleSteps => computeVisibleSteps(
        hasDescriptive: descriptiveAttributes.isNotEmpty,
        hasVariantAttrsAvailable: variantAttributesAvailable.isNotEmpty,
        hasVariantsEnabled: hasVariants && variantDrafts.isNotEmpty,
      );

  int currentStep = 0; // فهرس ضمن visibleSteps (وليس رقم الخطوة الثابت)

  void goToStep(int visibleIndex) {
    if (visibleIndex < 0 || visibleIndex >= visibleSteps.length) return;
    currentStep = visibleIndex;
    notifyListeners();
  }

  void nextStep() {
    if (currentStep < visibleSteps.length - 1) {
      currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      currentStep--;
      notifyListeners();
    }
  }

  /// ✅ تحقّق لكل خطوة قبل السماح بالانتقال للتالية — رسالة خطأ عربية
  /// واضحة أو null إن كانت الخطوة سليمة.
  String? validateStep(int stepId) {
    switch (stepId) {
      case stepCategory:
        if (selectedCategory == null) return 'اختر فئة المنتج أولاً';
        if (!selectedCategory!.isLeaf && customSubcategoryLabel == null) return 'اختر فئة فرعية، أو أضف فئة فرعية أخرى';
        return null;
      case stepBasicInfo:
        if (nameCtrl.text.trim().isEmpty) return 'اسم المنتج مطلوب';
        if (shortDescCtrl.text.trim().isEmpty) return 'الوصف المختصر مطلوب';
        if (descCtrl.text.trim().isEmpty) return 'الوصف التفصيلي مطلوب';
        return null;
      case stepVariantSelection:
        if (hasVariants && selectedVariantValueIds.isEmpty) {
          return 'اختر قيمة واحدة على الأقل لكل خاصية متغيّرة، أو أوقف تفعيل المتغيرات';
        }
        // ✅ السعر والكمية صارا في خطوة الخصائص (نُقلا من المعلومات الأساسية).
        if (hasVariants && variantDrafts.isNotEmpty) {
          if (unifyPrice && _unifiedPrice <= 0) return 'أدخل السعر الأساسي الموحَّد أو ألغِ التوحيد';
          if (unifyStock && unifiedStockCtrl.text.trim().isEmpty) return 'أدخل الكمية الموحَّدة أو ألغِ التوحيد';
          if (variantDrafts.any((d) => d.price <= 0)) return 'حدّد سعراً أكبر من صفر لكل خيار';
          if (variantDrafts.any((d) => d.originalPrice > 0 && d.originalPrice <= d.price)) {
            return 'السعر قبل الخصم يجب أن يكون أكبر من السعر الأساسي (أو اتركه فارغاً)';
          }
        } else {
          final price = double.tryParse(priceCtrl.text.trim());
          if (price == null || price <= 0) return 'السعر غير صحيح';
          final stock = int.tryParse(stockCtrl.text.trim());
          if (stock == null || stock < 0) return 'الكمية غير صحيحة';
        }
        return null;
      case stepVariantCombinations:
        if (hasVariants && variantDrafts.isEmpty) return 'لا توجد تركيبات — راجع الخطوة السابقة';
        if (hasVariants && variantDrafts.every((d) => d.stock <= 0)) {
          return 'يجب أن تملك تركيبة واحدة على الأقل مخزوناً أكبر من صفر';
        }
        return null;
      case stepGalleryReview:
        if (heroUrl == null || heroUrl!.trim().isEmpty) return 'الصورة الرئيسية مطلوبة';
        return null;
      default:
        return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  الحفظ النهائي
  // ═══════════════════════════════════════════════════════════════════
  bool saving = false;
  String? saveError;

  List<String> _imagesHeroFirst() {
    final hero = heroUrl?.trim() ?? '';
    if (hero.isEmpty) return List.of(images);
    return [hero, ...images.where((u) => u != hero)];
  }

  List<GalleryItemModel> _buildGallery() {
    final gallery = <GalleryItemModel>[];
    final videoUrl = videoUrlCtrl.text.trim();
    if (videoUrl.isNotEmpty) {
      gallery.add(GalleryItemModel(url: videoUrl, role: GalleryItemRole.video));
    }
    if (heroUrl != null && heroUrl!.trim().isNotEmpty) {
      gallery.add(GalleryItemModel(url: heroUrl!, role: GalleryItemRole.hero));
    }
    for (final url in itemImageUrls) {
      gallery.add(GalleryItemModel(url: url, role: GalleryItemRole.item));
    }
    if (hasVariants) {
      for (final attr in variantAttributesAvailable) {
        final ids = selectedVariantValueIds[attr.key];
        if (ids == null || ids.isEmpty) continue;
        for (final valueId in ids) {
          final url = valueImageFor(attr.key, valueId);
          if (url == null || url.trim().isEmpty) continue;
          final role = attr.key == 'color'
              ? GalleryItemRole.color
              : (attr.key == 'size' ? GalleryItemRole.size : GalleryItemRole.other);
          gallery.add(GalleryItemModel(
            url: url, role: role, optionKey: attr.key, optionValueId: valueId,
          ));
        }
      }
    }
    return gallery;
  }

  Map<String, List<ProductOptionValueRef>> _buildOptionSets(List<GalleryItemModel> gallery) {
    final optionSets = <String, List<ProductOptionValueRef>>{};
    if (!hasVariants) return optionSets;
    final heroIndex = gallery.indexWhere((g) => g.role == GalleryItemRole.hero);

    for (final attr in variantAttributesAvailable) {
      final ids = selectedVariantValueIds[attr.key];
      if (ids == null || ids.isEmpty) continue;
      final refs = <ProductOptionValueRef>[];
      for (final valueId in ids) {
        // ✅ يبحث في القيم الرسمية والمخصَّصة (المضافة عبر "+ لون/مقاس آخر") معاً.
        final val = resolveOptionValue(attr, valueId);
        if (val == null) continue;
        // ✅ فهرس أول صورة مخصّصة لهذه القيمة، وإلا Hero كـ Fallback بدل
        // ترك المستخدم أمام صفحة بلا صورة عند اختيار هذا اللون/المقاس.
        var idx = gallery.indexWhere((g) => g.optionKey == attr.key && g.optionValueId == valueId);
        if (idx < 0) idx = heroIndex >= 0 ? heroIndex : 0;
        // التوفر الفعلي: توجد تركيبة نشطة بمخزون > 0 تحمل هذه القيمة.
        final isAvailable = variantDrafts.any(
          (d) => d.optionValues[attr.key] == valueId && d.isActive && d.stock > 0,
        );
        refs.add(ProductOptionValueRef(
          valueId: valueId, label: val.label, hex: val.hex,
          firstGalleryIndex: idx, isAvailable: isAvailable,
        ));
      }
      if (refs.isNotEmpty) optionSets[attr.key] = refs;
    }
    return optionSets;
  }

  /// ✅ الحفظ النهائي: يكتب مستند المنتج أولاً (Create أو Update عبر
  /// ProductRepository)، ثم — فقط عند hasVariants — يكتب subcollection
  /// variants دفعة واحدة (Batch) بعد بناء SKU حقيقي بمعرّف المنتج الفعلي
  /// (لا يمكن بناء SKU نهائي قبل معرفة id المنتج المكتوب فعلياً).
  Future<bool> save() async {
    if (saving) return false;
    // ✅ تحقّق شامل قبل أي كتابة فعلية — لا نكتب جزئياً أبداً.
    for (final stepId in [
      stepCategory, stepBasicInfo, stepVariantSelection, stepVariantCombinations, stepGalleryReview,
    ]) {
      final err = validateStep(stepId);
      if (err != null) {
        saveError = err;
        notifyListeners();
        return false;
      }
    }

    saving = true;
    saveError = null;
    notifyListeners();

    try {
      final category = selectedCategory!;
      final rootId = rootCategoryId(category);
      final gallery = _buildGallery();
      final optionSets = _buildOptionSets(gallery);
      final effectiveHasVariants = hasVariants && variantDrafts.isNotEmpty;
      // السعر المعروض في القوائم: أقل سعر بين الخيارات النشطة (أو السعر الأساسي).
      final activePrices = variantDrafts.where((d) => d.isActive && d.price > 0).map((d) => d.price);
      final price = (effectiveHasVariants && activePrices.isNotEmpty)
          ? activePrices.reduce((a, b) => a < b ? a : b)
          : double.parse(priceCtrl.text.trim());
      double? rawOriginal = double.tryParse(originalPriceCtrl.text.trim());
      if (effectiveHasVariants) {
        // سعر قبل الخصم المعروض في القوائم: للتركيبة الأرخص (إن كان لها خصم).
        final cheapest = variantDrafts.where((d) => d.isActive && d.price == price).toList();
        rawOriginal = cheapest.isNotEmpty && cheapest.first.originalPrice > price ? cheapest.first.originalPrice : null;
      }

      final product = ProductModel(
        id: existingProduct?.id ?? '',
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
        shortDescription: shortDescCtrl.text.trim(),
        condition: condition,
        customSubcategory: customSubcategoryLabel ?? '',
        price: price,
        category: rootId, // ✅ توافق خلفي — الفئة الجذرية المسطّحة القديمة
        // ✅ الصورة الرئيسية (Hero) أولاً دائماً لأنها غلاف المنتج في كل القوائم
        images: _imagesHeroFirst(),
        // ✅ منتج بمتغيرات: المخزون الحقيقي في subcollection variants فقط؛
        // نُبقي 0 هنا عمداً حتى لا يُقرأ حقل مضلِّل من أي استعلام قديم.
        stock: effectiveHasVariants ? 0 : (int.tryParse(stockCtrl.text.trim()) ?? 0),
        sellerId: sellerId,
        sellerName: sellerName,
        sellerLogo: sellerLogo,
        storeDescription: storeDescription,
        rating: existingProduct?.rating ?? 0.0,
        reviewCount: existingProduct?.reviewCount ?? 0,
        displayWeight: existingProduct?.displayWeight ?? 5,
        currencyCode: selectedCurrency.code,
        currencySymbol: selectedCurrency.symbol,
        createdAt: existingProduct?.createdAt ?? DateTime.now(),
        originalPrice: (rawOriginal != null && rawOriginal > price) ? rawOriginal : null,
        categoryId: category.category.id,
        attributes: {
          for (final e in attributeValues.entries)
            if (!hiddenFromBuyerKeys.contains(e.key) && !disabledAttrKeys.contains(e.key) && e.value.trim().isNotEmpty) e.key: e.value,
        },
        hiddenAttributes: {
          for (final e in attributeValues.entries)
            if (hiddenFromBuyerKeys.contains(e.key) && !disabledAttrKeys.contains(e.key) && e.value.trim().isNotEmpty) e.key: e.value,
        },
        gallery: gallery,
        optionSets: optionSets,
        hasVariants: effectiveHasVariants,
        variantKeys: effectiveHasVariants ? optionSets.keys.toList() : const [],
      );

      String productId;
      final isNewProduct = existingProduct == null;
      if (!isNewProduct) {
        productId = existingProduct!.id;
        await productRepo.update(productId, product.toMap());
      } else {
        productId = await productRepo.create(product);
      }

      // ✅ إعادة تفعيل المزايا القديمة (كانت في add_product_screen.dart
      // وتوقّفت مع الشاشة الجديدة) — بنفس السلوك تماماً: عمليات خلفية
      // صامتة (unawaited)، لا تؤثر على نجاح/فشل تجربة النشر نفسها.
      if (isNewProduct) {
        // توليد 10 تقييمات تمهيدية ذكية — فقط للمنتجات الجديدة.
        unawaited(AiAssistantService.generateSeedReviews(productId: productId));
        // إشعار Push تلقائي لكل المستخدمين المسجَّلين بالمنتج الجديد.
        unawaited(PushNotificationService.sendProductNotification(productId: productId));
      }
      // إعادة بناء صفحات SEO الثابتة في الخلفية — عند الإضافة والتعديل معاً.
      unawaited(SeoRebuildService.triggerRebuild(
        reason: isNewProduct ? 'product_created:$productId' : 'product_updated:$productId',
      ));

      if (effectiveHasVariants) {
        final variants = variantDrafts.map((d) {
          final sku = VariantRepository.buildSku(productId, product.variantKeys, d.optionValues);
          return ProductVariantModel(
            id: sku, sku: sku, optionValues: d.optionValues,
            price: d.price, originalPrice: d.originalPrice > d.price ? d.originalPrice : 0,
            stock: d.stock, isActive: d.isActive,
          );
        }).toList();
        await variantRepo.upsertBatch(productId, variants);
      }

      saving = false;
      notifyListeners();
      return true;
    } catch (e) {
      saveError = 'حدث خطأ أثناء الحفظ: $e';
      saving = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  ✅ المسودة المحلية (راجع product_draft_store.dart)
  // ═══════════════════════════════════════════════════════════════════
  bool get hasDraftContent =>
      nameCtrl.text.trim().isNotEmpty ||
      shortDescCtrl.text.trim().isNotEmpty ||
      descCtrl.text.trim().isNotEmpty ||
      priceCtrl.text.trim().isNotEmpty ||
      heroUrl != null ||
      itemImageUrls.isNotEmpty ||
      images.isNotEmpty ||
      videoUrlCtrl.text.trim().isNotEmpty ||
      selectedCategory != null;

  Map<String, dynamic> toDraftMap() => {
        'name': nameCtrl.text.trim(),
        'shortDescription': shortDescCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'price': priceCtrl.text.trim(),
        'originalPrice': originalPriceCtrl.text.trim(),
        'stock': stockCtrl.text.trim(),
        'condition': condition,
        'currency': selectedCurrency.code,
        'categoryId': selectedCategory?.category.id,
        'customSubcategory': customSubcategoryLabel,
        'attributes': Map<String, String>.from(attributeValues),
        'heroUrl': heroUrl,
        'itemImageUrls': List<String>.from(itemImageUrls),
        'images': List<String>.from(images),
        'videoUrl': videoUrlCtrl.text.trim(),
        'savedAt': DateTime.now().toIso8601String(),
      };

  /// يستعيد مسودة محفوظة. يجب استدعاؤها بعد انتهاء تحميل الفئات.
  Future<void> applyDraft(Map<String, dynamic> m) async {
    String str(String k) => (m[k] ?? '').toString();
    List<String> list(String k) =>
        ((m[k] as List?) ?? const []).map((e) => e.toString()).toList();

    nameCtrl.text = str('name');
    shortDescCtrl.text = str('shortDescription');
    descCtrl.text = str('description');
    priceCtrl.text = str('price');
    originalPriceCtrl.text = str('originalPrice');
    stockCtrl.text = str('stock');
    videoUrlCtrl.text = str('videoUrl');
    final cond = str('condition');
    if (cond.isNotEmpty) condition = cond;
    final cur = kSougaCurrencies.where((c) => c.code == str('currency'));
    if (cur.isNotEmpty) selectedCurrency = cur.first;

    images = list('images');
    final hero = m['heroUrl'];
    heroUrl = (hero is String && hero.isNotEmpty) ? hero : null;
    itemImageUrls = list('itemImageUrls');

    final catId = m['categoryId'];
    if (catId is String && catId.isNotEmpty) {
      final found = CategoryRepository.findById(categoryTree, catId);
      if (found != null) {
        await selectCategory(found); // يصفّر القيم المعتمدة على الفئة ثم نعيدها
        final attrs = m['attributes'];
        if (attrs is Map) {
          attributeValues
            ..clear()
            ..addAll(attrs.map((k, v) => MapEntry(k.toString(), v.toString())));
        }
        final sub = m['customSubcategory'];
        if (sub is String && sub.trim().isNotEmpty) customSubcategoryLabel = sub.trim();
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    shortDescCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    originalPriceCtrl.dispose();
    stockCtrl.dispose();
    unifiedPriceCtrl.dispose();
    unifiedOriginalCtrl.dispose();
    unifiedStockCtrl.dispose();
    videoUrlCtrl.dispose();
    super.dispose();
  }
}
