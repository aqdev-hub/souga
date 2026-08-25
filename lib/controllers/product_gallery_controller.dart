// lib/controllers/product_gallery_controller.dart
//
// ✅ المرحلة 3 من Universal Product Engine — Gallery Engine.
//
// كل المنطق هنا فقط (State Management عبر ChangeNotifier) — الـ UI
// (product_gallery_view.dart لاحقاً) لن يحتوي أي قرار، فقط Rendering بحت،
// تماماً كما اشترطت في "State Management".
//
// خوارزمية resolveActiveState تحقّقت من صحتها بمحاكاة Python بـ 10 حالات
// اختبار (منطقة Item، حدود دقيقة بين قيمتين، صفحة بعد آخر حدّ، منتج بلا
// أي متغيرات) قبل ترجمتها هنا — راجع سجل الجلسة.

import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/gallery_item_model.dart';
import '../models/product_option_ref_model.dart';

class ProductGalleryController extends ChangeNotifier {
  final ProductModel product;
  late final PageController pageController;

  ProductGalleryController({required this.product}) {
    pageController = PageController();
    pageController.addListener(_onPageControllerChanged);
    // ✅ تهيئة الحالة الأولية بمنطق resolveActiveState نفسه، حتى لا يبدأ
    // شريط المصغرات بحالة غير متزامنة قبل أول إطار.
    _applyState(0);
  }

  List<GalleryItemModel> get gallery => product.effectiveGallery;

  // ── الحالات المستقلة الثلاث (مطابقة تماماً لما اشترطت) ──────────────
  int _currentPage = 0;
  int get currentPage => _currentPage;

  /// null إن كنا داخل منطقة لون/مقاس — غير null فقط داخل منطقة Hero/Item.
  int? _activeItemIndex = 0;
  int? get activeItemIndex => _activeItemIndex;

  String? _activeColorId;
  String? get activeColorId => _activeColorId;

  String? _activeSizeId;
  String? get activeSizeId => _activeSizeId;

  /// ✅ عام: يدعم أي خاصية أخرى مستقبلية (Storage, Material...) بلا تعديل
  /// كود — المفتاح هو optionKey (مثال 'storage')، والقيمة معرّف الخيار النشط.
  String? _activeOtherKey;
  String? _activeOtherValueId;
  String? get activeOtherKey => _activeOtherKey;
  String? get activeOtherValueId => _activeOtherValueId;

  bool get hasVideo => gallery.isNotEmpty && gallery.first.role == GalleryItemRole.video;

  // ═══════════════════════════════════════════════════════════════════
  //  Bidirectional Sync — الاتجاه الأول: السحب في المعرض يُحدِّث الحالة
  // ═══════════════════════════════════════════════════════════════════
  void _onPageControllerChanged() {
    final page = pageController.page?.round();
    if (page == null || page == _currentPage) return;
    _applyState(page);
  }

  void _applyState(int page) {
    _currentPage = page;
    final resolved = _resolveActiveState(page, product.optionSets);
    _activeItemIndex = resolved.isItemZone ? page : null;
    _activeColorId = resolved.key == 'color' ? resolved.valueId : null;
    _activeSizeId = resolved.key == 'size' ? resolved.valueId : null;
    if (resolved.key != null && resolved.key != 'color' && resolved.key != 'size') {
      _activeOtherKey = resolved.key;
      _activeOtherValueId = resolved.valueId;
    } else {
      _activeOtherKey = null;
      _activeOtherValueId = null;
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Bidirectional Sync — الاتجاه الثاني: الضغط على Thumbnail يقفز بالمعرض
  // ═══════════════════════════════════════════════════════════════════
  void jumpToHero() {
    final heroIndex = gallery.indexWhere((g) => g.role == GalleryItemRole.hero);
    _animateTo(heroIndex >= 0 ? heroIndex : 0);
  }

  void jumpToOption(String optionKey, String valueId) {
    final values = product.optionSets[optionKey];
    if (values == null) return;
    final match = values.where((v) => v.valueId == valueId);
    if (match.isEmpty) return;
    _animateTo(match.first.firstGalleryIndex);
  }

  void _animateTo(int index) {
    if (!pageController.hasClients) {
      // المعرض لم يُركَّب بعد بالكامل — نحدّث الحالة المنطقية فوراً على
      // الأقل، وسيُطبَّق موضع الصفحة الفعلي عند أول إطار جاهز.
      _applyState(index);
      return;
    }
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  شريط المصغرات — Hero + Color + Size فقط (وليس كل صور Item، كما اشترطت)
  // ═══════════════════════════════════════════════════════════════════
  List<ThumbnailEntry> get thumbnails {
    final list = <ThumbnailEntry>[];
    final heroItem = gallery.where((g) => g.role == GalleryItemRole.hero);
    if (heroItem.isNotEmpty) {
      list.add(ThumbnailEntry(
        label: null,
        imageUrl: heroItem.first.thumbnailUrl ?? heroItem.first.url,
        isActive: _activeItemIndex != null,
        onTap: jumpToHero,
      ));
    }
    for (final entry in product.optionSets.entries) {
      for (final value in entry.value) {
        final isColor = entry.key == 'color';
        list.add(ThumbnailEntry(
          label: value.label,
          hex: isColor ? value.hex : null,
          imageUrl: _imageUrlForOption(entry.key, value),
          isActive: (entry.key == 'color' && _activeColorId == value.valueId) ||
              (entry.key == 'size' && _activeSizeId == value.valueId) ||
              (_activeOtherKey == entry.key && _activeOtherValueId == value.valueId),
          isAvailable: value.isAvailable,
          onTap: () => jumpToOption(entry.key, value.valueId),
        ));
      }
    }
    return list;
  }

  String? _imageUrlForOption(String key, ProductOptionValueRef value) {
    if (value.firstGalleryIndex >= 0 && value.firstGalleryIndex < gallery.length) {
      return gallery[value.firstGalleryIndex].thumbnailUrl ?? gallery[value.firstGalleryIndex].url;
    }
    return null;
  }

  @override
  void dispose() {
    pageController.removeListener(_onPageControllerChanged);
    pageController.dispose();
    super.dispose();
  }

  // ── دالة نقية مساعدة (تحقّقت في Python بـ 10 حالات) ─────────────────
  static _ResolvedState _resolveActiveState(
    int pageIndex,
    Map<String, List<ProductOptionValueRef>> optionSets,
  ) {
    final boundaries = <_Boundary>[];
    for (final entry in optionSets.entries) {
      for (final value in entry.value) {
        boundaries.add(_Boundary(value.firstGalleryIndex, entry.key, value.valueId));
      }
    }
    boundaries.sort((a, b) => a.index.compareTo(b.index));

    _Boundary? active;
    for (final b in boundaries) {
      if (b.index <= pageIndex) {
        active = b;
      } else {
        break;
      }
    }
    if (active == null) return _ResolvedState.itemZone();
    return _ResolvedState(key: active.key, valueId: active.valueId);
  }
}

class _Boundary {
  final int index;
  final String key;
  final String valueId;
  _Boundary(this.index, this.key, this.valueId);
}

class _ResolvedState {
  final bool isItemZone;
  final String? key;
  final String? valueId;
  const _ResolvedState({this.isItemZone = false, this.key, this.valueId});
  factory _ResolvedState.itemZone() => const _ResolvedState(isItemZone: true);
}

/// عنصر واحد داخل شريط المصغرات — بيانات جاهزة للعرض فقط (لا منطق).
class ThumbnailEntry {
  final String? label;
  final String? hex;
  final String? imageUrl;
  final bool isActive;
  final bool isAvailable;
  final VoidCallback onTap;
  const ThumbnailEntry({
    this.label,
    this.hex,
    this.imageUrl,
    required this.isActive,
    this.isAvailable = true,
    required this.onTap,
  });
}