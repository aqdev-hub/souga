// lib/utils/currencies.dart
//
// ✅ مصدر واحد موحّد لقائمة العملات العالمية، مُستخرَجة من
// `_Currency`/`_kCurrencies` الخاصة بـ `add_product_screen.dart` (كانت
// private داخل ذلك الملف فقط). الهدف: تمكين `add_edit_product_stepper_screen.dart`
// الجديد من استخدام نفس القائمة بدل تكرارها، مع الإبقاء على
// `add_product_screen.dart` القديم يعمل تماماً كما هو دون أي لمس — لم
// يُعدَّل ذلك الملف إطلاقاً في هذه الخطوة (سيُحذَف لاحقاً في خطوة الربط
// النهائية بعد موافقة صريحة، حسب HANDOFF).

class SougaCurrency {
  final String code;   // USD
  final String name;   // دولار أمريكي
  final String symbol; // $
  final String en;     // US Dollar — للبحث بالإنجليزية
  final List<String> aliases; // أسماء/اختصارات بديلة للبحث (يمني، dollar، SR...)

  const SougaCurrency(this.code, this.name, this.symbol, {this.en = '', this.aliases = const []});

  String get display => '$symbol $code — $name';
}

/// قائمة العملات (الخليج أولاً ثم العربية ثم العالمية). كل عملة تحمل اسمها
/// الإنجليزي وأسماء بديلة ليعمل البحث بالعربية والإنجليزية والرمز.
const List<SougaCurrency> kSougaCurrencies = [
  SougaCurrency('SAR', 'ريال سعودي', '﷼', en: 'Saudi Riyal', aliases: ['SR','ر.س','سعودي']),
  SougaCurrency('AED', 'درهم إماراتي', 'د.إ', en: 'UAE Dirham', aliases: ['dirham','اماراتي','إماراتي']),
  SougaCurrency('KWD', 'دينار كويتي', 'د.ك', en: 'Kuwaiti Dinar', aliases: ['كويتي']),
  SougaCurrency('BHD', 'دينار بحريني', 'د.ب', en: 'Bahraini Dinar', aliases: ['بحريني']),
  SougaCurrency('QAR', 'ريال قطري', 'ر.ق', en: 'Qatari Riyal', aliases: ['قطري']),
  SougaCurrency('OMR', 'ريال عُماني', 'ر.ع', en: 'Omani Rial', aliases: ['عماني','Omani Riyal']),
  SougaCurrency('EGP', 'جنيه مصري', 'ج.م', en: 'Egyptian Pound', aliases: ['مصري','LE']),
  SougaCurrency('JOD', 'دينار أردني', 'د.أ', en: 'Jordanian Dinar', aliases: ['اردني']),
  SougaCurrency('IQD', 'دينار عراقي', 'ع.د', en: 'Iraqi Dinar', aliases: ['عراقي']),
  SougaCurrency('SYP', 'ليرة سورية', 'ل.س', en: 'Syrian Pound', aliases: ['سوري','سوريه']),
  SougaCurrency('LBP', 'ليرة لبنانية', 'ل.ل', en: 'Lebanese Pound', aliases: ['لبناني','لبنانيه']),
  SougaCurrency('TND', 'دينار تونسي', 'د.ت', en: 'Tunisian Dinar', aliases: ['تونسي']),
  SougaCurrency('MAD', 'درهم مغربي', 'د.م', en: 'Moroccan Dirham', aliases: ['مغربي']),
  SougaCurrency('DZD', 'دينار جزائري', 'دج', en: 'Algerian Dinar', aliases: ['جزائري']),
  SougaCurrency('LYD', 'دينار ليبي', 'ل.د', en: 'Libyan Dinar', aliases: ['ليبي']),
  SougaCurrency('SDG', 'جنيه سوداني', 'ج.س', en: 'Sudanese Pound', aliases: ['سوداني']),
  SougaCurrency('YER', 'ريال يمني', 'ر.ي', en: 'Yemeni Rial', aliases: ['يمني','Yemeni Riyal','YR']),
  SougaCurrency('USD', 'دولار أمريكي', '\$', en: 'US Dollar', aliases: ['dollar','دولار','امريكي','أمريكي','buck']),
  SougaCurrency('EUR', 'يورو', '€', en: 'Euro', aliases: ['اورو','أورو']),
  SougaCurrency('GBP', 'جنيه إسترليني', '£', en: 'British Pound', aliases: ['pound','sterling','استرليني','بريطاني']),
  SougaCurrency('JPY', 'ين ياباني', '¥', en: 'Japanese Yen', aliases: ['yen','ياباني']),
  SougaCurrency('CNY', 'يوان صيني', '¥', en: 'Chinese Yuan', aliases: ['yuan','RMB','صيني','رنمينبي']),
  SougaCurrency('CAD', 'دولار كندي', 'C\$', en: 'Canadian Dollar', aliases: ['كندي']),
  SougaCurrency('AUD', 'دولار أسترالي', 'A\$', en: 'Australian Dollar', aliases: ['استرالي','أسترالي']),
  SougaCurrency('CHF', 'فرنك سويسري', 'Fr', en: 'Swiss Franc', aliases: ['franc','سويسري']),
  SougaCurrency('TRY', 'ليرة تركية', '₺', en: 'Turkish Lira', aliases: ['lira','تركي','تركيه']),
  SougaCurrency('INR', 'روبية هندية', '₹', en: 'Indian Rupee', aliases: ['rupee','هندي','هنديه']),
  SougaCurrency('BRL', 'ريال برازيلي', 'R\$', en: 'Brazilian Real', aliases: ['برازيلي']),
  SougaCurrency('MXN', 'بيزو مكسيكي', '\$', en: 'Mexican Peso', aliases: ['peso','مكسيكي']),
  SougaCurrency('RUB', 'روبل روسي', '₽', en: 'Russian Ruble', aliases: ['ruble','روسي']),
  SougaCurrency('KRW', 'وون كوري', '₩', en: 'South Korean Won', aliases: ['won','كوري']),
  SougaCurrency('SGD', 'دولار سنغافوري', 'S\$', en: 'Singapore Dollar', aliases: ['سنغافوري']),
  SougaCurrency('HKD', 'دولار هونغ كونغ', 'HK\$', en: 'Hong Kong Dollar', aliases: ['هونج كونج','هونغ كونغ']),
  SougaCurrency('SEK', 'كرونة سويدية', 'kr', en: 'Swedish Krona', aliases: ['krona','سويدي']),
  SougaCurrency('NOK', 'كرونة نرويجية', 'kr', en: 'Norwegian Krone', aliases: ['krone','نرويجي']),
  SougaCurrency('DKK', 'كرونة دانماركية', 'kr', en: 'Danish Krone', aliases: ['دنماركي','دانماركي']),
  SougaCurrency('PLN', 'زلوتي بولندي', 'zł', en: 'Polish Zloty', aliases: ['zloty','بولندي']),
  SougaCurrency('IDR', 'روبية إندونيسية', 'Rp', en: 'Indonesian Rupiah', aliases: ['rupiah','اندونيسي','إندونيسي']),
  SougaCurrency('MYR', 'رينغيت ماليزي', 'RM', en: 'Malaysian Ringgit', aliases: ['ringgit','ماليزي','رنجيت']),
  SougaCurrency('THB', 'بات تايلاندي', '฿', en: 'Thai Baht', aliases: ['baht','تايلندي','تايلاندي']),
  SougaCurrency('PKR', 'روبية باكستانية', '₨', en: 'Pakistani Rupee', aliases: ['باكستاني']),
  SougaCurrency('NGN', 'نيرة نيجيرية', '₦', en: 'Nigerian Naira', aliases: ['naira','نيجيري']),
  SougaCurrency('ZAR', 'راند جنوب أفريقي', 'R', en: 'South African Rand', aliases: ['rand','جنوب افريقي']),
  SougaCurrency('ILS', 'شيكل إسرائيلي', '₪', en: 'Israeli Shekel', aliases: ['shekel','شيكل']),
  SougaCurrency('IRR', 'ريال إيراني', '﷼', en: 'Iranian Rial', aliases: ['ايراني','Iranian Riyal']),
  SougaCurrency('AFN', 'أفغاني', '؋', en: 'Afghan Afghani', aliases: ['afghani','افغاني']),
  SougaCurrency('ETB', 'بير إثيوبي', 'Br', en: 'Ethiopian Birr', aliases: ['birr','اثيوبي']),
  SougaCurrency('KES', 'شلن كيني', 'KSh', en: 'Kenyan Shilling', aliases: ['shilling','كيني']),
  SougaCurrency('TZS', 'شلن تنزاني', 'TSh', en: 'Tanzanian Shilling', aliases: ['تنزاني']),
  SougaCurrency('UGX', 'شلن أوغندي', 'USh', en: 'Ugandan Shilling', aliases: ['اوغندي','أوغندي']),
  SougaCurrency('GHS', 'سيدي غاني', 'GH₵', en: 'Ghanaian Cedi', aliases: ['cedi','غاني']),
  SougaCurrency('XAF', 'فرنك وسط أفريقي', 'FCFA', en: 'CFA Franc BEAC', aliases: ['فرنك افريقي']),
  SougaCurrency('XOF', 'فرنك غرب أفريقي', 'CFA', en: 'CFA Franc BCEAO', aliases: ['فرنك سيفا']),
  SougaCurrency('SOS', 'شلن صومالي', 'Sh', en: 'Somali Shilling', aliases: ['صومالي']),
  SougaCurrency('DJF', 'فرنك جيبوتي', 'Fdj', en: 'Djiboutian Franc', aliases: ['جيبوتي']),
  SougaCurrency('MRU', 'أوقية موريتانية', 'UM', en: 'Mauritanian Ouguiya', aliases: ['اوقية','موريتاني']),
  SougaCurrency('KMF', 'فرنك قمري', 'CF', en: 'Comorian Franc', aliases: ['قمري']),
  SougaCurrency('ARS', 'بيزو أرجنتيني', '\$', en: 'Argentine Peso', aliases: ['ارجنتيني','أرجنتيني']),
  SougaCurrency('CLP', 'بيزو تشيلي', '\$', en: 'Chilean Peso', aliases: ['تشيلي']),
  SougaCurrency('COP', 'بيزو كولومبي', '\$', en: 'Colombian Peso', aliases: ['كولومبي']),
  SougaCurrency('PEN', 'سول بيروفي', 'S/', en: 'Peruvian Sol', aliases: ['sol','بيروفي']),
  SougaCurrency('NZD', 'دولار نيوزيلندي', 'NZ\$', en: 'New Zealand Dollar', aliases: ['نيوزيلندي']),
  SougaCurrency('CZK', 'كرونة تشيكية', 'Kč', en: 'Czech Koruna', aliases: ['تشيكي']),
  SougaCurrency('HUF', 'فورنت مجري', 'Ft', en: 'Hungarian Forint', aliases: ['forint','مجري']),
  SougaCurrency('RON', 'ليو روماني', 'lei', en: 'Romanian Leu', aliases: ['leu','روماني']),
  SougaCurrency('UAH', 'هريفنيا أوكرانية', '₴', en: 'Ukrainian Hryvnia', aliases: ['hryvnia','اوكراني','أوكراني']),
  SougaCurrency('VND', 'دونغ فيتنامي', '₫', en: 'Vietnamese Dong', aliases: ['dong','فيتنامي']),
  SougaCurrency('PHP', 'بيزو فلبيني', '₱', en: 'Philippine Peso', aliases: ['فلبيني']),
  SougaCurrency('BDT', 'تاكا بنغلاديشية', '৳', en: 'Bangladeshi Taka', aliases: ['taka','بنغلاديشي']),
  SougaCurrency('LKR', 'روبية سريلانكية', 'Rs', en: 'Sri Lankan Rupee', aliases: ['سريلانكي']),
  SougaCurrency('NPR', 'روبية نيبالية', 'रू', en: 'Nepalese Rupee', aliases: ['نيبالي']),
  SougaCurrency('KZT', 'تنغي كازاخستاني', '₸', en: 'Kazakhstani Tenge', aliases: ['tenge','كازاخي']),
  SougaCurrency('AZN', 'مانات أذربيجاني', '₼', en: 'Azerbaijani Manat', aliases: ['manat','اذربيجاني']),
  SougaCurrency('GEL', 'لاري جورجي', '₾', en: 'Georgian Lari', aliases: ['lari','جورجي']),
  SougaCurrency('ISK', 'كرونة آيسلندية', 'kr', en: 'Icelandic Krona', aliases: ['ايسلندي']),
];

/// ✅ تنسيق موحّد للمبالغ في كل التطبيق:
///  • فواصل آلاف:   15000   → 15,000
///  • بلا كسور صفرية: 49.00 → 49   (والكسر الحقيقي يبقى: 49.5 → 49.50)
/// (كان بعض الشاشات يعرض `toStringAsFixed(2)` وبطاقة المنتج `toStringAsFixed(0)`
///  فيُقرَّب 12.50 إلى 13 — وهذا يعرض سعراً غير صحيح.)
String formatMoney(num value) {
  final neg = value < 0;
  final a = value.abs().toDouble();
  final whole = (a - a.roundToDouble()).abs() < 0.005;
  final fixed = whole ? a.round().toString() : a.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final out = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  return neg ? '-$out' : out;
}
