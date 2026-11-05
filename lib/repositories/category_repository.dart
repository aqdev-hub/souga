// lib/repositories/category_repository.dart
//
// ✅ Repository Layer — كان غائباً تماماً عن المشروع سابقاً (كل الشاشات
// كانت تستدعي FirebaseFirestore.instance مباشرة). هذا أول مستودع من نظام
// Universal Product Engine، ويُبقي التبعية على Firestore في مكان واحد
// قابل للاستبدال/الاختبار لاحقاً بمعزل عن الواجهة.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final FirebaseFirestore _fs;
  CategoryRepository({FirebaseFirestore? firestore}) : _fs = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _fs.collection('categories');

  Future<List<CategoryModel>> fetchAll() async {
    final snap = await _col.orderBy('order').get();
    return snap.docs.map((d) => CategoryModel.fromMap(d.data(), d.id)).toList();
  }

  Stream<List<CategoryModel>> watchAll() {
    return _col.orderBy('order').snapshots().map(
          (snap) => snap.docs.map((d) => CategoryModel.fromMap(d.data(), d.id)).toList(),
        );
  }

  /// ✅ دالة نقية (Pure Function) — تبني الشجرة الهرمية الكاملة من القائمة
  /// المسطّحة، بأي عدد من المستويات، دون أي استعلام إضافي لـ Firestore.
  /// قابلة للاختبار بمعزل تام (لا تعتمد على Firebase إطلاقاً).
  static List<CategoryNode> buildTree(List<CategoryModel> flat) {
    final nodesById = <String, CategoryNode>{
      for (final c in flat) c.id: CategoryNode(category: c),
    };
    final roots = <CategoryNode>[];

    for (final c in flat) {
      final node = nodesById[c.id]!;
      if (c.isRoot) {
        roots.add(node);
      } else {
        final parentNode = nodesById[c.parentId];
        if (parentNode != null) {
          // ✅ إعادة بناء العقدة بأب صحيح (CategoryNode.parent نهائي/final)
          final linked = CategoryNode(category: c, parent: parentNode);
          parentNode.children.add(linked);
          nodesById[c.id] = linked;
        } else {
          // ✅ Fallback: أب محذوف/غير موجود — الفئة تظهر كجذر بدل أن تختفي
          // بصمت (لا تفقد أي فئة بسبب بيانات غير متسقة).
          roots.add(node);
        }
      }
    }

    roots.sort((a, b) => a.category.order.compareTo(b.category.order));
    for (final n in nodesById.values) {
      n.children.sort((a, b) => a.category.order.compareTo(b.category.order));
    }
    return roots;
  }

  /// ✅ كل الفئات "الورقية" (بلا أبناء) — هذه القائمة المفضَّلة افتراضياً
  /// لاختيار فئة منتج جديد، حسب قرارك المعتمد.
  static List<CategoryNode> collectLeaves(List<CategoryNode> tree) {
    final leaves = <CategoryNode>[];
    void walk(CategoryNode n) {
      if (n.isLeaf) {
        leaves.add(n);
      } else {
        for (final c in n.children) {
          walk(c);
        }
      }
    }
    for (final root in tree) {
      walk(root);
    }
    return leaves;
  }

  /// ✅ يبحث عن عقدة بمعرّف معيّن في الشجرة كاملة (بأي عمق).
  static CategoryNode? findById(List<CategoryNode> tree, String id) {
    for (final root in tree) {
      final found = _findInSubtree(root, id);
      if (found != null) return found;
    }
    return null;
  }

  static CategoryNode? _findInSubtree(CategoryNode node, String id) {
    if (node.category.id == id) return node;
    for (final child in node.children) {
      final found = _findInSubtree(child, id);
      if (found != null) return found;
    }
    return null;
  }
}
