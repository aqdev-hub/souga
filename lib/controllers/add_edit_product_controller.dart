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
import '../repositories/attribute_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/variant_repository.dart';
import '../services/ai_assistant_service.dart';
import '../services/push_notification_service.dart';
import '../services/seo_rebuild_service.dart';
import '../utils/currencies.dart';

/// تركيبة SKU واحدة قيد التحرير — قبل الحفظ (لا تحمل id حقيقياً بعد، يُبنى
/// SKU الفعلي فقط عند save() لأنه يحتاج productId الحقيقي من Firestore).
class VariantDraft {
  final Map<String, String> optionValues; // مثال: {'color': 'red', 'size': 'xl'}
  double price;
  int stock;
  bool isActive;

  VariantDraft({
    required this.optionValues,
    required this.price,
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
  })  : categoryRepo = categoryRepo ?? CategoryRepository(),
        attributeRepo = attributeRepo ?? AttributeRepository(),
        productRepo = productRepo ?? ProductRepository(),
        variantRepo = variantRepo ?? VariantRepository() {
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

  List<AttributeDefinitionModel> get descriptiveAttributes =>
      _categoryAttributes.where((a) => !a.isVariant).toList();

  List<AttributeDefinitionModel> get variantAttributesAvailable =>
      _categoryAttributes.where((a) => a.isVariant).toList();

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
      attributeValues.clear();
      hasVariants = false;
      selectedVariantValueIds.clear();
      variantDrafts.clear();
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
    hasVariants = p.hasVariants;
    selectedVariantValueIds.clear();
    customOptionValues.clear();
    for (final entry in p.optionSets.entries) {
      selectedVariantValueIds[entry.key] = entry.value.map((v) => v.valueId).toSet();
      // ✅ إعادة بناء أي قيمة "مخصَّصة" (أُضيفت سابقاً عبر "+ لون/مقاس آخر"
      // ولا تنتمي لقائمة predefinedValues الرسمية للخاصية) من Snapshot
      // المنتج نفسه (label/hex محفوظان بالفعل في ProductOptionValueRef) —
      // بدون هذا، فتح المنتج للتعديل كان سيُظهر قيمة غير معروفة بلا تسمية.
      final attrMatch = variantAttributesAvailable.where((a) => a.key == entry.key);
      if (attrMatch.isEmpty) continue;
      final officialIds = attrMatch.first.predefinedValues.map((v) => v.id).toSet();
      for (final ref in entry.value) {
        if (!officialIds.contains(ref.valueId)) {
          customOptionValues.putIfAbsent(entry.key, () => []).add(
            AttributeOptionValue(id: ref.valueId, label: ref.label, hex: ref.hex),
          );
        }
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

  void setCustomSubcategory(String label) {
    final trimmed = label.trim();
    customSubcategoryLabel = trimmed.isEmpty ? null : trimmed;
    notifyListeners();
  }

  void clearCustomSubcategory() {
    customSubcategoryLabel = null;
    notifyListeners();
  }

  /// اسم الفئة المعروض في شريط الفئة/التصفح: الفئة المختارة فعلياً، مع
  /// إلحاق اقتراح البائع (إن وُجد) كملاحظة إضافية — لا يستبدلها أبداً.
  String subcategoryDisplayName(CategoryNode? node) {
    final base = node?.category.name ?? '';
    if (customSubcategoryLabel == null || customSubcategoryLabel!.isEmpty) return base;
    return base.isEmpty ? customSubcategoryLabel! : '$base ($customSubcategoryLabel — مقترَحة)';
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

  Future<void> enhanceDescription({required String category, required String priceText}) async {
    if (isEnhancingDescription) return;
    final rawText = descCtrl.text.trim();
    if (rawText.length < 10) return;

    isEnhancingDescription = true;
    notifyListeners();

    final result = await AiAssistantService.enhanceDescription(
      productName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'منتج',
      category: category,
      rawDescription: rawText,
      price: priceText,
      currencySymbol: selectedCurrency.symbol,
    );

    isEnhancingDescription = false;
    if (result.isSuccess) {
      descriptionEnhanceError = null;
      descCtrl.text = result.enhanced!;
      descCtrl.selection = TextSelection.fromPosition(TextPosition(offset: descCtrl.text.length));
    } else {
      descriptionEnhanceError = result.errorMessage ?? 'تعذّر تحسين الوصف';
    }
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

  /// ✅ جديد — "+ إضافة خاصية أخرى" (مطابقة التصميم المعتمد): يسمح للبائع
  /// بإضافة خاصية حرّة غير معرَّفة مسبقاً في الفئة (مثال: "وزن العبوة").
  /// تُخزَّن بنفس آلية attributeValues (المفتاح هو التسمية العربية نفسها،
  /// بلا حاجة لـ AttributeDefinitionModel رسمي)، فتُعرَض تلقائياً في قسم
  /// المواصفات بصفحة تفاصيل المنتج (attributeDisplayLabel يُعيد المفتاح
  /// كما هو لأي مفتاح غير معروف له اسم عربي مُعرَّف).
  final List<String> customAttributeKeys = [];

  void addCustomAttribute(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty || customAttributeKeys.contains(trimmed)) return;
    customAttributeKeys.add(trimmed);
    notifyListeners();
  }

  void removeCustomAttribute(String label) {
    customAttributeKeys.remove(label);
    attributeValues.remove(label);
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
  List<AttributeOptionValue> optionValuesFor(AttributeDefinitionModel attr) => [
        ...attr.predefinedValues,
        ...(customOptionValues[attr.key] ?? const []),
      ];

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
      newDrafts.add(existing ?? VariantDraft(optionValues: combo, price: basePrice, stock: 0));
    }
    variantDrafts = newDrafts;
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

  // ═══════════════════════════════════════════════════════════════════
  //  الخطوة 5 — المعرض والمراجعة
  // ═══════════════════════════════════════════════════════════════════
  late TextEditingController videoUrlCtrl; // ⚠️ لا يوجد رفع فيديو فعلي بعد
  // (ImageKitService يدعم رفع صور فقط) — حقل نصي لرابط جاهز مؤقتاً، راجع
  // ملاحظة النطاق في HANDOFF.
  String? heroUrl;
  List<String> itemImageUrls = [];
  final Map<String, String> colorImageUrls = {}; // valueId -> url
  final Map<String, String> sizeImageUrls = {}; // valueId -> url

  void setHeroUrl(String url) {
    heroUrl = url;
    if (!images.contains(url)) images.add(url);
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
        if (!selectedCategory!.isLeaf) return 'اختر فئة فرعية نهائية (بلا أبناء)';
        return null;
      case stepBasicInfo:
        if (nameCtrl.text.trim().isEmpty) return 'اسم المنتج مطلوب';
        if (shortDescCtrl.text.trim().isEmpty) return 'الوصف المختصر مطلوب';
        if (descCtrl.text.trim().isEmpty) return 'الوصف التفصيلي مطلوب';
        final price = double.tryParse(priceCtrl.text.trim());
        if (price == null || price <= 0) return 'السعر غير صحيح';
        if (!hasVariants) {
          final stock = int.tryParse(stockCtrl.text.trim());
          if (stock == null || stock < 0) return 'الكمية غير صحيحة';
        }
        return null;
      case stepVariantSelection:
        if (hasVariants && selectedVariantValueIds.isEmpty) {
          return 'اختر قيمة واحدة على الأقل لكل خاصية متغيّرة، أو أوقف تفعيل المتغيرات';
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
          final url = attr.key == 'color'
              ? colorImageUrls[valueId]
              : (attr.key == 'size' ? sizeImageUrls[valueId] : null);
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
      final price = double.parse(priceCtrl.text.trim());
      final rawOriginal = double.tryParse(originalPriceCtrl.text.trim());

      final product = ProductModel(
        id: existingProduct?.id ?? '',
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
        shortDescription: shortDescCtrl.text.trim(),
        condition: condition,
        customSubcategory: customSubcategoryLabel ?? '',
        price: price,
        category: rootId, // ✅ توافق خلفي — الفئة الجذرية المسطّحة القديمة
        images: images,
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
        attributes: Map.of(attributeValues),
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
            price: d.price, stock: d.stock, isActive: d.isActive,
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

  @override
  void dispose() {
    nameCtrl.dispose();
    shortDescCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    originalPriceCtrl.dispose();
    stockCtrl.dispose();
    videoUrlCtrl.dispose();
    super.dispose();
  }
}
