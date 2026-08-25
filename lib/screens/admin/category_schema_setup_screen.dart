// lib/screens/admin/category_schema_setup_screen.dart
//
// ✅ المرحلة 1 من خطة Universal Product Engine — تعبئة بيانات فقط، بلا أي
// تغيير على أي شاشة أو منطق موجود حالياً في التطبيق. آمنة للتشغيل أكثر
// من مرة (Idempotent) — تتحقق من وجود كل مستند قبل الكتابة فوقه بلا داعٍ.
//
// ⚠️ معرّفات الفئات هنا مطابقة *حرفياً* لقيم الحقل category المسطّح
// القديم (electronics, clothes, food...) — هذا مقصود ومهم جداً: أي منتج
// قديم موجود بالفعل في Firestore سيجد فئته الجديدة بنفس المعرّف تماماً،
// فيعمل معه محرك الفئات الجديد فوراً بلا أي ترحيل بيانات يدوي على منتج
// واحد. الفئات الجذرية (إلكترونيات، ملابس) تبقى "قابلة للاختيار" أيضاً
// كـ Fallback حتى بعد إضافة فئات فرعية تحتها — بالضبط كما اعتمدت.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class CategorySchemaSetupScreen extends StatefulWidget {
  const CategorySchemaSetupScreen({super.key});
  @override
  State<CategorySchemaSetupScreen> createState() => _CategorySchemaSetupScreenState();
}

class _CategorySchemaSetupScreenState extends State<CategorySchemaSetupScreen> {
  bool _isLoading = false;
  String _status = '';

  // ── تعريفات الخصائص (Attribute Definitions) ──────────────────────────
  // isVariant=true → تُنتج تركيبات SKU (سعر/مخزون مستقل لكل قيمة)
  // isVariant=false → مواصفة وصفية فقط تُعرض في قسم Specifications
  static final List<Map<String, dynamic>> _attributes = [
    {
      'id': 'color', 'key': 'color', 'name': 'اللون', 'type': 'colorSwatch',
      'isVariant': true, 'order': 1,
      'predefinedValues': [
        {'id': 'red', 'label': 'أحمر', 'hex': '#C8102E'},
        {'id': 'blue', 'label': 'أزرق', 'hex': '#1E90FF'},
        {'id': 'black', 'label': 'أسود', 'hex': '#111111'},
        {'id': 'white', 'label': 'أبيض', 'hex': '#FFFFFF'},
        {'id': 'green', 'label': 'أخضر', 'hex': '#2E8B57'},
      ],
    },
    {
      'id': 'size', 'key': 'size', 'name': 'المقاس', 'type': 'select',
      'isVariant': true, 'order': 2,
      'predefinedValues': [
        {'id': 's', 'label': 'S'}, {'id': 'm', 'label': 'M'},
        {'id': 'l', 'label': 'L'}, {'id': 'xl', 'label': 'XL'},
        {'id': 'xxl', 'label': 'XXL'},
      ],
    },
    {
      'id': 'material', 'key': 'material', 'name': 'نوع القماش', 'type': 'select',
      'isVariant': false, 'order': 3,
      'predefinedValues': [
        {'id': 'cotton', 'label': 'قطن'}, {'id': 'polyester', 'label': 'بوليستر'},
        {'id': 'wool', 'label': 'صوف'}, {'id': 'leather', 'label': 'جلد'},
      ],
    },
    {
      'id': 'ram', 'key': 'ram', 'name': 'الرام', 'type': 'select',
      'isVariant': true, 'order': 4,
      'predefinedValues': [
        {'id': '4gb', 'label': '4GB'}, {'id': '6gb', 'label': '6GB'},
        {'id': '8gb', 'label': '8GB'}, {'id': '12gb', 'label': '12GB'},
      ],
    },
    {
      'id': 'storage', 'key': 'storage', 'name': 'التخزين', 'type': 'select',
      'isVariant': true, 'order': 5,
      'predefinedValues': [
        {'id': '64gb', 'label': '64GB'}, {'id': '128gb', 'label': '128GB'},
        {'id': '256gb', 'label': '256GB'}, {'id': '512gb', 'label': '512GB'},
      ],
    },
    {
      'id': 'processor', 'key': 'processor', 'name': 'المعالج', 'type': 'text',
      'isVariant': false, 'order': 6, 'predefinedValues': [],
    },
    {
      'id': 'battery', 'key': 'battery', 'name': 'البطارية', 'type': 'text',
      'isVariant': false, 'order': 7, 'predefinedValues': [],
    },
  ];

  // ── شجرة الفئات ────────────────────────────────────────────────────
  // ⚠️ id مطابق حرفياً لقيمة category القديمة عند الفئات الجذرية.
  static final List<Map<String, dynamic>> _categories = [
    {'id': 'electronics', 'name': 'إلكترونيات', 'iconKey': 'devices', 'parentId': null, 'order': 1, 'attributeIds': <String>[]},
    {'id': 'electronics_phones', 'name': 'هواتف', 'iconKey': 'smartphone', 'parentId': 'electronics', 'order': 1, 'attributeIds': ['ram', 'storage', 'processor', 'battery']},
    {'id': 'electronics_headphones', 'name': 'سماعات', 'iconKey': 'headphones', 'parentId': 'electronics', 'order': 2, 'attributeIds': ['battery', 'color']},

    {'id': 'clothes', 'name': 'ملابس', 'iconKey': 'checkroom', 'parentId': null, 'order': 2, 'attributeIds': <String>[]},
    {'id': 'clothes_men', 'name': 'رجالي', 'iconKey': 'man', 'parentId': 'clothes', 'order': 1, 'attributeIds': ['color', 'size', 'material']},
    {'id': 'clothes_women', 'name': 'نسائي', 'iconKey': 'woman', 'parentId': 'clothes', 'order': 2, 'attributeIds': ['color', 'size', 'material']},

    {'id': 'food', 'name': 'طعام', 'iconKey': 'fastfood', 'parentId': null, 'order': 3, 'attributeIds': <String>[]},
    {'id': 'home', 'name': 'منزل', 'iconKey': 'chair', 'parentId': null, 'order': 4, 'attributeIds': <String>[]},
    {'id': 'sports', 'name': 'رياضة', 'iconKey': 'sports_soccer', 'parentId': null, 'order': 5, 'attributeIds': <String>[]},
    {'id': 'books', 'name': 'كتب', 'iconKey': 'menu_book', 'parentId': null, 'order': 6, 'attributeIds': <String>[]},
    {'id': 'perfumes', 'name': 'العناية والجمال', 'iconKey': 'spa', 'parentId': null, 'order': 7, 'attributeIds': ['color']},
    {'id': 'accessories', 'name': 'اكسسوارات', 'iconKey': 'watch', 'parentId': null, 'order': 8, 'attributeIds': ['color']},
    {'id': 'other', 'name': 'أخرى', 'iconKey': 'category', 'parentId': null, 'order': 9, 'attributeIds': <String>[]},
  ];

  Future<void> _runSetup() async {
    setState(() { _isLoading = true; _status = 'جاري التحقق من البيانات الحالية...'; });
    final fs = FirebaseFirestore.instance;

    try {
      int attrsWritten = 0, attrsSkipped = 0;
      for (final a in _attributes) {
        final id = a['id'] as String;
        final ref = fs.collection('attribute_definitions').doc(id);
        final existing = await ref.get();
        if (existing.exists) { attrsSkipped++; continue; }
        await ref.set({
          'key': a['key'], 'name': a['name'], 'type': a['type'],
          'isVariant': a['isVariant'], 'order': a['order'],
          'predefinedValues': a['predefinedValues'],
        });
        attrsWritten++;
        setState(() => _status = 'خصائص: $attrsWritten جديدة، $attrsSkipped موجودة مسبقاً...');
      }

      int catsWritten = 0, catsSkipped = 0;
      for (final c in _categories) {
        final id = c['id'] as String;
        final ref = fs.collection('categories').doc(id);
        final existing = await ref.get();
        if (existing.exists) { catsSkipped++; continue; }
        await ref.set({
          'name': c['name'], 'iconKey': c['iconKey'], 'parentId': c['parentId'],
          'order': c['order'], 'attributeIds': c['attributeIds'],
        });
        catsWritten++;
        setState(() => _status = 'فئات: $catsWritten جديدة، $catsSkipped موجودة مسبقاً...');
      }

      setState(() {
        _isLoading = false;
        _status = '✅ اكتمل الإعداد.\n'
            'الخصائص: $attrsWritten جديدة / $attrsSkipped كانت موجودة مسبقاً.\n'
            'الفئات: $catsWritten جديدة / $catsSkipped كانت موجودة مسبقاً.\n\n'
            'لم يتغيّر أي منتج أو شاشة حالية — هذه بيانات إعداد فقط.';
      });
    } catch (e) {
      setState(() { _isLoading = false; _status = '❌ خطأ: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('إعداد شجرة الفئات والخصائص')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.account_tree_outlined, size: 80, color: colors.primary),
          const SizedBox(height: 20),
          const Text('المرحلة 1 — Universal Product Engine',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'ينشئ ${_categories.length} فئة (بمستويين هرميين) و${_attributes.length} خاصية ديناميكية.\n'
            'آمن للتشغيل أكثر من مرة — لا يكتب فوق أي بيانات موجودة، ولا يغيّر أي منتج حالي.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          if (_status.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.6)),
            ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _runSetup,
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_isLoading ? 'جاري التنفيذ...' : 'تشغيل الإعداد'),
          ),
        ]),
      ),
    );
  }
}
