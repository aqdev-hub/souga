# Souga — Universal Product Engine — ملخص التسليم للمتابعة في محادثة جديدة

## التعليمات لبدء المحادثة الجديدة
1. أنشئ محادثة جديدة **داخل نفس الـ Project**.
2. ارفع هذا الملف + `souga_universal_product_engine_checkpoint.zip` المرفق معه.
3. الصق هذه الرسالة: *"أكمل مشروع Souga Universal Product Engine من نقطة التوقف
   الموضّحة في HANDOFF.md المرفق. اقرأه أولاً بالكامل قبل أي تعديل."*

---

## القرارات المعتمدة (لا تُعِد طرحها للنقاش)
- State Management: **Provider/ChangeNotifier**.
- Variants: **Subcollection** `products/{id}/variants` (لا Array).
- `video_player: ^2.14.0` موجود بالفعل في `pubspec.yaml`.
- الفئات الورقية افتراضية للبيع، مع Fallback مرن للفئات الرئيسية.
- Gallery role صريح (video/hero/item/color/size/other).
- **شاشة موحَّدة واحدة للإضافة/التعديل**: `ProductFormStepperScreen` — تُستخدَم من
  البائع (إضافة+تعديل) **ومن الأدمن** (تعديل أي منتج) معاً. فرق الصلاحيات يُحسَم
  بالكامل عبر `firestore.rules` (`isAdmin() || sellerId==uid`)، بلا أي فرع كود.
- **Variant-aware Cart/Order** (بموافقة صريحة — راجع التصميم المعتمد أدناه):
  مفتاح سطر السلة = `(productId, variantId)`، السعر Snapshot ثابت وقت الإضافة،
  والطلب يحمل نسخة مستقلة تماماً (لا مرجع حي) من التركيبة/السعر وقت الشراء.

## ✅ منتهٍ ومُتحقَّق منه (لا تُعِد بناءه)

| الطبقة | الملفات | ملاحظة |
|---|---|---|
| Models | `product_model.dart`، `category_model.dart`، `attribute_model.dart`، `product_variant_model.dart`، `gallery_item_model.dart`، `product_option_ref_model.dart` | كل حقل جديد اختياري افتراضي آمن |
| Repositories | `category_repository.dart`، `attribute_repository.dart`، `product_repository.dart`، `variant_repository.dart` | SKU Generator تحقّق رياضياً بـ Python قبل الترجمة |
| Firestore | `firestore.rules` (categories/attribute_definitions/variants) | — |
| بيانات | `category_schema_setup_screen.dart` + بطاقة في `admin_dashboard_screen.dart` | Idempotent |
| Gallery | `product_gallery_controller.dart`، `product_gallery_view.dart`، `product_gallery_thumbnail_bar.dart` | خوارزمية الحالة النشطة تحقّقت بـ 10 حالات Python |
| `product_detail_screen.dart` | ربط المعرض + **إصلاح باغ حرج** (imports ناقصة كانت ستمنع الترجمة) + Variant Selector + تفكيك كامل لـ Widgets مستقلة + قسم Specifications جديد + دمج مع السلة Variant-aware | ✅ راجع التفاصيل أدناه |
| إصلاح باغ | `product_model.dart` → `toMap()` | `sellerLogo`/`storeDescription` كانا يُفقَدان بصمت عند الحفظ عبر Repository |
| `AddEditProductController` | `lib/controllers/add_edit_product_controller.dart` | State management كامل لستّ خطوات شرطية — **اسم الملف/الكلاس لم يُغيَّر** (فقط الشاشة أُعيدت تسميتها) |
| `ProductFormStepperScreen` | `lib/screens/seller/product_form_stepper_screen.dart` (بعد إعادة تسمية من `AddEditProductStepperScreen`) | الشاشة الموحَّدة لإضافة/تعديل — مُوصَّلة الآن فعلياً |
| `lib/utils/currencies.dart` | جديد | مُستخرَج من `add_product_screen.dart` القديم |
| **الربط الفعلي الكامل** | `seller_products_screen.dart`، `admin_products_screen.dart` | ✅ راجع التفاصيل أدناه — **هذا تغيير سلوك حقيقي، ليس إضافياً فقط** |
| **Variant-aware Cart/Order** | `cart_model.dart`، `cart_provider.dart`، `order_model.dart`، `cart_screen.dart`، `checkout_screen.dart`، `orders_screen.dart`، `seller_orders_screen.dart` | ✅ راجع التصميم والتفاصيل أدناه |

### تفاصيل `product_detail_screen.dart`
- **Variant Selector**: `_VariantSelectorSection` + `_ColorSwatchChip` + `_TextOptionChip` — شرطي بالكامل حسب `hasVariants`، يُزامن المعرض عبر `jumpToOption`، يُطابق حياً ضد `VariantRepository.watchAll`.
- **تفكيك كامل**: `_ProductGalleryHeader`, `_StockBadge`, `_LikeShareRow`, `_DescriptionSection`, `_SpecificationsSection` (جديد كلياً — شرطي حسب `product.attributes`), `_QuantitySelector`, `_PurchaseButtonsRow` + دالة مشتركة `attributeDisplayLabel(key)`.
- **دمج السلة**: `_buildVariantLabelSnapshot()` يبني `Map<String,String>` بتسميات عربية جاهزة (وليس ids) من `_selectedVariant` + `product.optionSets`، يُمرَّر إلى `cart.addItem(...)` مع `unitPriceOverride: _effectivePrice`.

### تفاصيل `AddEditProductController` + `ProductFormStepperScreen`
خوارزمية "أي خطوات تظهر" (`computeVisibleSteps`) تحقّقت بـ 6 حالات Python:

| # | الخطوة | شرط الظهور |
|---|---|---|
| 0 | الفئة | دائماً |
| 1 | معلومات أساسية | دائماً |
| 2 | المواصفات الوصفية | خاصية `isVariant=false` واحدة على الأقل في الفئة |
| 3 | اختيار المتغيرات | خاصية `isVariant=true` واحدة على الأقل في الفئة |
| 4 | تركيبات SKU | البائع فعَّل "له خيارات متعددة" **و** اختار قيماً |
| 5 | المعرض والمراجعة | دائماً |

`save()`: يكتب المنتج أولاً (create/update عبر `ProductRepository`)، ثم فقط عند
`hasVariants` يبني SKU حقيقياً بمعرّف المنتج الفعلي (`VariantRepository.buildSku`)
ويكتب كل التركيبات دفعة واحدة (`upsertBatch`). تحقّق شامل قبل أي كتابة — لا حفظ جزئي.

توافق خلفي: `category` المسطّح القديم = جذر الفئة (`CategoryNode.parent` حتى الجذر)،
وليس الفئة الفرعية — تستمر شاشات الفلترة القديمة بالعمل بلا تعديل.

⚠️ لا يوجد رفع فيديو فعلي (`ImageKitService` صور فقط) — حقل الفيديو رابط يدوي مؤقتاً.

### الربط الفعلي الكامل (تغيير سلوك حقيقي — نُفِّذ بموافقتك الصريحة)
- `seller_products_screen.dart`: زر FAB "إضافة منتج" + أيقونة تعديل كل منتج → **كلاهما الآن يفتحان `ProductFormStepperScreen` مباشرة** (لم يعودا يفتحان `AddProductScreen` القديمة إطلاقاً).
- `admin_products_screen.dart`: أيقونة تعديل كل منتج → **تفتح `ProductFormStepperScreen(product: p)`** بدل BottomSheet المحدودة القديمة (اسم/وصف/صور/نسبة ظهور فقط). دالة `_UploadImageButton` وBottomSheet القديمة أُزيلتا (Dead Code).
- `add_product_screen.dart` **لم يُحذَف** — أصبح ملفاً غير مرجعي (orphaned) من أي مكان، مُبقىً عليه فعلياً كخيار تراجع سريع فقط. **راجع تحذير SDK أدناه قبل حذفه نهائياً.**

### التصميم المعتمد لـ Variant-aware Cart/Order (نُفِّذ بالكامل)

**نموذج البيانات:**
```dart
// CartItem — lib/models/cart_model.dart
final String? variantId;                        // = ProductVariantModel.id، null لمنتج تقليدي
final Map<String, String>? variantOptionValues;  // Snapshot تسميات عربية: {'اللون':'أحمر'}
final double price;                              // ✅ يعمل بالفعل كـ Unit-Price Snapshot ثابت وقت الإضافة

// OrderItem — lib/models/order_model.dart
final String? variantId;
final Map<String, String>? variantOptions;       // نسخة مستقلة تماماً، تُكتَب مرة عند checkout ولا تُقرأ حياً بعدها
```

**CartProvider**: كل الدوال (`addItem/updateQuantity/removeItem/isInCart/getQuantity`)
تطابق الآن بـ `(productId, variantId)` بدل `productId` فقط، عبر `_indexOf()` داخلي.
`variantId` اختياري افتراضي `null` في كل توقيع — أي استدعاء قديم يعمل حرفياً كالسابق.

**مسار البيانات الكامل**:
```
Product.optionSets[key] → ProductOptionValueRef{valueId,label}
        ↓
ProductDetailScreen._selectedVariant (ProductVariantModel{id,optionValues,price,stock})
        ↓ عند "إضافة للسلة": _buildVariantLabelSnapshot() يحوّل ids→labels عربية
CartProvider.addItem(variantId, variantOptionValues, unitPriceOverride)
        ↓ Snapshot يُكتَب فوراً في CartItem.price — لا رابط حي بعدها
CartScreen: عرض تجميلي فقط لـ variantOptionValues
        ↓
CheckoutScreen: نسخ مباشر (productId/variantId/variantOptions/price) من CartItem → OrderItem
        ↓
Firestore orders/{id}: مستقل 100% للأبد — لا يتأثر بأي تعديل لاحق على product/variant
```
**عُرِض أيضاً** في `orders_screen.dart` (عميل) و`seller_orders_screen.dart` (بائع) — سطر
صغير تحت كل منتج بخيارات التركيبة المشتراة، حتى تكتمل السلسلة فعلياً وليس فقط في البيانات.

**جاهزية مستقبلية لمخزون Variant** (بلا تنفيذ الآن، بموافقتك الصريحة على التأجيل):
`variantId` موجود في كل طبقة — أي تحقق مستقبلي وقت `checkout` (مطابقة `ProductVariantModel.stock`)
يُضاف لاحقاً بلا أي تعديل بنيوي إضافي على النموذج الحالي.

## ⚠️ تنبيه هام — لم يُختبَر على Flutter SDK فعلياً
كل الكود في هذه الجلسات **لم يُشغَّل فعلياً** (لا توجد بيئة Flutter SDK هنا). التحقق
تم حصراً عبر: (أ) فحص توازن الأقواس ببرنامج مخصّص يتجاهل strings/comments على **كل**
ملف جديد/مُعدَّل، (ب) مطابقة كل توقيع API مستخدَم يدوياً مقابل الملفات الفعلية،
(ج) تتبّع كل استدعاء دالة عبر طبقات الملفات (Controller → Repository → Model) للتأكد
من تطابق الأسماء/الأنواع/الحقول. **يُنصَح بشدة بتشغيل `flutter analyze` ثم `flutter run`
فعلياً — خصوصاً تدفّق: فتح `ProductFormStepperScreen` من كلا المسارين (بائع/أدمن)،
حفظ منتج بمتغيرات، إضافته للسلة، إتمام الشراء — قبل حذف `add_product_screen.dart`
نهائياً أو اعتبار أي من هذا "منتهياً للإنتاج".**

## ⏳ المتبقي (بالترتيب)

1. ~~تفكيك `product_detail_screen.dart`~~ ✅ منجز
2. ~~`AddEditProductController` + `ProductFormStepperScreen`~~ ✅ منجز
3. ~~Variant-aware Cart/Order~~ ✅ منجز
4. ~~الربط الفعلي (بائع + أدمن)~~ ✅ منجز
5. ~~**إعادة تصميم كاملة لواجهة `ProductFormStepperScreen`**~~ ✅ **منجز بالكامل هذه الجلسة** — راجع التفاصيل أدناه.
6. **اختبار فعلي على Flutter SDK حقيقي** — لم يحدث بعد، خطوتك أنت. **الأهم الآن** بعد إعادة التصميم الكبيرة.
7. بعد نجاح الاختبار: حذف `add_product_screen.dart` نهائياً.
8. اختياري مستقبلي: تحقق فعلي من مخزون الـ Variant وقت `checkout`.

### تفاصيل إعادة التصميم الكاملة (منجز هذه الجلسة)
بعد ملاحظة مباشرة أن تصميم `ProductFormStepperScreen` السابق (باستخدام Flutter
`Stepper` الافتراضي) "فاشل وغير مطابق"، أعدت بناء الواجهة بالكامل لتُطابق تصميماً
مرجعياً معتمداً — **نسخاً حرفياً في الترتيب والمسافات والأزرار**، مع الحفاظ على
هوية سوجا (الأحمر القرمزي/الذهبي عبر `context.colors`، لا ألوان مكتوبة يدوياً).

**Stepper أفقي مخصَّص بالكامل** (`_StepHeaderBar`) — استبدل Flutter's `Stepper`
تماماً: دوائر مرقّمة متصلة بخطوط، دائرة حمراء ممتلئة للخطوة النشطة، علامة ✓
بيضاء للخطوات المكتملة، رمادي للقادمة، تسمية تحت كل دائرة.

**تجميع 6 "خطوات بيانات" (Controller) إلى 4 "خطوات مرئية" (تصميم)**:

| # مرئي | العنوان | يحوي |
|---|---|---|
| 0 | المعلومات الأساسية | **الصورة الرئيسية (إجبارية، داخل نفس البطاقة لا قسم منفصل)** + اسم المنتج * + الوصف المختصر * + الوصف التفصيلي * + الفئة الرئيسية * (قائمة منسدلة) + الفئة الفرعية * (تظهر فقط إن كان للفئة الرئيسية أبناء) + السعر/العملة * + السعر قبل الخصم (اختياري) + الكمية (فقط إن !hasVariants) + حالة المنتج (جديد/مستعمل) |
| 1 | الخصائص | خصائص المتغيرات أولاً (لون بدوائر + "لون آخر"، ثم الباقي بشرائح + "[الاسم] آخر") ← خصائص وصفية (خامة/معالج/بطارية...، والعلامة التجارية بعرض بحث خاص "ابحث/أو اكتبها") ← "+ إضافة خاصية أخرى" (حرة) ← "خيارات متقدمة" (مطوي افتراضياً) لتخصيص سعر/مخزون كل تركيبة يدوياً |
| 2 | الصور | شبكة صور (**زر الإضافة أولاً** ثم الصور، الرئيسية بشارة "رئيسية") + فيديو (رابط، **مربّع قابل للضغط** بدل حقل نص عادي) + صور حسب اللون (اختياري) + نصائح لصور أفضل |
| 3 | النشر | بطاقة معاينة + صفوف مراجعة **بترتيب ثابت مطابق تماماً**: الوصف، اللون، المقاس، الخامة، العلامة التجارية، السعر، الكمية، الحالة، الفئة + مربع "قبل النشر" + "حفظ كمسودة"(stub) + "نشر المنتج"/"حفظ التعديلات" |

**قرار معماري صريح** (أجاب على سؤال عبدالقدوس): الخصائص تُعرَّف على مستوى **الفئة
الفرعية (Leaf)** مع وراثة من الفئة الرئيسية (`CategoryNode.inheritedAttributeIds` —
كان موجوداً بالفعل، هذا هو التصميم الاحترافي الصحيح، مطبَّق فعلياً الآن في
قائمتَي الفئة الرئيسية/الفرعية بخطوة "المعلومات الأساسية").

**ميزات جديدة أُضيفت لتحقيق التطابق الكامل مع المرجع:**
- `+ لون آخر` / `+ [أي خاصية متغيّرة] آخر`: يفتح حواراً لإضافة قيمة خاصة **بهذا
  المنتج تحديداً** (غير موجودة في `attribute_definitions` العامة) — `AddEditProductController.addCustomOptionValue()`
  + `optionValuesFor()`/`resolveOptionValue()` يدمجان الرسمية والمخصَّصة بلا تفريق
  في كل مكان (SKU/optionSets/المعاينة/التعديل لاحقاً — بما فيه استرجاعها بشكل
  صحيح عند فتح منتج قديم للتعديل عبر `_hydrateFromExistingProduct`).
- `+ [خاصية وصفية] أخرى` (خامة مثلاً): يضيف قيمة نصية حرة لقائمة الشرائح.
- **العلامة التجارية**: خاصية جديدة كلياً (`brand`) أُضيفت لـ `category_schema_setup_screen.dart`
  بعرض بحث+اقتراحات+كتابة يدوية مطابق للمرجع تماماً — مرتبطة بالفئات المناسبة
  (ملابس رجالي/نسائي، هواتف، سماعات، إكسسوارات، عناية وجمال، رياضة).
- **`shortDescription` + `condition`** (جديد/مستعمل): حقلان جديدان في `ProductModel`
  (اختياريان، توافق خلفي كامل) لمطابقة حقلَي "الوصف المختصر *" و"حالة المنتج"
  في المرجع.
- **ترقية آلية Idempotent** في `category_schema_setup_screen.dart`: كانت "تتخطى
  تماماً" أي فئة موجودة مسبقاً، فلن تصل خاصية `brand` الجديدة لبيئة مُشغَّلة
  بالفعل! أصبحت الآن **تدمج** (Union) أي `attributeIds` جديدة في الفئات
  الموجودة دون حذف أي تخصيص يدوي سابق — تشغيل الشاشة مجدداً على بيئة قديمة
  يُحدِّث الفئات المتأثرة تلقائياً.

**⚠️ محدودية موثَّقة (بقرار واعٍ، ذُكرت صراحة في الكود):**
- "حفظ كمسودة" **زر واجهة فقط حالياً بلا وظيفة حفظ فعلية** — تُظهر Snackbar
  "قادمة قريباً" بدل الكتابة الفعلية. تنفيذها الحقيقي يتطلب حقل `status` على
  `ProductModel` + تصفية **كل** استعلامات المنتجات العامة (الرئيسية/البحث) لإخفاء
  المسودات عن المشترين — تغيير أوسع نطاقاً مؤجَّل عمداً لتفادي خطر تسريب منتج
  غير مكتمل للمتجر قبل اختبار هذا المسار بعناية. **يحتاج نقاشاً منفصلاً إن أردت
  تفعيله فعلياً.**
- رفع الفيديو مباشرة لا يزال غير مدعوم (لا يوجد endpoint) — المربّع الجديد
  يفتح حوار إدخال رابط جاهز فقط، لكنه **مصمَّم بصرياً** كصندوق قابل للضغط
  مطابق للمرجع (وليس حقل نص عادي كما كان سابقاً).
- روابط "شروط الاستخدام"/"سياسة بيع المنتجات" في مربع "قبل النشر" **نص ثابت
  غير قابل للنقر حالياً** — يمكن ربطهما بنفس حوارات `_showPolicy` الموجودة
  أصلاً في `profile_screen.dart` في جلسة قادمة إن رغبت.

## ⚠️ ملاحظة تقنية مهمة لأي محادثة قادمة
بيئة التنفيذ قابلة لإعادة التشغيل غير المتوقعة أثناء الجلسات الطويلة، ما قد يُفقِد
ملفات العمل المؤقتة. **الحل المتّبع بنجاح:** تغليف كل تسليم مكتمل فوراً في ZIP بعد
كل مرحلة صغيرة بدل تأجيل التجميع للنهاية — واصل بنفس المنهجية.
