// lib/providers/cart_provider.dart
//
// ✅ تحديثان جوهريان في هذا الإصدار (بدون حذف أي وظيفة سابقة):
//   1. السلة أصبحت مرتبطة بـ uid المستخدم الحالي بدل مفتاح تخزين عام
//      واحد — يمنع تسرّب سلة مستخدم سابق لمستخدم آخر على نفس الجهاز.
//      يُستدعى bindUser(uid) من Wrapper عند كل تغيّر في حالة تسجيل الدخول.
//   2. حساب الإجمالي أصبح "لكل عملة على حدة" (totalsByCurrency) بدل رقم
//      واحد يجمع عملات مختلفة كأنها متطابقة (كان هذا باغاً حسابياً حقيقياً
//      عندما يضيف العميل منتجات بعملات مختلفة للسلة). القيمة القديمة
//      `total`/`currencySymbol` أُبقيت للتوافق الخلفي لكن مع تحذير واضح
//      في التعليق، والشاشات المحدَّثة (cart_screen/checkout_screen) تستخدم
//      الآن totalsByCurrency مباشرة.

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
  /// مفتاح الخريطة "رمز العملة" (currencySymbol) وقيمتها المجموع بهذه
  /// العملة فقط — لا يوجد أي جمع خاطئ بين عملات مختلفة بعد الآن.
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

  /// ✅ جديد — يُستدعى من Wrapper عند كل تغيّر لحالة تسجيل الدخول (بما فيها
  /// الدخول كزائر أو تسجيل الخروج) لتحميل سلة هذا المستخدم تحديداً بدل
  /// سلة عامة مشتركة بين كل من يستخدم نفس الجهاز.
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

  void addItem(ProductModel product, {int quantity = 1}) {
    final index = _items.indexWhere((i) => i.productId == product.id);
    if (index >= 0) {
      _items[index].quantity += quantity;
    } else {
      _items.add(CartItem(
        productId:      product.id,
        name:           product.name,
        price:          product.price,
        quantity:       quantity,
        image:          product.firstImage,
        sellerId:       product.sellerId,
        sellerName:     product.sellerName,
        currencySymbol: product.currencySymbol,
        currencyCode:   product.currencyCode,
      ));
    }
    notifyListeners();
    _saveToStorage();
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) { removeItem(productId); return; }
    final index = _items.indexWhere((i) => i.productId == productId);
    if (index >= 0) {
      _items[index].quantity = quantity;
      notifyListeners();
      _saveToStorage();
    }
  }

  void removeItem(String productId) {
    _items.removeWhere((i) => i.productId == productId);
    notifyListeners();
    _saveToStorage();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
    _saveToStorage();
  }

  bool isInCart(String productId) => _items.any((i) => i.productId == productId);
  int getQuantity(String productId) {
    final index = _items.indexWhere((i) => i.productId == productId);
    return index >= 0 ? _items[index].quantity : 0;
  }
}
