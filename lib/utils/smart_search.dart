// lib/utils/smart_search.dart
//
// بحث ذكي وسريع للقوائم الصغيرة/المتوسطة (عملات، وحدات قياس...):
//   • يطبّع العربية (الألف/الياء/التاء المربوطة/التشكيل) عبر normalizeSearch.
//   • الاستعلام متعدد الكلمات: كل كلمة يجب أن تطابق (AND) — "ريال يمني" → نتيجة واحدة.
//   • الترتيب: تطابق تام (رمز/كود) ‹ بداية الحقل ‹ بداية كلمة ‹ احتواء.
//   • ثابت (Stable) عند تساوي الدرجة: يحافظ على ترتيب القائمة الأصلي.

import 'search_text.dart';

List<T> smartSearch<T>(
  List<T> items,
  String query, {
  required List<String> Function(T) fields,
  List<String> Function(T)? exact,
}) {
  final tokens = normalizeSearch(query).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return List<T>.of(items);

  final scored = <(int, int, T)>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final fs = fields(item).map(normalizeSearch).where((f) => f.isNotEmpty).toList();
    final ex = (exact?.call(item) ?? const <String>[]).map(normalizeSearch).toSet();
    var total = 0;
    var ok = true;
    for (final t in tokens) {
      var best = 0;
      if (ex.contains(t)) best = 100;
      for (final f in fs) {
        int s = 0;
        if (f == t) {
          s = 95;
        } else if (f.startsWith(t)) {
          s = 80;
        } else if (f.split(RegExp(r'\s+')).any((w) => w.startsWith(t))) {
          s = 70;
        } else if (f.contains(t)) {
          s = 50;
        }
        if (s > best) best = s;
      }
      if (best == 0) {
        ok = false;
        break;
      }
      total += best;
    }
    if (ok) scored.add((total, i, item));
  }
  scored.sort((a, b) {
    final c = b.$1.compareTo(a.$1);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  return [for (final s in scored) s.$3];
}
