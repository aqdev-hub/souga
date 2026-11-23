// lib/services/product_draft_store.dart
//
// مسودة "إضافة منتج" — تُحفظ محلياً على جهاز البائع (SharedPreferences) لكل حساب.
// لماذا محلياً؟ حتى لا يظهر منتج ناقص للمشترين أبداً، ولا حاجة لتغيير قواعد
// Firestore ولا لتصفية استعلامات المنتجات العامة.
// تحفظ: الفئة، الأسماء والأوصاف، الأسعار والمخزون، الحالة، العملة، الصور
// والفيديو (روابط مرفوعة مسبقاً)، والمواصفات الوصفية. (لا تُحفظ المتغيرات/التركيبات.)

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductDraftStore {
  ProductDraftStore._();

  static String _key(String uid) => 'product_draft_v1_$uid';

  static Future<bool> save(String uid, Map<String, dynamic> draft) async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.setString(_key(uid), jsonEncode(draft));
    } catch (e) {
      debugPrint('[Draft] save error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> load(String uid) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key(uid));
      if (raw == null || raw.isEmpty) return null;
      final m = jsonDecode(raw);
      return m is Map ? Map<String, dynamic>.from(m) : null;
    } catch (e) {
      debugPrint('[Draft] load error: $e');
      return null;
    }
  }

  static Future<void> clear(String uid) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_key(uid));
    } catch (_) {}
  }
}
