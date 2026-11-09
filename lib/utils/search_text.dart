// lib/utils/search_text.dart
//
// تطبيع النص العربي للبحث: يتجاهل التشكيل واختلاف الألف/الياء/التاء المربوطة
// والحالة، فيجد "إلكترونيات" عند كتابة "الكترونيات" و"مدرسه" عند "مدرسة".

final RegExp _tashkeel = RegExp(r'[ً-ْـ]');

String normalizeSearch(String input) {
  var s = input.toLowerCase().trim();
  s = s.replaceAll(_tashkeel, '');
  s = s
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
  // أرقام عربية-هندية → لاتينية
  const ar = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < ar.length; i++) {
    s = s.replaceAll(ar[i], '$i');
  }
  return s;
}

bool searchMatches(String haystack, String normalizedQuery) =>
    normalizeSearch(haystack).contains(normalizedQuery);
