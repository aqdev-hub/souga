// lib/repositories/attribute_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attribute_model.dart';

class AttributeRepository {
  final FirebaseFirestore _fs;
  AttributeRepository({FirebaseFirestore? firestore}) : _fs = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _fs.collection('attribute_definitions');

  Future<List<AttributeDefinitionModel>> fetchAll() async {
    final snap = await _col.orderBy('order').get();
    return snap.docs.map((d) => AttributeDefinitionModel.fromMap(d.data(), d.id)).toList();
  }

  /// ✅ يجلب فقط الخصائص المرتبطة بمعرّفات مُعطاة — يُستخدم مع
  /// CategoryNode.inheritedAttributeIds لعرض الخصائص الصحيحة حسب الفئة
  /// المختارة تحديداً، دون تحميل كل خصائص النظام في كل مرة.
  ///
  /// ملاحظة تقنية: Firestore `whereIn` محدود بـ 30 عنصراً كحد أقصى لكل
  /// استعلام — نقسّم القائمة تلقائياً إلى دفعات لو تجاوزت هذا الحد، حتى
  /// تبقى الدالة صحيحة مهما كبر عدد خصائص الفئة مستقبلاً.
  Future<List<AttributeDefinitionModel>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final unique = ids.toSet().toList();
    final results = <AttributeDefinitionModel>[];
    const batchSize = 30;
    for (var i = 0; i < unique.length; i += batchSize) {
      final batch = unique.sublist(i, i + batchSize > unique.length ? unique.length : i + batchSize);
      final snap = await _col.where(FieldPath.documentId, whereIn: batch).get();
      results.addAll(snap.docs.map((d) => AttributeDefinitionModel.fromMap(d.data(), d.id)));
    }
    results.sort((a, b) => a.order.compareTo(b.order));
    return results;
  }

  Stream<List<AttributeDefinitionModel>> watchAll() {
    return _col.orderBy('order').snapshots().map(
          (snap) => snap.docs.map((d) => AttributeDefinitionModel.fromMap(d.data(), d.id)).toList(),
        );
  }
}
