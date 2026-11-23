// lib/utils/measure_units.dart
//
// وحدات القياس لخاصية الحجم/السعة/الوزن/الطول...: قائمة عربية مع الرمز واختصارات
// وأسماء إنجليزية للبحث. تُستخدم مع منتقي الوحدة (حقل بحث ذكي) ومع إدخال القيم
// المتعددة: وحدة واحدة × عدة قيم (5، 7، 12 لتر → "5 لتر" و"7 لتر" و"12 لتر").

import 'smart_search.dart';

class MeasureUnit {
  final String id;      // ثابت (l, kg, cm...)
  final String ar;      // الاسم العربي المعروض في القيم: "لتر"
  final String symbol;  // الرمز: L
  final String group;   // حجم/وزن/طول/مساحة/عدد/تخزين/كهرباء/زمن/أخرى
  final List<String> aliases;
  const MeasureUnit(this.id, this.ar, this.symbol, this.group, this.aliases);

  String get display => symbol == ar ? ar : '$ar ($symbol)';
}

const List<MeasureUnit> kMeasureUnits = [
  MeasureUnit('l', 'لتر', 'L', 'حجم', ['liter','litre','ltr','لتر']),
  MeasureUnit('ml', 'ملليلتر', 'ml', 'حجم', ['milliliter','millilitre','مل','مللي','ملي لتر']),
  MeasureUnit('gal', 'جالون', 'gal', 'حجم', ['gallon']),
  MeasureUnit('cup', 'كوب', 'cup', 'حجم', ['cup']),
  MeasureUnit('m3', 'متر مكعب', 'm³', 'حجم', ['cubic meter','م3']),
  MeasureUnit('cl', 'سنتيلتر', 'cl', 'حجم', ['centiliter']),
  MeasureUnit('kg', 'كيلوغرام', 'kg', 'وزن', ['كيلو','كجم','كغ','كيلوجرام','kilogram','kilo']),
  MeasureUnit('g', 'غرام', 'g', 'وزن', ['جرام','جم','gram','غم']),
  MeasureUnit('mg', 'ملليغرام', 'mg', 'وزن', ['ملغ','ملجم','ملليجرام','milligram']),
  MeasureUnit('ton', 'طن', 't', 'وزن', ['ton','tonne']),
  MeasureUnit('lb', 'رطل', 'lb', 'وزن', ['pound','باوند','lbs']),
  MeasureUnit('oz', 'أونصة', 'oz', 'وزن', ['ounce','اوقية','أوقية','اونصه']),
  MeasureUnit('carat', 'قيراط', 'ct', 'وزن', ['carat']),
  MeasureUnit('m', 'متر', 'm', 'طول', ['meter','metre','م']),
  MeasureUnit('cm', 'سنتيمتر', 'cm', 'طول', ['سم','centimeter','سنتي']),
  MeasureUnit('mm', 'مليمتر', 'mm', 'طول', ['ملم','millimeter','ملي']),
  MeasureUnit('km', 'كيلومتر', 'km', 'طول', ['كم','kilometer']),
  MeasureUnit('inch', 'بوصة', 'in', 'طول', ['إنش','انش','inch','بوصه','"']),
  MeasureUnit('ft', 'قدم', 'ft', 'طول', ['feet','foot','فوت']),
  MeasureUnit('yd', 'ياردة', 'yd', 'طول', ['yard','ياردا','ياردة']),
  MeasureUnit('mile', 'ميل', 'mi', 'طول', ['mile']),
  MeasureUnit('dhraa', 'ذراع', 'ذراع', 'طول', ['dhraa','cubit']),
  MeasureUnit('shibr', 'شبر', 'شبر', 'طول', []),
  MeasureUnit('lafa', 'لفة', 'لفة', 'طول', ['roll','رول','لفه']),
  MeasureUnit('m2', 'متر مربع', 'm²', 'مساحة', ['م2','square meter','sqm']),
  MeasureUnit('cm2', 'سنتيمتر مربع', 'cm²', 'مساحة', ['سم2']),
  MeasureUnit('ft2', 'قدم مربع', 'ft²', 'مساحة', ['sqft']),
  MeasureUnit('donum', 'دونم', 'دونم', 'مساحة', []),
  MeasureUnit('feddan', 'فدان', 'فدان', 'مساحة', ['acre']),
  MeasureUnit('pcs', 'قطعة', 'pcs', 'عدد', ['piece','حبة','وحدة','pc']),
  MeasureUnit('pack', 'عبوة', 'pack', 'عدد', ['علبة','package','باكيت','باكت']),
  MeasureUnit('box', 'علبة', 'box', 'عدد', ['صندوق','كرتون','carton']),
  MeasureUnit('carton', 'كرتون', 'ctn', 'عدد', ['كرتونة','carton']),
  MeasureUnit('dozen', 'دزينة', 'dz', 'عدد', ['دستة','dozen']),
  MeasureUnit('pair', 'زوج', 'pair', 'عدد', ['جوز','pair']),
  MeasureUnit('set', 'طقم', 'set', 'عدد', ['مجموعة','set','سيت']),
  MeasureUnit('bag', 'كيس', 'bag', 'عدد', ['شوال','bag']),
  MeasureUnit('bottle', 'زجاجة', 'btl', 'عدد', ['قارورة','bottle','عبوة']),
  MeasureUnit('can', 'علبة معدنية', 'can', 'عدد', ['can','معلبات']),
  MeasureUnit('sheet', 'ورقة', 'sheet', 'عدد', ['sheet']),
  MeasureUnit('tablet', 'قرص', 'tab', 'عدد', ['حبة','tablet','capsule','كبسولة']),
  MeasureUnit('kb', 'كيلوبايت', 'KB', 'تخزين', ['kilobyte']),
  MeasureUnit('mb', 'ميغابايت', 'MB', 'تخزين', ['ميجابايت','megabyte','ميقا']),
  MeasureUnit('gb', 'جيجابايت', 'GB', 'تخزين', ['غيغابايت','gigabyte','قيقا','جيجا','giga']),
  MeasureUnit('tb', 'تيرابايت', 'TB', 'تخزين', ['terabyte','تيرا']),
  MeasureUnit('w', 'واط', 'W', 'كهرباء', ['watt']),
  MeasureUnit('kw', 'كيلوواط', 'kW', 'كهرباء', ['kilowatt']),
  MeasureUnit('v', 'فولت', 'V', 'كهرباء', ['volt']),
  MeasureUnit('a', 'أمبير', 'A', 'كهرباء', ['amp','ampere','امبير']),
  MeasureUnit('mah', 'ميللي أمبير ساعة', 'mAh', 'كهرباء', ['mah','سعة البطارية']),
  MeasureUnit('hp', 'حصان', 'HP', 'كهرباء', ['horsepower','حصان']),
  MeasureUnit('btu', 'وحدة حرارية', 'BTU', 'كهرباء', ['btu']),
  MeasureUnit('hz', 'هرتز', 'Hz', 'كهرباء', ['hertz']),
  MeasureUnit('ghz', 'جيجاهرتز', 'GHz', 'كهرباء', ['ghz']),
  MeasureUnit('hour', 'ساعة', 'h', 'زمن', ['hour','hr']),
  MeasureUnit('day', 'يوم', 'd', 'زمن', ['day']),
  MeasureUnit('week', 'أسبوع', 'wk', 'زمن', ['week','اسبوع']),
  MeasureUnit('month', 'شهر', 'mo', 'زمن', ['month']),
  MeasureUnit('year', 'سنة', 'yr', 'زمن', ['year','عام']),
  MeasureUnit('mp', 'ميغابكسل', 'MP', 'أخرى', ['megapixel','ميجابكسل']),
  MeasureUnit('px', 'بكسل', 'px', 'أخرى', ['pixel']),
  MeasureUnit('pct', 'نسبة مئوية', '%', 'أخرى', ['percent','بالمئة','٪']),
  MeasureUnit('deg', 'درجة', '°', 'أخرى', ['degree','°c','سيلسيوس']),
  MeasureUnit('ply', 'طبقة', 'ply', 'أخرى', ['ply']),
];

MeasureUnit? measureUnitById(String? id) {
  if (id == null) return null;
  for (final u in kMeasureUnits) {
    if (u.id == id) return u;
  }
  return null;
}

/// بحث: بالاسم العربي، الرمز المختصر، الأسماء الإنجليزية/المختصرة، أو اسم المجموعة.
List<MeasureUnit> searchMeasureUnits(String query) => smartSearch<MeasureUnit>(
      kMeasureUnits,
      query,
      fields: (u) => [u.ar, u.symbol, ...u.aliases, u.group],
      exact: (u) => [u.symbol, u.id],
    );

/// يعيد التسمية المعروضة لقيمة قياس: "5 لتر" (قيم كسرية: 2.5 متر).
String measureLabel(String number, MeasureUnit unit) => '$number ${unit.ar}';

/// يستنتج الوحدة من تسميات قيم موجودة ("5 لتر", "7 لتر") عند فتح منتج للتعديل.
/// يُعيد null إن لم تتفق كل التسميات على وحدة واحدة.
MeasureUnit? inferMeasureUnit(Iterable<String> labels) {
  MeasureUnit? found;
  for (final l in labels) {
    final m = RegExp(r'^\s*[0-9]+(?:[.,][0-9]+)?\s+(.+?)\s*$').firstMatch(l);
    if (m == null) return null;
    final name = m.group(1)!;
    final u = kMeasureUnits.where((x) => x.ar == name).toList();
    if (u.isEmpty) return null;
    if (found != null && found.id != u.first.id) return null;
    found = u.first;
  }
  return found;
}

/// تحويل إدخال المستخدم إلى رقم نظيف بصيغة لاتينية: ٢٫٥ / 2,5 / 2.50 → "2.5".
/// يُعيد null إن لم يكن رقماً موجباً صالحاً.
String? normalizeMeasureNumber(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  const ai = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(ai[i], '$i');
  }
  s = s.replaceAll('٫', '.').replaceAll(',', '.').replaceAll('،', '.');
  if (!RegExp(r'^[0-9]+(?:\.[0-9]+)?$').hasMatch(s)) return null;
  final d = double.tryParse(s);
  if (d == null || d <= 0) return null;
  // إزالة الأصفار الزائدة: 2.50 → 2.5 ، 12.0 → 12
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s.replaceFirst(RegExp(r'^0+(?=[0-9])'), '');
}
