// lib/providers/cart_provider.dart
//
// ✅ تحديثان جوهريان سابقان (بدون حذف أي وظيفة سابقة):
//   1. السلة أصبحت مرتبطة بـ uid المستخدم الحالي بدل مفتاح تخزين عام
//      واحد — يمنع تسرّب سلة مستخدم سابق لمستخدم آخر على نفس الجهاز.
//      يُستدعى bindUser(uid) من Wrapper عند كل تغيّر في حالة تسجيل الدخول.
//   2. حساب الإجمالي أصبح "لكل عملة على حدة" (totalsByCurrency) بدل رقم
//      واحد يجمع عملات مختلفة كأنها متطابقة.
//
// ✅ جديد — Variant-aware Cart (Universal Product Engine):
//   المفتاح المنطقي لسطر السلة أصبح (productId, variantId) بدل productId
//   فقط، حتى لا يختلط "قميص أحمر S" مع "قميص أزرق XL" كسطر واحد. كل دالة
//   تقبل الآن `variantId` اختيارياً (افتراضي null) — أي استدعاء قديم لا
//   يمرّره يستمر يعمل حرفياً كالسابق (توافق خلفي كامل، صفر كسر). السعر
//   المخزَّن في كل سطر Snapshot ثابت وقت الإضافة (راجع CartItem.price).

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_model.dart';
import '../models/product_model.dart';

class CartProvider extends ChangeNotifier {
  List<CartItem> _items = [];
  static const String _cartKeyPrefix = 'souga_cart_v2_';
  static const String _guestKey      = 'guest';

  String _boundUid = _guestKey;

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  bool get isEmpty => _items.isEmpty;

  /// ⚠️ للتوافق الخلفي فقط — يجمع كل الأسعار بصرف النظر عن العملة.
  /// لا تستخدمه لعرض إجمالي فعلي لسلة قد تحتوي عملات متعددة؛ استخدم
  /// [totalsByCurrency] بدلاً منه في أي واجهة جديدة.
  double get total => _items.fold(0, (sum, item) => sum + item.total);

  /// ✅ الإجمالي الصحيح: مبلغ منفصل لكل عملة موجودة فعلياً في السلة.
  Map<String, double> get totalsByCurrency {
    final map = <String, double>{};
    for (final item in _items) {
      map[item.currencySymbol] = (map[item.currencySymbol] ?? 0) + item.total;
    }
    return map;
  }

  /// هل تحتوي السلة أكثر من عملة واحدة؟ (تُستخدم لعرض تنبيه بالواجهة)
  bool get hasMixedCurrencies => totalsByCurrency.length > 1;

  CartProvider() { _loadFromStorage(); }

  String _keyFor(String uid) => '$_cartKeyPrefix$uid';

  /// ✅ يُستدعى من Wrapper عند كل تغيّر لحالة تسجيل الدخول.
  Future<void> bindUser(String? uid) async {
    final targetUid = (uid == null || uid.isEmpty) ? _guestKey : uid;
    if (targetUid == _boundUid) return; // لا تغيير فعلي
    _boundUid = targetUid;
    await _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyFor(_boundUid));
      if (json != null) {
        final list = jsonDecode(json) as List<dynamic>;
        _items = list.map((e) => CartItem.fromMap(e as Map<String, dynamic>)).toList();
      } else {
        _items = [];
      }
      notifyListeners();
    } catch (_) {
      _items = [];
      notifyListeners();
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyFor(_boundUid),
        jsonEncode(_items.map((e) => e.toMap()).toList()),
      );
    } catch (_) {}
  }

  /// ✅ المفتاح المنطقي الموحَّد لسطر سلة — (productId, variantId). منتج
  /// تقليدي بلا متغيرات: variantId=null، فيتطابق فقط مع نفسه (كما كان
  /// السلوك دائماً). منتج بمتغيرات: كل تركيبة (SKU) سطر مستقل تماماً.
  int _indexOf(String productId, String? variantId) =>
      _items.indexWhere((i) => i.productId == productId && i.variantId == variantId);

  /// [variantId]/[variantOptionValues]: مُمرَّرة فقط لمنتج بمتغيرات — راجع
  /// ProductVariantModel.id و"snapshot التسميات" في product_detail_screen.dart.
  /// [unitPriceOverride]: سعر الوحدة الفعلي وقت الإضافة (سعر التركيبة
  /// المختارة عادةً) — إن لم يُمرَّر، يُستخدَم product.price كما كان سابقاً
  /// (توافق خلفي كامل لكل استدعاء قديم من ProductCard وغيره).
  void addItem(
    ProductModel product, {
    int quantity = 1,
    String? variantId,
    Map<String, String>? variantOptionValues,
    double? unitPriceOverride,
  }) {
    final index = _indexOf(product.id, variantId);
    if (index >= 0) {
      _items[index].quantity += quantity;
      // ✅ لا نُحدِّث السعر المخزَّن لسطر موجود مسبقاً — يبقى Snapshot وقت
      // أول إضافة فعلية لهذه التركيبة بالذات، حتى لا "يتحرّك" السعر
      // المعروض في السلة تبعاً لأي تعديل لاحق على المنتج/التركيبة.
    } else {
      _items.add(CartItem(
        productId:      product.id,
        name:           product.name,
        price:          unitPriceOverride ?? product.price,
        quantity:       quantity,
        image:          product.firstImage,
        sellerId:       product.sellerId,
        sellerName:     product.sellerName,
        currencySymbol: product.currencySymbol,
        currencyCode:   product.currencyCode,
        variantId:            variantId,
        variantOptionValues:  variantOptionValues,
      ));
    }
    notifyListeners();
    _saveToStorage();
  }

  void updateQuantity(String productId, int quantity, {String? variantId}) {
    if (quantity <= 0) { removeItem(productId, variantId: variantId); return; }
    final index = _indexOf(productId, variantId);
    if (index >= 0) {
      _items[index].quantity = quantity;
      notifyListeners();
      _saveToStorage();
    }
  }

  void removeItem(String productId, {String? variantId}) {
    _items.removeWhere((i) => i.productId == productId && i.variantId == variantId);
    notifyListeners();
    _saveToStorage();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
    _saveToStorage();
  }

  bool isInCart(String productId, {String? variantId}) => _indexOf(productId, variantId) >= 0;

  int getQuantity(String productId, {String? variantId}) {
    final index = _indexOf(productId, variantId);
    return index >= 0 ? _items[index].quantity : 0;
  }
}
