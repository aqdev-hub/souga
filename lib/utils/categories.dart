// lib/utils/categories.dart
//
// ✅ جديد — مصدر واحد موحّد لتصنيفات سوجا الحقيقية (كانت مكرَّرة سابقاً في
// 5 ملفات مختلفة: home_screen, search_screen, add_product_screen,
// seller_products_screen, admin_products_screen — بقوائم غير متطابقة
// أحياناً). كل الشاشات المحدَّثة في هذا الإصدار (الصفحة الرئيسية والبحث)
// تستخدم هذا الملف الآن. يُنصح بترحيل بقية الشاشات إليه تباعاً.
import 'package:flutter/material.dart';

class SougaCategory {
  final String id;    // يُخزَّن في Firestore (product.category)
  final String name;  // الاسم المعروض بالعربية
  final IconData icon;
  const SougaCategory({required this.id, required this.name, required this.icon});
}

const List<SougaCategory> kSougaCategories = [
  SougaCategory(id: 'electronics', name: 'إلكترونيات', icon: Icons.devices_rounded),
  SougaCategory(id: 'clothes',     name: 'ملابس',       icon: Icons.checkroom_rounded),
  SougaCategory(id: 'food',        name: 'طعام',         icon: Icons.fastfood_rounded),
  SougaCategory(id: 'home',        name: 'منزل',         icon: Icons.chair_rounded),
  SougaCategory(id: 'sports',      name: 'رياضة',        icon: Icons.sports_soccer_rounded),
  SougaCategory(id: 'books',       name: 'كتب',          icon: Icons.menu_book_rounded),
  SougaCategory(id: 'perfumes',    name: 'العناية والجمال', icon: Icons.spa_rounded),
  SougaCategory(id: 'accessories', name: 'اكسسوارات',    icon: Icons.watch_rounded),
  SougaCategory(id: 'other',       name: 'أخرى',          icon: Icons.category_rounded),
];

/// الاسم العربي المعروض لمعرّف تصنيف معيّن (لبناء سياق واجهات/AI).
String sougaCategoryName(String id) {
  final match = kSougaCategories.where((c) => c.id == id);
  return match.isNotEmpty ? match.first.name : id;
}
