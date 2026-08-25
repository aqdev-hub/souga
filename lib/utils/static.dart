// lib/utils/static.dart
//
// ✅ نفس الاسم والبنية (قائمة onBoardingList من OnBoardingModel) كما وردا
// في الرفعة — نُقل لمجلد lib/utils/. المحتوى فقط تغيّر: النصوص الإنجليزية
// الوهمية استُبدلت بمحتوى عربي حقيقي مطابق لكل صورة من الصور الأربع التي
// أرسلتها، وبأسلوب يعكس هوية سوجا الفعلية (سوق محلي، دفع عند الاستلام،
// بدون عمولة، توصيل مباشر من البائع للمشتري).
import '../models/onboarding_model.dart';
import 'imageasset.dart';

final List<OnBoardingModel> onBoardingList = [
  // صورة 1: واجهة متجر + بحث + تقييم بالنجوم + بطاقة خصم
  const OnBoardingModel(
    title: 'تصفّح واكتشف منتجاتك',
    image: ImageAsset.onBoardingImageOne,
    body: 'آلاف المنتجات من بائعين محليين في تصنيفات متنوعة، '
        'مع تقييمات حقيقية تساعدك على اختيار الأنسب لك',
  ),
  // صورة 2: محفظة + بطاقة + نقود + رمز QR
  const OnBoardingModel(
    title: 'الدفع عند الاستلام بأمان',
    image: ImageAsset.onBoardingImageTwo,
    body: 'اطلب بثقة وادفع نقداً عند وصول طلبك إلى باب منزلك، '
        'بدون أي تعقيد وبدون عمولة خلال الفترة التجريبية',
  ),
  // صورة 3: خريطة + عدسة بحث فوق موقع
  const OnBoardingModel(
    title: 'اكتشف متاجر بالقرب منك',
    image: ImageAsset.onBoardingImageThree,
    body: 'تصفّح مواقع المتاجر المحلية على الخريطة، '
        'واطلب مباشرة من أقرب بائع في منطقتك',
  ),
  // صورة 4: عامل توصيل يحمل صناديق + شاحنة + مبانٍ المدينة
  const OnBoardingModel(
    title: 'توصيل سريع وموثوق',
    image: ImageAsset.onBoardingImageFour,
    body: 'فريق توصيل يوصل طلبك أينما كنت داخل مدينتك، '
        'مباشرة من البائع إليك بسرعة وأمان',
  ),
];
