// lib/utils/currencies.dart
//
// ✅ جديد — مصدر واحد موحّد لقائمة العملات العالمية، مُستخرَجة من
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

  const SougaCurrency(this.code, this.name, this.symbol);

  String get display => '$symbol $code — $name';
}

const List<SougaCurrency> kSougaCurrencies = [
  // الخليج أولاً
  SougaCurrency('SAR', 'ريال سعودي',      '﷼'),
  SougaCurrency('AED', 'درهم إماراتي',    'د.إ'),
  SougaCurrency('KWD', 'دينار كويتي',     'د.ك'),
  SougaCurrency('BHD', 'دينار بحريني',    'د.ب'),
  SougaCurrency('QAR', 'ريال قطري',       'ر.ق'),
  SougaCurrency('OMR', 'ريال عُماني',     'ر.ع'),
  // عربية
  SougaCurrency('EGP', 'جنيه مصري',       'ج.م'),
  SougaCurrency('JOD', 'دينار أردني',     'د.أ'),
  SougaCurrency('IQD', 'دينار عراقي',     'ع.د'),
  SougaCurrency('SYP', 'ليرة سورية',      'ل.س'),
  SougaCurrency('LBP', 'ليرة لبنانية',   'ل.ل'),
  SougaCurrency('TND', 'دينار تونسي',     'د.ت'),
  SougaCurrency('MAD', 'درهم مغربي',      'د.م'),
  SougaCurrency('DZD', 'دينار جزائري',    'دج'),
  SougaCurrency('LYD', 'دينار ليبي',      'ل.د'),
  SougaCurrency('SDG', 'جنيه سوداني',     'ج.س'),
  SougaCurrency('YER', 'ريال يمني',       'ر.ي'),
  // عالمية رئيسية
  SougaCurrency('USD', 'دولار أمريكي',    '\$'),
  SougaCurrency('EUR', 'يورو',            '€'),
  SougaCurrency('GBP', 'جنيه إسترليني',  '£'),
  SougaCurrency('JPY', 'ين ياباني',       '¥'),
  SougaCurrency('CNY', 'يوان صيني',       '¥'),
  SougaCurrency('CAD', 'دولار كندي',      'C\$'),
  SougaCurrency('AUD', 'دولار أسترالي',   'A\$'),
  SougaCurrency('CHF', 'فرنك سويسري',    'Fr'),
  SougaCurrency('TRY', 'ليرة تركية',     '₺'),
  SougaCurrency('INR', 'روبية هندية',    '₹'),
  SougaCurrency('BRL', 'ريال برازيلي',   'R\$'),
  SougaCurrency('MXN', 'بيزو مكسيكي',    '\$'),
  SougaCurrency('RUB', 'روبل روسي',      '₽'),
  SougaCurrency('KRW', 'وون كوري',       '₩'),
  SougaCurrency('SGD', 'دولار سنغافوري', 'S\$'),
  SougaCurrency('HKD', 'دولار هونغ كونغ','HK\$'),
  SougaCurrency('SEK', 'كرونة سويدية',   'kr'),
  SougaCurrency('NOK', 'كرونة نرويجية',  'kr'),
  SougaCurrency('DKK', 'كرونة دانماركية','kr'),
  SougaCurrency('PLN', 'زلوتي بولندي',   'zł'),
  SougaCurrency('IDR', 'روبية إندونيسية','Rp'),
  SougaCurrency('MYR', 'رينغيت ماليزي',  'RM'),
  SougaCurrency('THB', 'بات تايلاندي',   '฿'),
  SougaCurrency('PKR', 'روبية باكستانية','₨'),
  SougaCurrency('NGN', 'نيرة نيجيرية',   '₦'),
  SougaCurrency('ZAR', 'راند جنوب أفريقي','R'),
];
