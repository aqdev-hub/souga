// lib/screens/seller/product_form_stepper_screen.dart
//
// ✅ إعادة تصميم كاملة — نسخة مطابقة للتصميم المرجعي المعتمد (Stepper أفقي
// مخصّص بأربع خطوات: المعلومات الأساسية / الخصائص / الصور / النشر)، مع
// الحفاظ الكامل على هوية سوجا (الأحمر القرمزي/الذهبي عبر context.colors،
// وكل خصائص AppTheme المطبَّقة تلقائياً على الحقول والأزرار).
//
// ⚠️ هذا استبدال بصري كامل للنسخة السابقة من هذا الملف — لم يعُد يستخدم
// Flutter's Stepper widget (كان يُنتج شكلاً افتراضياً غير مقبول بصرياً حسب
// الملاحظة المباشرة). كل القرارات البنيوية (أي خصائص تظهر، توليد SKU،
// بناء المعرض...) لا تزال بالكامل في AddEditProductController — هذا الملف
// طبقة عرض بحتة فقط.
//
// تجميع 6 "خطوات بيانات" منطقية (Controller) إلى 4 "خطوات مرئية" (تصميم):
//   مرئية 0 "المعلومات الأساسية" = بيانات[الفئة + معلومات أساسية]
//   مرئية 1 "الخصائص"           = بيانات[مواصفات + اختيار متغيرات (+تركيبات اختيارية متقدمة)]
//   مرئية 2 "الصور"              = بيانات[معرض/صور فقط من خطوة الأخيرة]
//   مرئية 3 "النشر"              = بيانات[مراجعة ونشر من نفس الخطوة الأخيرة]

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/add_edit_product_controller.dart';
import '../../models/attribute_model.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/imagekit_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/currencies.dart';

const List<String> _kVisualStepLabels = ['المعلومات الأساسية', 'الخصائص', 'الصور', 'النشر'];

class ProductFormStepperScreen extends StatefulWidget {
  final ProductModel? product; // null = إضافة منتج جديد
  const ProductFormStepperScreen({super.key, this.product});

  @override
  State<ProductFormStepperScreen> createState() => _ProductFormStepperScreenState();
}

class _ProductFormStepperScreenState extends State<ProductFormStepperScreen> {
  late final AddEditProductController _controller;
  bool _variantsHydrated = false;
  int _visualStep = 0; // 0..3

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser!;
    _controller = AddEditProductController(
      sellerId: widget.product?.sellerId ?? user.uid,
      sellerName: user.storeName.isNotEmpty ? user.storeName : user.name,
      sellerLogo: user.storeLogo,
      storeDescription: user.storeDescription,
      existingProduct: widget.product,
    );
    _controller.addListener(_maybeHydrateVariants);
  }

  Future<void> _maybeHydrateVariants() async {
    if (_variantsHydrated) return;
    if (_controller.loadingCategories || _controller.loadingAttributes) return;
    if (widget.product == null || !_controller.hasVariants) return;
    _variantsHydrated = true;
    try {
      final real = await _controller.variantRepo.fetchAll(widget.product!.id);
      if (mounted) _controller.hydrateVariantDrafts(real);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.removeListener(_maybeHydrateVariants);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload(void Function(String url) onUploaded) async {
    final file = await ImageKitService.pickImage(fromCamera: false);
    if (file == null || !mounted) return;
    final colors = context.colors;
    setState(() => _controller.uploadingImage = true);
    final url = await ImageKitService.uploadImage(file, 'products');
    if (!mounted) return;
    setState(() => _controller.uploadingImage = false);
    if (url != null) {
      onUploaded(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('❌ فشل رفع الصورة. تحقق من الاتصال'),
        backgroundColor: colors.error,
      ));
    }
  }

  /// ✅ يُحوِّل الخطوة المرئية الحالية إلى معرّفات خطوات البيانات المطلوب
  /// التحقق منها قبل الانتقال — راجع الشرح أعلى الملف لخريطة التجميع.
  List<int> _dataStepsFor(int visualStep) {
    switch (visualStep) {
      case 0:
        return [AddEditProductController.stepCategory, AddEditProductController.stepBasicInfo];
      case 1:
        return [
          AddEditProductController.stepVariantSelection,
          AddEditProductController.stepVariantCombinations,
        ];
      case 2:
        return [AddEditProductController.stepGalleryReview];
      default:
        return const [];
    }
  }

  Future<void> _handleNext() async {
    for (final stepId in _dataStepsFor(_visualStep)) {
      final error = _controller.validateStep(stepId);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error), backgroundColor: context.colors.error,
        ));
        return;
      }
    }
    if (_visualStep == _kVisualStepLabels.length - 1) {
      await _submit();
    } else {
      setState(() => _visualStep++);
    }
  }

  void _handlePrevious() {
    if (_visualStep > 0) setState(() => _visualStep--);
  }

  void _saveDraftStub() {
    // ⚠️ ميزة "المسودات" غير مُنفَّذة بعد فعلياً (تتطلب حقل status على
    // ProductModel + تصفية كل استعلامات المنتجات العامة لإخفاء المسودات
    // عن المشترين — تغيير أوسع يمسّ شاشات متعددة، مؤجَّل عمداً لتفادي خطر
    // تسريب منتج غير مكتمل للمتجر قبل التحقق الكامل من هذا المسار). الزر
    // موجود بصرياً مطابقةً للتصميم المعتمد، لكنه لا يكتب شيئاً حالياً.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('ميزة حفظ المسودات قادمة قريباً'),
    ));
  }

  Future<void> _submit() async {
    final colors = context.colors;
    final success = await _controller.save();
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_controller.isEditing ? '✅ تم حفظ التعديلات' : '✅ تم نشر المنتج'),
        backgroundColor: colors.success,
      ));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_controller.saveError ?? 'حدث خطأ غير متوقع'),
        backgroundColor: colors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(_controller.isEditing ? 'تعديل المنتج' : 'إضافة منتج'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.loadingCategories) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.categoriesError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_controller.categoriesError!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _controller.retryLoadCategories,
                    child: const Text('إعادة المحاولة'),
                  ),
                ]),
              ),
            );
          }

          return Column(children: [
            _StepHeaderBar(currentIndex: _visualStep, labels: _kVisualStepLabels),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: _buildVisualStepContent(),
              ),
            ),
            _BottomActionBar(
              visualStep: _visualStep,
              totalSteps: _kVisualStepLabels.length,
              saving: _controller.saving,
              isEditing: _controller.isEditing,
              onPrevious: _handlePrevious,
              onNext: _handleNext,
              onSaveDraft: _saveDraftStub,
            ),
          ]);
        },
      ),
    );
  }

  Widget _buildVisualStepContent() {
    switch (_visualStep) {
      case 0:
        return _BasicInfoStep(controller: _controller, onPickImage: _pickAndUpload);
      case 1:
        return _AttributesStep(controller: _controller);
      case 2:
        return _GalleryStep(controller: _controller, onPickImage: _pickAndUpload);
      default:
        return _ReviewStep(controller: _controller);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ✅ شريط الخطوات الأفقي المخصّص — دوائر مرقّمة متصلة بخطوط، مطابق
//  للتصميم المعتمد تماماً، بألوان هوية سوجا (context.colors.primary).
// ═══════════════════════════════════════════════════════════════════════════
class _StepHeaderBar extends StatelessWidget {
  final int currentIndex;
  final List<String> labels;
  const _StepHeaderBar({required this.currentIndex, required this.labels});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final segmentIndex = (i - 1) ~/ 2;
            final done = segmentIndex < currentIndex;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 22),
                color: done ? colors.primary : colors.border,
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final isDone = stepIndex < currentIndex;
          final isActive = stepIndex == currentIndex;
          final circleColor = (isDone || isActive) ? colors.primary : colors.border;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(shape: BoxShape.circle, color: circleColor),
              alignment: Alignment.center,
              child: isDone
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : Text('${stepIndex + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : colors.textSecondary,
                        fontWeight: FontWeight.bold, fontSize: 13,
                      )),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 70,
              child: Text(
                labels[stepIndex],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isActive ? colors.primary : colors.textHint,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ✅ شريط الأزرار السفلي الثابت — "السابق" + "التالي"/"نشر" + "حفظ كمسودة"
// ═══════════════════════════════════════════════════════════════════════════
class _BottomActionBar extends StatelessWidget {
  final int visualStep;
  final int totalSteps;
  final bool saving;
  final bool isEditing;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSaveDraft;

  const _BottomActionBar({
    required this.visualStep,
    required this.totalSteps,
    required this.saving,
    required this.isEditing,
    required this.onPrevious,
    required this.onNext,
    required this.onSaveDraft,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLast = visualStep == totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ✅ إصلاح باغ: الأزرار الثلاثة (السابق + حفظ كمسودة + نشر) كانت
          // مكدَّسة في Row واحد ضيّق تسبَّب في التواء نص "حفظ كمسودة" لثلاثة
          // أسطر عمودية (مؤكَّد بصورة من المستخدم). الحل: زر النشر الأساسي
          // بعرض كامل في الأعلى (يستحق أكبر مساحة لأنه الفعل الأهم)، وصفّ
          // ثانوي للسابق/حفظ كمسودة تحته بعرضين متساويين.
          if (isLast)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: saving ? null : onNext,
                icon: saving
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(saving ? 'جاري الحفظ...' : (isEditing ? 'حفظ التعديلات' : 'نشر المنتج')),
              ),
            ),
          if (isLast) const SizedBox(height: 10),
          Row(children: [
            if (visualStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onPrevious,
                  child: const Text('السابق'),
                ),
              ),
            if (visualStep > 0 && isLast) const SizedBox(width: 12),
            if (isLast)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : onSaveDraft,
                  icon: const Icon(Icons.bookmark_border_rounded, size: 18),
                  label: const Text('حفظ كمسودة'),
                ),
              ),
            if (!isLast) ...[
              if (visualStep > 0) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: saving ? null : onNext,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('التالي'),
                ),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  عنصر بطاقة قسم موحَّد (عنوان + محتوى) — يُستخدَم في كل الخطوات لضمان
//  اتساق بصري كامل (حواف دائرية، ظل خفيف، عنوان بخط بارز).
// ═══════════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(
              color: colors.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary)),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

/// حقل مطلوب بعلامة النجمة الحمراء (مطابقة التصميم المعتمد)
Widget _requiredLabel(BuildContext context, String text) {
  return RichText(text: TextSpan(children: [
    TextSpan(text: text, style: TextStyle(color: context.colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
    TextSpan(text: ' *', style: TextStyle(color: context.colors.error, fontSize: 13, fontWeight: FontWeight.bold)),
  ]));
}

// ═══════════════════════════════════════════════════════════════════════════
//  خطوة مرئية 0 — المعلومات الأساسية
// ═══════════════════════════════════════════════════════════════════════════
class _BasicInfoStep extends StatefulWidget {
  final AddEditProductController controller;
  final Future<void> Function(void Function(String url) onUploaded) onPickImage;
  const _BasicInfoStep({required this.controller, required this.onPickImage});

  static List<CategoryNode> _currentSubOptions(AddEditProductController controller) {
    final selected = controller.selectedCategory;
    if (selected == null) return const [];
    // إيجاد الجذر الحالي لمعرفة إن كان له أبناء (فئات فرعية) لعرضها.
    var root = selected;
    while (root.parent != null) {
      root = root.parent!;
    }
    return root.children;
  }

  @override
  State<_BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends State<_BasicInfoStep> {
  AddEditProductController get controller => widget.controller;

  // ✅ إعادة تفعيل ميزة "تحسين الوصف بالذكاء الاصطناعي" — تُظهر زر التحسين
  // بعد 2 ثانية من توقّف البائع عن الكتابة (Debounce)، بنفس سلوك الشاشة
  // القديمة add_product_screen.dart تماماً.
  Timer? _descDebounceTimer;
  bool _showEnhanceButton = false;

  @override
  void initState() {
    super.initState();
    controller.descCtrl.addListener(_onDescriptionChanged);
  }

  @override
  void dispose() {
    _descDebounceTimer?.cancel();
    controller.descCtrl.removeListener(_onDescriptionChanged);
    super.dispose();
  }

  void _onDescriptionChanged() {
    _descDebounceTimer?.cancel();
    if (_showEnhanceButton) setState(() => _showEnhanceButton = false);
    final text = controller.descCtrl.text.trim();
    if (text.length < 10) return;
    _descDebounceTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showEnhanceButton = true);
    });
  }

  Future<void> _enhanceDescription() async {
    final colors = context.colors;
    final rootId = controller.selectedCategory != null
        ? AddEditProductController.rootCategoryId(controller.selectedCategory!)
        : '';
    await controller.enhanceDescription(category: rootId, priceText: controller.priceCtrl.text.trim());
    if (!mounted) return;
    if (controller.descriptionEnhanceError == null) {
      setState(() => _showEnhanceButton = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('✨ تم تحسين الوصف بالذكاء الاصطناعي'),
        backgroundColor: colors.success,
        duration: const Duration(seconds: 2),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ ${controller.descriptionEnhanceError}'),
        backgroundColor: colors.error,
      ));
    }
  }

  void _showCurrencyPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 420,
          child: ListView.builder(
            itemCount: kSougaCurrencies.length,
            itemBuilder: (_, i) {
              final c = kSougaCurrencies[i];
              return ListTile(
                leading: Text(c.symbol, style: const TextStyle(fontSize: 16)),
                title: Text(c.name),
                subtitle: Text(c.code),
                onTap: () { controller.setCurrency(c); Navigator.pop(ctx); },
              );
            },
          ),
        ),
      ),
    );
  }

  // ✅ جديد — "+ إضافة فئة فرعية أخرى": يفتح حواراً لإدخال اسم فئة فرعية
  // مقترَحة غير موجودة رسمياً بعد (نصّي بحت، لا يُنشئ فئة حقيقية).
  void _showAddCustomSubcategoryDialog(BuildContext context) {
    final textCtrl = TextEditingController(text: controller.customSubcategoryLabel ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة فئة فرعية أخرى'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'مثال: إكسسوارات هواتف مطوية'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              controller.setCustomSubcategory(textCtrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── المعلومات الأساسية (تتضمّن الصورة الرئيسية في الأعلى، مطابقةً
      // للتصميم المعتمد — لا قسم منفصل للصورة) ────────────────────────
      _SectionCard(
        title: 'المعلومات الأساسية',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: GestureDetector(
              onTap: controller.uploadingImage ? null : () => widget.onPickImage(controller.setHeroUrl),
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                  image: controller.heroUrl != null
                      ? DecorationImage(image: NetworkImage(ImageKitService.productUrl(controller.heroUrl!)), fit: BoxFit.cover)
                      : null,
                ),
                child: controller.uploadingImage
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : (controller.heroUrl == null
                        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.camera_alt_outlined, color: colors.textHint, size: 28),
                            const SizedBox(height: 6),
                            Text('أضف صورة رئيسية', style: TextStyle(fontSize: 11, color: colors.textHint)),
                          ])
                        : Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: CircleAvatar(radius: 12, backgroundColor: colors.primary,
                                  child: const Icon(Icons.edit, size: 12, color: Colors.white)),
                            ),
                          )),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: _requiredLabel(context, 'الصورة الرئيسية')),
          const SizedBox(height: 20),

          _requiredLabel(context, 'اسم المنتج'),
          const SizedBox(height: 6),
          TextField(
            controller: controller.nameCtrl,
            decoration: const InputDecoration(hintText: 'اكتب اسم المنتج', isDense: true),
          ),
          const SizedBox(height: 16),

          _requiredLabel(context, 'الوصف المختصر'),
          const SizedBox(height: 6),
          TextField(
            controller: controller.shortDescCtrl,
            decoration: const InputDecoration(hintText: 'اكتب وصفاً مختصراً للمنتج', isDense: true),
          ),
          const SizedBox(height: 16),

          _requiredLabel(context, 'الوصف التفصيلي'),
          const SizedBox(height: 6),
          TextField(
            controller: controller.descCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'اكتب وصفاً تفصيلياً عن المنتج',
              alignLabelWithHint: true, isDense: true,
            ),
          ),
          // ✅ زر "حسّن الوصف بالذكاء الاصطناعي" — يظهر فقط بعد أن يتوقف
          // البائع عن الكتابة (Debounce) ويكون الوصف ≥10 أحرف، بنفس سلوك
          // الشاشة القديمة تماماً — إعادة تفعيل لميزة كانت متوقفة.
          if (_showEnhanceButton || controller.isEnhancingDescription) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: controller.isEnhancingDescription ? null : _enhanceDescription,
                icon: controller.isEnhancingDescription
                    ? SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
                    : Icon(Icons.auto_awesome, size: 16, color: colors.primary),
                label: Text(
                  controller.isEnhancingDescription ? 'جاري التحسين...' : 'حسّن الوصف بالذكاء الاصطناعي',
                  style: TextStyle(color: colors.primary, fontSize: 12.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          _requiredLabel(context, 'الفئة الرئيسية'),
          const SizedBox(height: 6),
          _CategoryRootDropdown(controller: controller),
          const SizedBox(height: 16),

          if (_BasicInfoStep._currentSubOptions(controller).isNotEmpty) ...[
            _requiredLabel(context, 'الفئة الفرعية'),
            const SizedBox(height: 6),
            _CategorySubDropdown(controller: controller),
            const SizedBox(height: 10),
          ],

          // ✅ جديد — "+ إضافة فئة فرعية أخرى": متاح دائماً (حتى إن كانت
          // الفئة الحالية بلا فئات فرعية رسمية) لأن البائع قد يحتاج فئة
          // غير موجودة أصلاً في الشجرة الرسمية بعد.
          InkWell(
            onTap: () => _showAddCustomSubcategoryDialog(context),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(Icons.add_circle_outline, size: 16, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  controller.customSubcategoryLabel == null
                      ? 'إضافة فئة فرعية أخرى'
                      : 'فئة فرعية مقترَحة: ${controller.customSubcategoryLabel}',
                  style: TextStyle(color: colors.primary, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                if (controller.customSubcategoryLabel != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: controller.clearCustomSubcategory,
                    child: Icon(Icons.close, size: 14, color: colors.textHint),
                  ),
                ],
              ]),
            ),
          ),
        ]),
      ),

      // ── السعر والمخزون ──────────────────────────────────────────────
      _SectionCard(
        title: 'السعر والمخزون',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              flex: 3,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _requiredLabel(context, 'السعر'),
                const SizedBox(height: 6),
                TextField(
                  controller: controller.priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(isDense: true),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('العملة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _showCurrencyPicker(context),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Text(controller.selectedCurrency.symbol),
                      const SizedBox(width: 6),
                      Expanded(child: Text(controller.selectedCurrency.code, overflow: TextOverflow.ellipsis)),
                      const Icon(Icons.keyboard_arrow_down_outlined, size: 16),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 16),

          Text('السعر قبل الخصم (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          const SizedBox(height: 6),
          TextField(
            controller: controller.originalPriceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(isDense: true),
          ),
          const SizedBox(height: 16),

          if (!controller.hasVariants) ...[
            _requiredLabel(context, 'الكمية المتوفرة'),
            const SizedBox(height: 6),
            TextField(
              controller: controller.stockCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'أدخل الكمية', isDense: true),
            ),
            const SizedBox(height: 16),
          ] else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.info_outline, size: 15, color: colors.primary),
                const SizedBox(width: 6),
                Expanded(child: Text('الكمية تُحدَّد لكل خيار (لون/مقاس) في خطوة الخصائص',
                    style: TextStyle(fontSize: 11.5, color: colors.primary))),
              ]),
            ),

          const SizedBox(height: 4),
          Text('حالة المنتج', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _ConditionChip(
              label: 'جديد', selected: controller.condition == 'new',
              onTap: () => controller.setCondition('new'),
            )),
            const SizedBox(width: 10),
            Expanded(child: _ConditionChip(
              label: 'مستعمل', selected: controller.condition == 'used',
              onTap: () => controller.setCondition('used'),
            )),
          ]),
        ]),
      ),
    ]);
  }
}

class _ConditionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ConditionChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.primary.withValues(alpha: 0.1) : colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? colors.primary : colors.border, width: selected ? 1.6 : 1),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? colors.primary : colors.textPrimary,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 13,
        )),
      ),
    );
  }
}

/// ✅ قائمة الفئة الرئيسية — قائمة الفئات الجذرية (categoryTree مباشرة).
/// عند التغيير: إن كان للفئة الجديدة أبناء، يُختار أول ابن تلقائياً
/// (يمكن للبائع تغييره من قائمة الفئة الفرعية بعدها)؛ وإلا تُعتمَد الفئة
/// الجذرية نفسها مباشرة (فئات مثل "طعام" بلا أبناء حالياً).
class _CategoryRootDropdown extends StatelessWidget {
  final AddEditProductController controller;
  const _CategoryRootDropdown({required this.controller});

  CategoryNode? _currentRoot() {
    final selected = controller.selectedCategory;
    if (selected == null) return null;
    var n = selected;
    while (n.parent != null) {
      n = n.parent!;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final roots = controller.categoryTree;
    final currentRoot = _currentRoot();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(14)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: currentRoot?.category.id,
          hint: const Text('اختر الفئة الرئيسية'),
          items: roots.map((r) => DropdownMenuItem(value: r.category.id, child: Text(r.category.name))).toList(),
          onChanged: (id) {
            if (id == null) return;
            final root = roots.firstWhere((r) => r.category.id == id);
            if (root.children.isNotEmpty) {
              controller.selectCategory(root.children.first);
            } else {
              controller.selectCategory(root);
            }
          },
        ),
      ),
    );
  }
}

/// ✅ قائمة الفئة الفرعية — أبناء الفئة الجذرية المختارة حالياً فقط.
class _CategorySubDropdown extends StatelessWidget {
  final AddEditProductController controller;
  const _CategorySubDropdown({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = controller.selectedCategory;
    final subOptions = _BasicInfoStep._currentSubOptions(controller);
    if (subOptions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(14)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: subOptions.any((s) => s.category.id == selected?.category.id) ? selected?.category.id : null,
          hint: const Text('اختر الفئة الفرعية'),
          items: subOptions.map((s) => DropdownMenuItem(value: s.category.id, child: Text(s.category.name))).toList(),
          onChanged: (id) {
            if (id == null) return;
            final sub = subOptions.firstWhere((s) => s.category.id == id);
            controller.selectCategory(sub);
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  خطوة مرئية 1 — الخصائص (مواصفات + متغيرات مدمجة في عرض واحد)
// ═══════════════════════════════════════════════════════════════════════════
class _AttributesStep extends StatefulWidget {
  final AddEditProductController controller;
  const _AttributesStep({required this.controller});

  @override
  State<_AttributesStep> createState() => _AttributesStepState();
}

class _AttributesStepState extends State<_AttributesStep> {
  bool _advancedOpen = false;
  final _customLabelCtrl = TextEditingController();
  final _brandSearchCtrl = TextEditingController();
  final _brandManualCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final brandValue = widget.controller.attributeValues['brand'];
    if (brandValue != null) _brandManualCtrl.text = brandValue;
  }

  @override
  void dispose() {
    _customLabelCtrl.dispose();
    _brandSearchCtrl.dispose();
    _brandManualCtrl.dispose();
    super.dispose();
  }

  Color _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    final clean = hex.replaceAll('#', '');
    final parsed = int.tryParse('FF$clean', radix: 16);
    return parsed != null ? Color(parsed) : Colors.grey;
  }

  void _showAddCustomAttributeDialog(BuildContext context) {
    _customLabelCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة خاصية أخرى'),
        content: TextField(
          controller: _customLabelCtrl,
          decoration: const InputDecoration(hintText: 'مثال: وزن العبوة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              widget.controller.addCustomAttribute(_customLabelCtrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  // ✅ جديد — "+ لون آخر" / "+ مقاس آخر" / إلخ (مطابقة التصميم المعتمد):
  // يفتح حواراً لإضافة قيمة خيار خاصة بهذا المنتج تحديداً (راجع
  // AddEditProductController.addCustomOptionValue). خاصية اللون تعرض
  // أيضاً لوحة ألوان صغيرة لاختيار hex تمثيلي (اختياري).
  void _showAddCustomOptionValueDialog(BuildContext context, AttributeDefinitionModel attr) {
    final labelCtrl = TextEditingController();
    final isColor = attr.type == AttributeType.colorSwatch || attr.key == 'color';
    String? selectedHex;
    const palette = [
      '#111111', '#FFFFFF', '#8B4513', '#FFC0CB', '#800080',
      '#FFA500', '#FFD700', '#008080', '#A52A2A', '#708090',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${attr.name} آخر'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(hintText: 'اكتب ${attr.name} الجديد'),
            ),
            if (isColor) ...[
              const SizedBox(height: 14),
              const Text('اختر لوناً تقريبياً (اختياري)', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: palette.map((hex) {
                final selected = selectedHex == hex;
                return GestureDetector(
                  onTap: () => setDialogState(() => selectedHex = hex),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _parseHex(hex),
                      border: Border.all(color: selected ? Colors.black : Colors.black26, width: selected ? 2.4 : 1),
                    ),
                  ),
                );
              }).toList()),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                widget.controller.addCustomOptionValue(attr.key, labelCtrl.text, hex: isColor ? selectedHex : null);
                Navigator.pop(ctx);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ خاصية العلامة التجارية: عرض خاص (بحث ضمن الاقتراحات + إدخال يدوي)
  /// مطابق تماماً للتصميم المعتمد — مختلف عن بقية الخصائص النصية العادية.
  Widget _buildBrandField(BuildContext context, AttributeDefinitionModel attr) {
    final colors = context.colors;
    final controller = widget.controller;
    final query = _brandSearchCtrl.text.trim().toLowerCase();
    final suggestions = query.isEmpty
        ? attr.predefinedValues
        : attr.predefinedValues.where((v) => v.label.toLowerCase().contains(query)).toList();

    return _AttributeBlock(
      attr: attr,
      requiredMark: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _brandSearchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'ابحث عن الماركة',
            prefixIcon: Icon(Icons.search, color: colors.textHint),
            isDense: true,
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: suggestions.map((v) {
            final selected = controller.attributeValues['brand'] == v.label;
            return _ChipOption(
              label: v.label, selected: selected,
              onTap: () {
                controller.setAttributeValue('brand', selected ? '' : v.label);
                _brandManualCtrl.text = selected ? '' : v.label;
              },
            );
          }).toList()),
        ],
        const SizedBox(height: 12),
        Text('أو اكتبها', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _brandManualCtrl,
          decoration: const InputDecoration(hintText: 'اكتب اسم الماركة', isDense: true),
          onChanged: (v) => controller.setAttributeValue('brand', v),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final controller = widget.controller;
    final hasAnyCategoryAttributes =
        controller.descriptiveAttributes.isNotEmpty || controller.variantAttributesAvailable.isNotEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionCard(
        title: 'خصائص المنتج',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('اختر الخيارات المتاحة للمنتج (يمكنك اختيار أكثر من خيار)',
              style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
          const SizedBox(height: 14),

          if (!hasAnyCategoryAttributes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('لا توجد خصائص إضافية معرَّفة لهذه الفئة',
                  style: TextStyle(fontSize: 12.5, color: colors.textHint)),
            ),

          // ── خصائص المتغيرات أولاً (لون بدوائر، ثم الباقي بشرائح) —
          // مطابقةً لترتيب التصميم المعتمد: اللون، ثم المقاس، ثم البقية. ──
          ...controller.variantAttributesAvailable.map((attr) {
            final isColor = attr.type == AttributeType.colorSwatch || attr.key == 'color';
            final values = controller.optionValuesFor(attr); // رسمية + مخصَّصة معاً
            return _AttributeBlock(
              attr: attr,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: values.map((v) {
                    final selected = controller.isVariantValueSelected(attr.key, v.id);
                    if (isColor) {
                      return _ColorDot(
                        color: _parseHex(v.hex), selected: selected, label: v.label,
                        onTap: () {
                          if (!controller.hasVariants) controller.setHasVariants(true);
                          controller.toggleVariantValue(attr.key, v.id);
                        },
                      );
                    }
                    return _ChipOption(
                      label: v.label, selected: selected,
                      onTap: () {
                        if (!controller.hasVariants) controller.setHasVariants(true);
                        controller.toggleVariantValue(attr.key, v.id);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _showAddCustomOptionValueDialog(context, attr),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('${attr.name} آخر'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ]),
            );
          }),

          if (controller.hasVariants && controller.variantAttributesAvailable.isNotEmpty) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => controller.setHasVariants(false),
              icon: Icon(Icons.close_rounded, size: 16, color: colors.error),
              label: Text('إلغاء الخيارات المتعددة لهذا المنتج',
                  style: TextStyle(color: colors.error, fontSize: 12)),
            ),
            const SizedBox(height: 10),
          ],

          // ── الخصائص الوصفية (خامة/معالج/بطارية...، أو "brand" بعرضها الخاص) ──
          ...controller.descriptiveAttributes.map((attr) {
            if (attr.key == 'brand') return _buildBrandField(context, attr);
            // ✅ جديد — خصائص Boolean (مثال: "مقاومة الماء") تُعرَض كمفتاح
            // تبديل (نعم/لا) بدل حقل نصي حر — مطابقة الإنفوجراف المرجعي.
            if (attr.type == AttributeType.boolean) {
              final colors = context.colors;
              final isOn = controller.attributeValues[attr.key] == 'true';
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(attr.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  value: isOn,
                  activeThumbColor: colors.primary,
                  onChanged: (v) => controller.setAttributeValue(attr.key, v ? 'true' : ''),
                ),
              );
            }
            final hasPredefined = attr.predefinedValues.isNotEmpty;
            return _AttributeBlock(
              attr: attr,
              requiredMark: false,
              child: hasPredefined
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: attr.predefinedValues.map((v) {
                          final selected = controller.attributeValues[attr.key] == v.label;
                          return _ChipOption(
                            label: v.label, selected: selected,
                            onTap: () => controller.setAttributeValue(attr.key, selected ? '' : v.label),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (ctx) {
                            final ctrl = TextEditingController();
                            return AlertDialog(
                              title: Text('${attr.name} أخرى'),
                              content: TextField(controller: ctrl, decoration: InputDecoration(hintText: 'اكتب ${attr.name}')),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                                ElevatedButton(
                                  onPressed: () {
                                    controller.setAttributeValue(attr.key, ctrl.text);
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('إضافة'),
                                ),
                              ],
                            );
                          },
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text('${attr.name} أخرى'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ])
                  : TextFormField(
                      initialValue: controller.attributeValues[attr.key],
                      decoration: InputDecoration(hintText: 'أدخل ${attr.name}', isDense: true),
                      onChanged: (v) => controller.setAttributeValue(attr.key, v),
                    ),
            );
          }),

          // ── الخصائص المخصَّصة (+ إضافة خاصية أخرى) ───────────────────────
          ...controller.customAttributeKeys.map((label) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                GestureDetector(
                  onTap: () => controller.removeCustomAttribute(label),
                  child: Icon(Icons.close_rounded, size: 16, color: colors.error),
                ),
              ]),
              const SizedBox(height: 6),
              TextFormField(
                initialValue: controller.attributeValues[label],
                decoration: InputDecoration(hintText: 'أدخل قيمة $label', isDense: true),
                onChanged: (v) => controller.setAttributeValue(label, v),
              ),
            ]),
          )),

          OutlinedButton.icon(
            onPressed: () => _showAddCustomAttributeDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إضافة خاصية أخرى'),
          ),
        ]),
      ),

      // ── خيارات متقدمة: سعر ومخزون مستقل لكل تركيبة (اختياري، مخفي افتراضياً) ──
      if (controller.hasVariants && controller.variantDrafts.isNotEmpty)
        _SectionCard(
          title: 'خيارات متقدمة',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: () => setState(() => _advancedOpen = !_advancedOpen),
              child: Row(children: [
                Icon(Icons.tune_rounded, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('تخصيص السعر والمخزون لكل خيار على حدة',
                    style: TextStyle(fontSize: 13, color: colors.textPrimary))),
                Icon(_advancedOpen ? Icons.expand_less : Icons.expand_more, color: colors.textSecondary),
              ]),
            ),
            if (_advancedOpen) ...[
              const SizedBox(height: 12),
              _VariantCombinationsEditor(controller: controller),
            ],
          ]),
        ),
    ]);
  }
}

class _AttributeBlock extends StatelessWidget {
  final AttributeDefinitionModel attr;
  final Widget child;
  final bool requiredMark;
  const _AttributeBlock({required this.attr, required this.child, this.requiredMark = true});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        requiredMark
            ? _requiredLabel(context, attr.name)
            : Text(attr.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

class _ChipOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChipOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withValues(alpha: 0.1) : colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? colors.primary : colors.border, width: selected ? 1.6 : 1),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? colors.primary : colors.textPrimary,
        )),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final String label;
  final VoidCallback onTap;
  const _ColorDot({required this.color, required this.selected, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: color,
            border: Border.all(color: selected ? colors.primary : colors.border, width: selected ? 2.6 : 1),
            boxShadow: selected ? [BoxShadow(color: colors.primary.withValues(alpha: 0.3), blurRadius: 6)] : null,
          ),
          child: selected
              ? Icon(Icons.check, size: 18, color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: colors.textSecondary)),
      ]),
    );
  }
}

/// ✅ محرِّر التركيبات المتقدِّم — نُقل هنا كما هو من التصميم السابق (لا يزال
// وظيفياً كاملاً)، لكنه الآن خلف تبويب "خيارات متقدمة" المطوى افتراضياً،
// مطابقةً لتوجيه "لا نريد نظام مخزون معقّد الآن" مع إبقائه متاحاً لمن يريده.
class _VariantCombinationsEditor extends StatefulWidget {
  final AddEditProductController controller;
  const _VariantCombinationsEditor({required this.controller});

  @override
  State<_VariantCombinationsEditor> createState() => _VariantCombinationsEditorState();
}

class _VariantCombinationsEditorState extends State<_VariantCombinationsEditor> {
  final _bulkPriceCtrl = TextEditingController();

  @override
  void dispose() {
    _bulkPriceCtrl.dispose();
    super.dispose();
  }

  String _describe(VariantDraft draft) {
    final valuesByKey = <String, List<AttributeOptionValue>>{
      for (final attr in widget.controller.variantAttributesAvailable)
        attr.key: widget.controller.optionValuesFor(attr),
    };
    return draft.describeWith(valuesByKey);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final drafts = widget.controller.variantDrafts;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _bulkPriceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'تطبيق سعر على الكل', isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            final v = double.tryParse(_bulkPriceCtrl.text.trim());
            if (v != null) widget.controller.applyPriceToAllDrafts(v);
          },
          child: const Text('تطبيق'),
        ),
      ]),
      const SizedBox(height: 12),
      ...List.generate(drafts.length, (i) {
        final d = drafts[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(_describe(d), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              Switch(value: d.isActive, onChanged: (_) => widget.controller.toggleDraftActive(i), activeThumbColor: colors.primary),
            ]),
            Row(children: [
              Expanded(child: TextFormField(
                initialValue: d.price.toString(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'السعر', isDense: true),
                onChanged: (v) => widget.controller.updateDraftPrice(i, double.tryParse(v) ?? d.price),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                initialValue: d.stock.toString(),
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'المخزون', isDense: true),
                onChanged: (v) => widget.controller.updateDraftStock(i, int.tryParse(v) ?? d.stock),
              )),
            ]),
          ]),
        );
      }),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  خطوة مرئية 2 — الصور
// ═══════════════════════════════════════════════════════════════════════════
class _GalleryStep extends StatelessWidget {
  final AddEditProductController controller;
  final Future<void> Function(void Function(String url) onUploaded) onPickImage;
  const _GalleryStep({required this.controller, required this.onPickImage});

  void _showVideoLinkDialog(BuildContext context, AddEditProductController controller) {
    final ctrl = TextEditingController(text: controller.videoUrlCtrl.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رابط فيديو المنتج'),
        content: TextField(
          controller: ctrl,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(hintText: 'https://...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              controller.videoUrlCtrl.text = ctrl.text.trim();
              controller.refresh();
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasColor = controller.hasVariants &&
        controller.variantAttributesAvailable.any((a) => a.key == 'color' &&
            (controller.selectedVariantValueIds['color']?.isNotEmpty ?? false));

    final allImages = <String>[
      if (controller.heroUrl != null) controller.heroUrl!,
      ...controller.itemImageUrls,
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionCard(
        title: 'صور المنتج',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('أضف صوراً واضحة للمنتج من زوايا مختلفة', style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10,
            children: [
              // ✅ زر "إضافة صورة" أولاً في الشبكة (مطابقة ترتيب التصميم
              // المعتمد تماماً)، ثم الصور المرفوعة بعده.
              GestureDetector(
                onTap: controller.uploadingImage
                    ? null
                    : () => onPickImage((url) {
                          if (controller.heroUrl == null) {
                            controller.setHeroUrl(url);
                          } else {
                            controller.addItemImage(url);
                          }
                        }),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: controller.uploadingImage
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_outlined, color: colors.textHint, size: 24),
                          const SizedBox(height: 4),
                          Text('إضافة صورة', style: TextStyle(fontSize: 10, color: colors.textHint)),
                        ]),
                ),
              ),
              ...allImages.map((url) => Stack(children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(image: NetworkImage(ImageKitService.productUrl(url)), fit: BoxFit.cover),
                  ),
                ),
                if (url == controller.heroUrl)
                  Positioned(
                    bottom: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(6)),
                      child: const Text('رئيسية', style: TextStyle(color: Colors.white, fontSize: 9)),
                    ),
                  ),
                Positioned(
                  top: 2, left: 2,
                  child: GestureDetector(
                    onTap: () {
                      if (url == controller.heroUrl) {
                        controller.removeImageUrl(url);
                      } else {
                        controller.removeItemImage(url);
                        controller.removeImageUrl(url);
                      }
                    },
                    child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 12, color: Colors.white)),
                  ),
                ),
              ])),
            ],
          ),
          const SizedBox(height: 10),
          Text('الصورة الأولى إجبارية (الرئيسية) — يمكنك إضافة حتى 10 صور إضافية اختيارية',
              style: TextStyle(fontSize: 11, color: colors.textHint)),
        ]),
      ),

      _SectionCard(
        title: 'فيديو المنتج (اختياري)',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('أضف فيديو قصير للمنتج لزيادة ثقة المشترين',
              style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showVideoLinkDialog(context, controller),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Column(children: [
                Icon(
                  controller.videoUrlCtrl.text.trim().isEmpty ? Icons.videocam_outlined : Icons.check_circle,
                  color: controller.videoUrlCtrl.text.trim().isEmpty ? colors.textHint : colors.success,
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  controller.videoUrlCtrl.text.trim().isEmpty ? 'إضافة فيديو' : 'تم إضافة رابط الفيديو — اضغط للتغيير',
                  style: TextStyle(fontSize: 11.5, color: colors.textHint),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text('⚠️ رفع الفيديو مباشرة غير مدعوم بعد — يُضاف كرابط جاهز فقط',
              style: TextStyle(fontSize: 10.5, color: colors.textHint)),
        ]),
      ),

      if (hasColor)
        _SectionCard(
          title: 'صور حسب اللون (اختياري)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: (controller.selectedVariantValueIds['color'] ?? <String>{}).map((valueId) {
              final attr = controller.variantAttributesAvailable.firstWhere((a) => a.key == 'color');
              final resolved = controller.resolveOptionValue(attr, valueId);
              final label = resolved?.label ?? valueId;
              final url = controller.colorImageUrls[valueId];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12))),
                  if (url != null)
                    Container(width: 48, height: 48,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(image: NetworkImage(ImageKitService.productUrl(url)), fit: BoxFit.cover)))
                  else
                    Container(width: 48, height: 48,
                        decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.border))),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => onPickImage((url) => controller.setColorImage(valueId, url)),
                    child: const Text('اختيار'),
                  ),
                ]),
              );
            }).toList(),
          ),
        ),

      const _SectionCard(
        title: 'نصائح لصور أفضل',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TipRow(text: 'استخدم صوراً حقيقية وواضحة'),
            _TipRow(text: 'أضف صوراً من زوايا مختلفة'),
            _TipRow(text: 'تأكد من إضاءة جيدة'),
            _TipRow(text: 'اجعل الصورة الرئيسية جذابة'),
          ],
        ),
      ),
    ]);
  }
}

class _TipRow extends StatelessWidget {
  final String text;
  const _TipRow({required this.text});
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(Icons.check_circle, size: 16, color: colors.success),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: colors.textSecondary))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  خطوة مرئية 3 — النشر (مراجعة)
// ═══════════════════════════════════════════════════════════════════════════
class _ReviewStep extends StatelessWidget {
  final AddEditProductController controller;
  const _ReviewStep({required this.controller});

  /// ✅ يبني نص القيم المختارة لخاصية متغيّرة معيّنة (مثال: "أسود، أزرق،
  /// رمادي" لخاصية اللون) — يدعم القيم المخصَّصة أيضاً عبر resolveOptionValue.
  String _variantValuesText(String attrKey) {
    final ids = controller.selectedVariantValueIds[attrKey];
    if (ids == null || ids.isEmpty) return '';
    final attrMatch = controller.variantAttributesAvailable.where((a) => a.key == attrKey);
    if (attrMatch.isEmpty) return '';
    final attr = attrMatch.first;
    final labels = ids.map((id) => controller.resolveOptionValue(attr, id)?.label ?? id);
    return labels.join('، ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final categoryPath = _breadcrumb(controller.selectedCategory, controller.customSubcategoryLabel);
    final colorText = _variantValuesText('color');
    final sizeText = _variantValuesText('size');
    final materialText = controller.attributeValues['material'] ?? '';
    final brandText = controller.attributeValues['brand'] ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionCard(
        title: 'مراجعة المنتج',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('راجع تفاصيل منتجك قبل نشره', style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
          const SizedBox(height: 14),
          Row(children: [
            if (controller.heroUrl != null)
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(image: NetworkImage(ImageKitService.productUrl(controller.heroUrl!)), fit: BoxFit.cover),
                ),
              )
            else
              Container(width: 64, height: 64,
                  decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.image_outlined, color: colors.textHint)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(controller.nameCtrl.text.isEmpty ? '—' : controller.nameCtrl.text,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(categoryPath, style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
              const SizedBox(height: 4),
              Text('${controller.priceCtrl.text} ${controller.selectedCurrency.symbol}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary, fontSize: 14)),
            ])),
          ]),
          const Divider(height: 28),
          // ✅ ترتيب ثابت مطابق للتصميم المعتمد تماماً: الوصف، اللون،
          // المقاس، الخامة، (العلامة التجارية)، السعر، الكمية، الحالة، الفئة.
          _ReviewRow(label: 'الوصف', value: controller.descCtrl.text, icon: Icons.description_outlined),
          _ReviewRow(label: 'اللون', value: colorText, icon: Icons.palette_outlined),
          _ReviewRow(label: 'المقاس', value: sizeText, icon: Icons.straighten_outlined),
          _ReviewRow(label: 'الخامة', value: materialText, icon: Icons.texture_outlined),
          _ReviewRow(label: 'العلامة التجارية', value: brandText, icon: Icons.local_offer_outlined),
          _ReviewRow(
            label: 'السعر',
            value: '${controller.priceCtrl.text} ${controller.selectedCurrency.symbol}',
            icon: Icons.attach_money_rounded,
          ),
          _ReviewRow(
            label: 'الكمية المتوفرة',
            value: controller.hasVariants ? 'حسب كل خيار (${controller.variantDrafts.length})' : controller.stockCtrl.text,
            icon: Icons.inventory_2_outlined,
          ),
          _ReviewRow(
            label: 'حالة المنتج',
            value: controller.condition == 'new' ? 'جديد' : 'مستعمل',
            icon: Icons.verified_outlined,
          ),
          _ReviewRow(label: 'الفئة', value: categoryPath, icon: Icons.category_outlined),
          // ✅ جديد — أي خصائص وصفية إضافية غير مُدرَجة أعلاه بشكل صريح
          // (خامة/علامة تجارية فقط مُدرَجتان صراحةً) + الخصائص المخصَّصة
          // ("+ إضافة خاصية أخرى") — تُعرَض تلقائياً بلا استثناء بدل أن
          // تختفي بصمت من صفحة المراجعة.
          ...controller.descriptiveAttributes.where((a) => a.key != 'material' && a.key != 'brand').map((attr) {
            final raw = controller.attributeValues[attr.key] ?? '';
            final display = attr.type == AttributeType.boolean
                ? (raw == 'true' ? 'نعم' : (raw.isEmpty ? '' : 'لا'))
                : raw;
            return _ReviewRow(label: attr.name, value: display, icon: Icons.info_outline);
          }),
          ...controller.customAttributeKeys.map((label) => _ReviewRow(
                label: label,
                value: controller.attributeValues[label] ?? '',
                icon: Icons.info_outline,
              )),
        ]),
      ),

      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.shield_outlined, color: colors.accentDark, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'قبل النشر: بالضغط على "نشر المنتج" فإنك توافق على أن تفاصيل المنتج صحيحة ومطابقة لسياسات سوجا.',
            style: TextStyle(fontSize: 11.5, color: colors.textPrimary, height: 1.5),
          )),
        ]),
      ),
    ]);
  }

  String _breadcrumb(CategoryNode? node, String? customSubcategory) {
    if (node == null) return '—';
    final parts = <String>[];
    CategoryNode? n = node;
    while (n != null) {
      parts.insert(0, n.category.name);
      n = n.parent;
    }
    var path = parts.join(' > ');
    // ✅ اقتراح فئة فرعية غير رسمية: يُلحَق للعرض فقط، لا يستبدل الفئة
    // الفعلية أبداً — بدون هذا كان سيختفي بصمت من صفحة المراجعة.
    if (customSubcategory != null && customSubcategory.isNotEmpty) {
      path = '$path ($customSubcategory — مقترَحة)';
    }
    return path;
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _ReviewRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 12.5, color: colors.textSecondary))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12.5, color: colors.textPrimary, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
