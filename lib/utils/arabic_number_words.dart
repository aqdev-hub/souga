// lib/utils/arabic_number_words.dart
//
// تفقيط الأرقام بالعربية (مرفوع): 50 → خمسون، 25 → خمسة وعشرون،
// 1,234,567 → مليون ومائتان وأربعة وثلاثون ألفاً وخمسمائة وسبعة وستون.
// يعمل على النص رقماً رقماً (بلا int/BigInt) فيدعم حتى 18 خانة دون أي تجاوز.
// يقبل الأرقام العربية-الهندية (٠١٢...) والفواصل (, ، ٬ _ مسافة).
//
// numberToArabicWords(text) → null إذا كان الإدخال فارغاً/غير صالح/أطول من 18 خانة.

const List<String> _units = [
  '', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة',
];
const List<String> _teens = [
  'عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر',
  'ستة عشر', 'سبعة عشر', 'ثمانية عشر', 'تسعة عشر',
];
const List<String> _tens = [
  '', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون',
];
const List<String> _hundreds = [
  '', 'مائة', 'مائتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة',
];

// [مفرد، مثنّى، جمع (3–10)، تمييز (11+)]
const List<List<String>> _scales = [
  [],
  ['ألف', 'ألفان', 'آلاف', 'ألفاً'],
  ['مليون', 'مليونان', 'ملايين', 'مليوناً'],
  ['مليار', 'ملياران', 'مليارات', 'ملياراً'],
  ['تريليون', 'تريليونان', 'تريليونات', 'تريليوناً'],
  ['كوادريليون', 'كوادريليونان', 'كوادريليونات', 'كوادريليوناً'],
];

/// 1..99
String _below100(int n) {
  if (n < 10) return _units[n];
  if (n < 20) return _teens[n - 10];
  final t = n ~/ 10, u = n % 10;
  return u == 0 ? _tens[t] : '${_units[u]} و${_tens[t]}';
}

/// 1..999
String _below1000(int n) {
  final h = n ~/ 100, r = n % 100;
  if (h == 0) return _below100(r);
  if (r == 0) return _hundreds[h];
  return '${_hundreds[h]} و${_below100(r)}';
}

/// عدد المجموعة [g] (1..999) مع اسم المرتبة [scale] (ألف/مليون...).
String _withScale(int g, List<String> scale) {
  if (g == 1) return scale[0];
  if (g == 2) return scale[1];
  final h = g ~/ 100, r = g % 100;
  final hw = h == 0 ? '' : _hundreds[h];
  if (r == 0) {
    // مائتا ألف (إضافة) وليس مائتان ألف
    final hword = h == 2 ? 'مائتا' : hw;
    return '$hword ${scale[0]}';
  }
  if (r == 1 && h > 0) return '$hw و${scale[0]}';
  if (r == 2 && h > 0) return '$hw و${scale[1]}';
  if (r >= 3 && r <= 10) {
    final rw = r == 10 ? 'عشرة' : _units[r];
    return '${h > 0 ? '$hw و' : ''}$rw ${scale[2]}';
  }
  return '${_below1000(g)} ${scale[3]}';
}

const String _arabicIndic = '٠١٢٣٤٥٦٧٨٩';

String? numberToArabicWords(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  final buf = StringBuffer();
  for (final ch in s.split('')) {
    final i = _arabicIndic.indexOf(ch);
    if (i >= 0) {
      buf.write(i);
    } else if (RegExp(r'[0-9]').hasMatch(ch)) {
      buf.write(ch);
    } else if (ch == ',' || ch == '،' || ch == '٬' || ch == '_' || ch == ' ') {
      continue;
    } else {
      return null; // حرف/نقطة عشرية/علامة → غير صالح
    }
  }
  s = buf.toString().replaceFirst(RegExp(r'^0+'), '');
  if (buf.isEmpty) return null;
  if (s.isEmpty) return 'صفر';
  if (s.length > 18) return null;

  // مجموعات من 3 خانات من اليمين
  final groups = <int>[];
  for (var end = s.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    groups.add(int.parse(s.substring(start, end)));
  }
  final parts = <String>[];
  for (var k = groups.length - 1; k >= 0; k--) {
    final g = groups[k];
    if (g == 0) continue;
    parts.add(k == 0 ? _below1000(g) : _withScale(g, _scales[k]));
  }
  return parts.join(' و');
}
