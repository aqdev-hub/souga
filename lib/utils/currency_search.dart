// lib/utils/currency_search.dart
//
// بحث العملات: بالاسم العربي (ريال، ريال يمني، يمني) أو الإنجليزي (dollar،
// Yemeni Rial) أو الكود (USD) أو الرمز ($، €، ر.ي).

import 'currencies.dart';
import 'smart_search.dart';

List<SougaCurrency> searchCurrencies(String query, {List<SougaCurrency> source = kSougaCurrencies}) {
  return smartSearch<SougaCurrency>(
    source,
    query,
    fields: (c) => [c.name, c.en, c.code, c.symbol, ...c.aliases],
    exact: (c) => [c.code, c.symbol],
  );
}

/// القاعدة المطلوبة: نتيجة واحدة محددة → تُختار مباشرة؛ عدة نتائج → تُعرض كلها؛
/// لا شيء → رسالة "لا توجد نتائج". (الاستعلام الفارغ لا يختار شيئاً.)
SougaCurrency? autoPickCurrency(String query, List<SougaCurrency> results) {
  if (query.trim().isEmpty) return null;
  return results.length == 1 ? results.first : null;
}
