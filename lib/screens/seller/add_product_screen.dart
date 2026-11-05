// lib/screens/seller/add_product_screen.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/imagekit_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/seo_rebuild_service.dart';
import '../../utils/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  قائمة العملات العالمية
// ─────────────────────────────────────────────────────────────────────────────
class _Currency {
  final String code;   // USD
  final String name;   // دولار أمريكي
  final String symbol; // $

  const _Currency(this.code, this.name, this.symbol);

  String get display => '$symbol $code — $name';
}

const List<_Currency> _kCurrencies = [
  // الخليج أولاً
  _Currency('SAR', 'ريال سعودي',      '﷼'),
  _Currency('AED', 'درهم إماراتي',    'د.إ'),
  _Currency('KWD', 'دينار كويتي',     'د.ك'),
  _Currency('BHD', 'دينار بحريني',    'د.ب'),
  _Currency('QAR', 'ريال قطري',       'ر.ق'),
  _Currency('OMR', 'ريال عُماني',     'ر.ع'),
  // عربية
  _Currency('EGP', 'جنيه مصري',       'ج.م'),
  _Currency('JOD', 'دينار أردني',     'د.أ'),
  _Currency('IQD', 'دينار عراقي',     'ع.د'),
  _Currency('SYP', 'ليرة سورية',      'ل.س'),
  _Currency('LBP', 'ليرة لبنانية',   'ل.ل'),
  _Currency('TND', 'دينار تونسي',     'د.ت'),
  _Currency('MAD', 'درهم مغربي',      'د.م'),
  _Currency('DZD', 'دينار جزائري',    'دج'),
  _Currency('LYD', 'دينار ليبي',      'ل.د'),
  _Currency('SDG', 'جنيه سوداني',     'ج.س'),
  _Currency('YER', 'ريال يمني',       'ر.ي'),
  // عالمية رئيسية
  _Currency('USD', 'دولار أمريكي',    '\$'),
  _Currency('EUR', 'يورو',            '€'),
  _Currency('GBP', 'جنيه إسترليني',  '£'),
  _Currency('JPY', 'ين ياباني',       '¥'),
  _Currency('CNY', 'يوان صيني',       '¥'),
  _Currency('CAD', 'دولار كندي',      'C\$'),
  _Currency('AUD', 'دولار أسترالي',   'A\$'),
  _Currency('CHF', 'فرنك سويسري',    'Fr'),
  _Currency('TRY', 'ليرة تركية',     '₺'),
  _Currency('INR', 'روبية هندية',    '₹'),
  _Currency('BRL', 'ريال برازيلي',   'R\$'),
  _Currency('MXN', 'بيزو مكسيكي',    '\$'),
  _Currency('RUB', 'روبل روسي',      '₽'),
  _Currency('KRW', 'وون كوري',       '₩'),
  _Currency('SGD', 'دولار سنغافوري', 'S\$'),
  _Currency('HKD', 'دولار هونغ كونغ','HK\$'),
  _Currency('SEK', 'كرونة سويدية',   'kr'),
  _Currency('NOK', 'كرونة نرويجية',  'kr'),
  _Currency('DKK', 'كرونة دانماركية','kr'),
  _Currency('PLN', 'زلوتي بولندي',   'zł'),
  _Currency('IDR', 'روبية إندونيسية','Rp'),
  _Currency('MYR', 'رينغيت ماليزي',  'RM'),
  _Currency('THB', 'بات تايلاندي',   '฿'),
  _Currency('PKR', 'روبية باكستانية','₨'),
  _Currency('NGN', 'نيرة نيجيرية',   '₦'),
  _Currency('ZAR', 'راند جنوب أفريقي','R'),
];

// ─────────────────────────────────────────────────────────────────────────────
class AddProductScreen extends StatefulWidget {
  final ProductModel? product;
  const AddProductScreen({super.key, this.product});
  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _originalPriceCtrl = TextEditingController(); // ✅ جديد — السعر قبل الخصم (اختياري)
  final _stockCtrl = TextEditingController();

  String _selectedCategory = 'electronics';
  _Currency _selectedCurrency = _kCurrencies[0]; // SAR افتراضي
  String _currencySearch = '';

  final List<String> _uploadedUrls = [];
  bool _isLoading        = false;
  bool _isUploadingImage = false;

  // ✅ تحسين الوصف بالذكاء الاصطناعي
  Timer? _descDebounceTimer;
  bool _showEnhanceButton = false;
  bool _isEnhancing       = false;

  final List<Map<String, String>> _categories = [
    {'id': 'electronics', 'name': 'إلكترونيات'},
    {'id': 'clothes',     'name': 'ملابس'},
    {'id': 'food',        'name': 'طعام'},
    {'id': 'home',        'name': 'منزل'},
    {'id': 'sports',      'name': 'رياضة'},
    {'id': 'books',       'name': 'كتب'},
    {'id': 'other',       'name': 'أخرى'},
    {'id': 'perfumes',    'name': 'عطور'},
    {'id': 'accessories', 'name': 'اكسسوارات'},
  ];

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameCtrl.text    = widget.product!.name;
      _descCtrl.text    = widget.product!.description;
      _priceCtrl.text   = widget.product!.price.toString();
      if (widget.product!.originalPrice != null) {
        _originalPriceCtrl.text = widget.product!.originalPrice!.toString();
      }
      _stockCtrl.text   = widget.product!.stock.toString();
      _selectedCategory = widget.product!.category;

      // استعادة العملة المحفوظة
      final savedCode = widget.product!.currencyCode;
      if (savedCode.isNotEmpty) {
        _selectedCurrency = _kCurrencies.firstWhere(
          (c) => c.code == savedCode,
          orElse: () => _kCurrencies[0],
        );
      }

      _uploadedUrls.addAll(widget.product!.images);
    }

    // ✅ يُضاف بعد تعبئة القيم الأولية حتى لا يُطلق الزر عند فتح شاشة التعديل
    _descCtrl.addListener(_onDescriptionChanged);
  }

  @override
  void dispose() {
    _descDebounceTimer?.cancel();
    _descCtrl.removeListener(_onDescriptionChanged);
    _nameCtrl.dispose(); _descCtrl.dispose();
    _priceCtrl.dispose(); _originalPriceCtrl.dispose(); _stockCtrl.dispose();
    super.dispose();
  }

  // ── مراقبة الكتابة في حقل الوصف (Debounce ثانيتان) ─────────────────────────
  void _onDescriptionChanged() {
    _descDebounceTimer?.cancel();
    if (_showEnhanceButton) {
      setState(() => _showEnhanceButton = false);
    }
    final text = _descCtrl.text.trim();
    if (text.length < 10) { return; }
    _descDebounceTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) { setState(() => _showEnhanceButton = true); }
    });
  }

  // ── تحسين الوصف بالذكاء الاصطناعي ───────────────────────────────────────────
  Future<void> _enhanceDescription() async {
    if (_isEnhancing) { return; }
    final rawText = _descCtrl.text.trim();
    if (rawText.length < 10) { return; }

    setState(() { _isEnhancing = true; });
    final colors = context.colors;

    final result = await AiAssistantService.enhanceDescription(
      productName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'منتج',
      category:    _selectedCategory,
      rawDescription: rawText,
      price:          _priceCtrl.text.trim(),
      currencySymbol: _selectedCurrency.symbol,
    );

    if (!mounted) { return; }

    if (result.isSuccess) {
      _descCtrl.removeListener(_onDescriptionChanged);
      _descCtrl.text = result.enhanced!;
      _descCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _descCtrl.text.length));
      _descCtrl.addListener(_onDescriptionChanged);

      setState(() {
        _isEnhancing        = false;
        _showEnhanceButton  = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.isFallback
            ? '✅ تم تحسين الوصف'
            : '✨ تم تحسين الوصف بالذكاء الاصطناعي'),
        backgroundColor: colors.success,
        duration: const Duration(seconds: 2),
      ));
    } else {
      setState(() { _isEnhancing = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ ${result.errorMessage ?? "تعذر تحسين الوصف"}'),
        backgroundColor: colors.error,
      ));
    }
  }

  // ── اختيار العملة ────────────────────────────────────────────────────────
  void _showCurrencyPicker() {
    setState(() => _currencySearch = '');
    final colors = context.colors;
    showModalBottomSheet(
      context:           context,
      isScrollControlled: true,
      useSafeArea:       true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final filtered = _currencySearch.isEmpty
              ? _kCurrencies
              : _kCurrencies.where((c) =>
                  c.code.toLowerCase().contains(_currencySearch.toLowerCase()) ||
                  c.name.contains(_currencySearch) ||
                  c.symbol.contains(_currencySearch)).toList();

          return DraggableScrollableSheet(
            expand:          false,
            initialChildSize: 0.7,
            maxChildSize:    0.92,
            builder: (_, sc) => Column(children: [
              // شريط السحب
              Center(child: Container(
                width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colors.border, borderRadius: BorderRadius.circular(2)),
              )),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('اختر العملة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              // حقل البحث
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => setModal(() => _currencySearch = v),
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText:  'ابحث (USD, ريال, \$...)',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense:   true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // القائمة
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  itemCount:  filtered.length,
                  itemBuilder: (_, i) {
                    final c        = filtered[i];
                    final isSelected = c.code == _selectedCurrency.code;
                    return ListTile(
                      dense: true,
                      leading: Text(c.symbol,
                          style: TextStyle(
                            fontSize:   18,
                            color:      isSelected
                                ? colors.primary : colors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold : FontWeight.normal,
                          )),
                      title: Text(c.name,
                          style: TextStyle(
                            color:      isSelected
                                ? colors.primary : colors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          )),
                      subtitle: Text(c.code,
                          style: TextStyle(
                              fontSize: 11, color: colors.textHint)),
                      trailing: isSelected
                          ? Icon(Icons.check_circle,
                              color: colors.primary, size: 18)
                          : null,
                      onTap: () {
                        setState(() => _selectedCurrency = c);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ── رفع الصورة ────────────────────────────────────────────────────────────
  Future<void> _pickAndUploadImage() async {
    final source = await showModalBottomSheet<bool>(
      context: context,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: Icon(Icons.photo_library_outlined, color: context.colors.primary),
          title:   const Text('من معرض الصور'),
          onTap:   () => Navigator.pop(context, false)),
        ListTile(
          leading: Icon(Icons.camera_alt_outlined, color: context.colors.primary),
          title:   const Text('من الكاميرا'),
          onTap:   () => Navigator.pop(context, true)),
      ])),
    );
    if (source == null || !mounted) { return; }

    final file = await ImageKitService.pickImage(fromCamera: source);
    if (file == null || !mounted) { return; }

    setState(() => _isUploadingImage = true);
    final errorColor = context.colors.error;
    final url = await ImageKitService.uploadImage(file, 'products');

    if (!mounted) { return; }
    if (url != null) {
      setState(() {
        _uploadedUrls.add(url);
        _isUploadingImage  = false;
      });
    } else {
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('❌ فشل رفع الصورة. تحقق من الاتصال'),
          backgroundColor: errorColor));
    }
  }

  // ── حفظ المنتج ────────────────────────────────────────────────────────────
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) { return; }
    setState(() => _isLoading = true);
    final colors = context.colors;
    try {
      final user = context.read<AuthProvider>().currentUser!;
      final priceVal = double.parse(_priceCtrl.text);
      final originalPriceText = _originalPriceCtrl.text.trim();
      final originalPriceVal = originalPriceText.isEmpty ? null : double.tryParse(originalPriceText);
      final data = {
        'name':          _nameCtrl.text.trim(),
        'description':   _descCtrl.text.trim(),
        'price':         priceVal,
        // ✅ يُحفَظ فقط إن كان رقماً صحيحاً وأكبر فعلياً من السعر الحالي —
        // وإلا يُحذف الحقل تماماً حتى لا تظهر شارة خصم وهمية بالخطأ.
        if (originalPriceVal != null && originalPriceVal > priceVal)
          'originalPrice': originalPriceVal
        else if (_isEditing)
          'originalPrice': FieldValue.delete(),
        'currencyCode':  _selectedCurrency.code,    // ← العملة المحددة
        'currencySymbol':_selectedCurrency.symbol,  // ← رمز العملة
        'stock':         int.parse(_stockCtrl.text),
        'category':      _selectedCategory,
        'images':        _uploadedUrls,
        'sellerId':      user.uid,
        'sellerName':       user.storeName.isNotEmpty ? user.storeName : user.name,
        'sellerLogo':       user.storeLogo,
        'storeDescription': user.storeDescription,
        'rating':        _isEditing ? widget.product!.rating : 0.0,
        'reviewCount':   _isEditing ? widget.product!.reviewCount : 0,
        'displayWeight': _isEditing ? widget.product!.displayWeight : 5,
        'createdAt':     _isEditing ? widget.product!.createdAt : DateTime.now(),
      };
      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('products').doc(widget.product!.id).update(data);

        // ✅ إعادة بناء صفحات SEO الثابتة في الخلفية بعد التعديل — بدون
        // انتظار المستخدم (يُنفَّذ الطلب الفعلي على السيرفر بعد نافذة
        // تجميع لتقليل عدد عمليات النشر عند تعديلات متتالية سريعة).
        unawaited(SeoRebuildService.triggerRebuild(reason: 'product_updated:${widget.product!.id}'));
      } else {
        final docRef = await FirebaseFirestore.instance.collection('products').add(data);

        // ✅ توليد 10 تقييمات تمهيدية ذكية في الخلفية — لا ننتظرها.
        unawaited(AiAssistantService.generateSeedReviews(productId: docRef.id));

        // ✅ إشعار Push تلقائي لكل المستخدمين المسجّلين بالمنتج الجديد —
        // لا ننتظره أيضاً، ولا يُظهر أي رسالة للبائع (عملية خلفية صامتة
        // بحتة؛ نجاحها أو فشلها لا يؤثر على تجربة نشر المنتج).
        unawaited(PushNotificationService.sendProductNotification(productId: docRef.id));

        // ✅ إعادة بناء صفحات SEO الثابتة في الخلفية بعد الإضافة.
        unawaited(SeoRebuildService.triggerRebuild(reason: 'product_created:${docRef.id}'));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEditing ? '✅ تم تعديل المنتج' : '✅ تم إضافة المنتج'),
            backgroundColor: colors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ حدث خطأ: $e'), backgroundColor: colors.error));
      }
    }
    if (mounted) { setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'تعديل المنتج' : 'إضافة منتج جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'اسم المنتج',
                  prefixIcon: Icon(Icons.inventory_2_outlined)),
              validator: (v) => v!.isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descCtrl,
              maxLines:   3,
              decoration: const InputDecoration(
                  labelText:          'وصف المنتج',
                  prefixIcon:         Icon(Icons.description_outlined),
                  alignLabelWithHint: true),
              validator: (v) => v!.isEmpty ? 'مطلوب' : null,
            ),

            // ✅ زر تحسين الوصف بالذكاء الاصطناعي
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: (_showEnhanceButton || _isEnhancing)
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: _isEnhancing ? null : _enhanceDescription,
                          icon: _isEnhancing
                              ? SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: colors.primary))
                              : const Icon(Icons.auto_awesome, size: 18),
                          label: Text(_isEnhancing
                              ? 'جاري التحسين...'
                              : 'حسّن الوصف بالذكاء الاصطناعي'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.primary,
                            side: BorderSide(color: colors.primary),
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // ── السعر + العملة ─────────────────────────────────────────────
            Row(children: [
              // السعر
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller:   _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                      labelText:  'السعر',
                      prefixIcon: Icon(Icons.attach_money)),
                  validator: (v) {
                    if (v!.isEmpty) { return 'مطلوب'; }
                    if (double.tryParse(v) == null) { return 'رقم غير صحيح'; }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              // العملة
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _showCurrencyPicker,
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border:       Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Text(_selectedCurrency.symbol,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_selectedCurrency.code,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis)),
                      Icon(Icons.keyboard_arrow_down_outlined,
                          size: 16, color: colors.textSecondary),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            // اسم العملة
            Text(_selectedCurrency.name,
                style: TextStyle(
                    fontSize: 11, color: colors.textSecondary)),
            const SizedBox(height: 16),

            // ✅ جديد — السعر قبل الخصم (اختياري) لتفعيل شارة الخصم في
            // بطاقة المنتج وقسم "عروض اليوم" بالصفحة الرئيسية.
            TextFormField(
              controller:   _originalPriceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                  labelText:  'السعر قبل الخصم (اختياري)',
                  hintText:   'اتركه فارغاً إن لم يكن هناك عرض',
                  prefixIcon: Icon(Icons.local_offer_outlined)),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final parsed = double.tryParse(v.trim());
                if (parsed == null) return 'رقم غير صحيح';
                final priceNow = double.tryParse(_priceCtrl.text) ?? 0;
                if (parsed <= priceNow) return 'يجب أن يكون أعلى من السعر الحالي';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // الكمية
            TextFormField(
              controller:   _stockCtrl,
              keyboardType: TextInputType.number,
              decoration:   const InputDecoration(
                  labelText:  'الكمية المتاحة',
                  prefixIcon: Icon(Icons.warehouse_outlined)),
              validator: (v) {
                if (v!.isEmpty) { return 'مطلوب'; }
                if (int.tryParse(v) == null) { return 'رقم غير صحيح'; }
                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value:      _selectedCategory,
              decoration: const InputDecoration(
                  labelText:  'التصنيف',
                  prefixIcon: Icon(Icons.category_outlined)),
              items: _categories.map((c) => DropdownMenuItem(
                  value: c['id'], child: Text(c['name']!))).toList(),
              onChanged: (val) {
                if (val != null) { setState(() => _selectedCategory = val); }
              },
            ),
            const SizedBox(height: 20),

            // ── صور المنتج ─────────────────────────────────────────────────
            Row(children: [
              const Text('صور المنتج',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                icon: _isUploadingImage
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(_isUploadingImage ? 'جاري الرفع...' : 'إضافة صورة'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding:     const EdgeInsets.symmetric(horizontal: 12)),
              ),
            ]),
            const SizedBox(height: 12),

            _uploadedUrls.isEmpty && !_isUploadingImage
                ? Container(
                    height:     120,
                    decoration: BoxDecoration(
                      color:        colors.border.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(color: colors.border)),
                    child: Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 40, color: colors.textHint),
                      const SizedBox(height: 8),
                      Text('اضغط "إضافة صورة" لرفع صور المنتج',
                          style: TextStyle(color: colors.textHint, fontSize: 13)),
                    ])),
                  )
                : SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          _uploadedUrls.length + (_isUploadingImage ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (_isUploadingImage && i == _uploadedUrls.length) {
                          return Container(
                            width:  120, height: 120,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(color: colors.border,
                                borderRadius: BorderRadius.circular(12)),
                            child: const Center(
                                child: CircularProgressIndicator()));
                        }
                        return Stack(children: [
                          Container(
                            width:  120, height: 120,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                  image: NetworkImage(ImageKitService
                                      .productUrl(_uploadedUrls[i])),
                                  fit: BoxFit.cover)),
                          ),
                          Positioned(
                            top: 4, right: 12,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _uploadedUrls.removeAt(i)),
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                    color: Colors.red, shape: BoxShape.circle),
                                child: Icon(Icons.close,
                                    color: Colors.white, size: 18)),
                            ),
                          ),
                        ]);
                      },
                    ),
                  ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: (_isLoading || _isUploadingImage) ? null : _saveProduct,
              child: _isLoading
                  ? const SizedBox(height: 22, width: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة المنتج'),
            ),
          ]),
        ),
      ),
    );
  }
}
