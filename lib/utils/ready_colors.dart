// lib/utils/ready_colors.dart
//
// ✅ الألوان الجاهزة (قوس قزح + محايدة) وقوالب الخصائص الشائعة الجاهزة.
// الاسم العربي + الـ hex يُحفظان كما هما (لا تقريب) ويمكن للبائع تعديلهما لاحقاً.

class ReadyColor {
  final String name;
  final String hex; // '#RRGGBB'
  const ReadyColor(this.name, this.hex);
}

const List<ReadyColor> kReadyColors = [
  // محايدة
  ReadyColor('أسود', '#111111'),
  ReadyColor('أبيض', '#FFFFFF'),
  ReadyColor('رمادي', '#808080'),
  ReadyColor('رمادي فاتح', '#C8C8C8'),
  ReadyColor('رمادي غامق', '#4A4A4A'),
  ReadyColor('فضي', '#C0C0C0'),
  ReadyColor('بيج', '#F5F5DC'),
  ReadyColor('كريمي', '#FFFDD0'),
  ReadyColor('بني', '#8B4513'),
  ReadyColor('بني فاتح', '#B5835A'),
  ReadyColor('كاكي', '#BDB76B'),
  // قوس قزح
  ReadyColor('أحمر', '#E53935'),
  ReadyColor('أحمر غامق', '#8B0000'),
  ReadyColor('عنابي', '#800020'),
  ReadyColor('وردي', '#FFC0CB'),
  ReadyColor('وردي غامق', '#E91E8C'),
  ReadyColor('فوشيا', '#FF00FF'),
  ReadyColor('برتقالي', '#FB8C00'),
  ReadyColor('مشمشي', '#FBCEB1'),
  ReadyColor('أصفر', '#FDD835'),
  ReadyColor('ذهبي', '#D4AF37'),
  ReadyColor('ليموني', '#CDDC39'),
  ReadyColor('أخضر', '#43A047'),
  ReadyColor('أخضر فاتح', '#9CCC65'),
  ReadyColor('أخضر غامق', '#1B5E20'),
  ReadyColor('زيتي', '#6B7A2A'),
  ReadyColor('نعناعي', '#98FF98'),
  ReadyColor('تركوازي', '#1ABC9C'),
  ReadyColor('سماوي', '#00BCD4'),
  ReadyColor('أزرق فاتح', '#64B5F6'),
  ReadyColor('أزرق', '#1E88E5'),
  ReadyColor('أزرق غامق', '#0D2A6B'),
  ReadyColor('كحلي', '#1F2A44'),
  ReadyColor('نيلي', '#3F51B5'),
  ReadyColor('بنفسجي', '#8E24AA'),
  ReadyColor('بنفسجي فاتح', '#CE93D8'),
  ReadyColor('لافندر', '#B497BD'),
  ReadyColor('خوخي', '#FFB48F'),
  ReadyColor('نحاسي', '#B87333'),
  ReadyColor('برونزي', '#CD7F32'),
];

/// قالب خاصية جاهزة شائعة: اسم + نوع + قيم مُعبَّأة مسبقاً (قابلة للتعديل كلياً).
class ReadyAttributeTemplate {
  final String name;
  final String kind; // 'options' | 'spec' | 'measure'
  final List<String> values;
  final String? hint;
  const ReadyAttributeTemplate(this.name, this.kind, this.values, {this.hint});
}

const List<ReadyAttributeTemplate> kReadyAttributeTemplates = [
  ReadyAttributeTemplate('المقاس', 'options', ['S', 'M', 'L', 'XL', 'XXL']),
  ReadyAttributeTemplate('مقاس الحذاء', 'options', ['38', '39', '40', '41', '42', '43', '44']),
  ReadyAttributeTemplate('السعة', 'options', ['64 جيجابايت', '128 جيجابايت', '256 جيجابايت', '512 جيجابايت']),
  ReadyAttributeTemplate('الرام', 'options', ['4 جيجابايت', '6 جيجابايت', '8 جيجابايت', '12 جيجابايت']),
  ReadyAttributeTemplate('الخامة', 'spec', ['قطن', 'بوليستر', 'جلد', 'صوف', 'حرير', 'كتان']),
  ReadyAttributeTemplate('بلد الصنع', 'spec', ['اليمن', 'السعودية', 'تركيا', 'الصين', 'الهند', 'مصر']),
  ReadyAttributeTemplate('الضمان', 'spec', ['بدون ضمان', 'شهر', '3 أشهر', '6 أشهر', 'سنة', 'سنتان']),
  ReadyAttributeTemplate('نوع المنتج', 'spec', ['جديد', 'أصلي', 'تقليد عالي الجودة']),
  ReadyAttributeTemplate('الجنس', 'spec', ['رجالي', 'نسائي', 'أطفال', 'للجنسين']),
  ReadyAttributeTemplate('الموسم', 'spec', ['صيفي', 'شتوي', 'خريفي', 'ربيعي', 'لكل المواسم']),
  ReadyAttributeTemplate('طريقة الاستخدام', 'spec', []),
  ReadyAttributeTemplate('الحجم', 'measure', []),
  ReadyAttributeTemplate('الوزن', 'measure', []),
  ReadyAttributeTemplate('الطول', 'measure', []),
];

/// تحويل '#RRGGBB' إلى قيمة ARGB؛ null عند عدم الصلاحية.
int? hexToArgb(String? hex) {
  if (hex == null) return null;
  final c = hex.replaceAll('#', '').trim();
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(c)) return null;
  return int.parse('FF$c', radix: 16);
}

String argbToHex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
