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
import '../../services/product_draft_store.dart';
import '../../utils/app_colors.dart';
import '../../utils/currencies.dart';
import '../../widgets/attribute_manager_sheet.dart';
import '../../widgets/product_form_widgets.dart';

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
    // ✅ منتج جديد فقط: اعرض استعادة المسودة المحفوظة (إن وُجدت)
    if (widget.product == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerDraft());
    }
  }

  String get _uid => context.read<AuthProvider>().currentUser?.uid ?? '';
  bool _draftSaved = false; // لتفادي سؤال الخروج بعد حفظ المسودة

  Future<void> _offerDraft() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    final draft = await ProductDraftStore.load(uid);
    if (draft == null || !mounted) return;
    final name = (draft['name'] ?? '').toString();
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('لديك مسودة محفوظة'),
        content: Text(name.isNotEmpty
            ? 'هل تريد متابعة العمل على "$name"؟'
            : 'هل تريد متابعة العمل على مسودتك السابقة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: Text('حذف المسودة', style: TextStyle(color: ctx.colors.error)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx, 'new'), child: const Text('بدء جديد')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'restore'), child: const Text('استعادة')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'delete') {
      await ProductDraftStore.clear(uid);
    } else if (choice == 'restore') {
      // ننتظر انتهاء تحميل الفئات (حدّ أقصى ~10 ثوانٍ)
      for (var i = 0; i < 100 && _controller.loadingCategories; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
      }
      await _controller.applyDraft(draft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت استعادة المسودة')),
        );
      }
    }
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

  /// ✅ اختيار فيديو (معرض أو كاميرا) ورفعه فعلياً، ثم حفظ رابطه في المنتج.
  Future<void> _pickAndUploadVideo({required bool fromCamera}) async {
    final colors = context.colors;
    final file = await ImageKitService.pickVideo(fromCamera: fromCamera);
    if (file == null || !mounted) return;
    _controller.setVideoUploadState(uploading: true, progress: 0);
    // ✅ ضغط الفيديو أولاً (أول 35% من الشريط) ثم الرفع (الباقي)
    final prepared = await ImageKitService.compressVideo(
      file,
      onProgress: (p) {
        if (mounted) _controller.setVideoUploadState(uploading: true, progress: p * 0.35);
      },
    );
    if (!mounted) return;
    String? errorMsg;
    final url = await ImageKitService.uploadVideo(
      prepared,
      onProgress: (p) {
        if (mounted) _controller.setVideoUploadState(uploading: true, progress: 0.35 + p * 0.65);
      },
      onError: (m) => errorMsg = m,
    );
    ImageKitService.clearVideoCache();
    if (!mounted) return;
    _controller.setVideoUploadState(uploading: false);
    if (url != null) {
      _controller.setVideoUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ ${errorMsg ?? 'فشل رفع الفيديو'}'),
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

  /// ✅ حفظ كمسودة (محلياً على الجهاز) — للمنتجات الجديدة فقط.
  Future<void> _saveDraft() async {
    final colors = context.colors;
    final messenger = ScaffoldMessenger.of(context);
    if (_controller.isEditing) {
      messenger.showSnackBar(const SnackBar(
        content: Text('المسودات للمنتجات الجديدة فقط. استخدم "حفظ التعديلات" لهذا المنتج.'),
      ));
      return;
    }
    if (!_controller.hasDraftContent) {
      messenger.showSnackBar(const SnackBar(
        content: Text('أدخل بيانات المنتج أو أضف صورة قبل الحفظ كمسودة'),
      ));
      return;
    }
    final ok = await ProductDraftStore.save(_uid, _controller.toDraftMap());
    if (!mounted) return;
    if (ok) {
      _draftSaved = true;
      messenger.showSnackBar(SnackBar(
        content: const Text('💾 تم حفظ المسودة على هذا الجهاز — ستجدها عند فتح "إضافة منتج"'),
        backgroundColor: colors.success,
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: const Text('تعذّر حفظ المسودة'),
        backgroundColor: colors.error,
      ));
    }
  }

  /// إغلاق الشاشة: إن كان هناك عمل غير محفوظ في منتج جديد نسأل أولاً.
  Future<void> _handleClose() async {
    if (_controller.isEditing || _draftSaved || !_controller.hasDraftContent) {
      Navigator.pop(context);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حفظ كمسودة؟'),
        content: const Text('لديك بيانات غير منشورة. يمكنك حفظها كمسودة والعودة لها لاحقاً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text('تجاهل', style: TextStyle(color: ctx.colors.error)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx, 'stay'), child: const Text('متابعة التعديل')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('حفظ كمسودة')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'save') {
      await _saveDraft();
      if (mounted && _draftSaved) Navigator.pop(context);
    } else if (choice == 'discard') {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    final colors = context.colors;
    final success = await _controller.save();
    if (!mounted) return;
    if (success) {
      if (!_controller.isEditing) await ProductDraftStore.clear(_uid);
      if (!mounted) return;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose();
      },
      child: Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(_controller.isEditing ? 'تعديل المنتج' : 'إضافة منتج'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _handleClose,
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
              onSaveDraft: _saveDraft,
            ),
          ]);
        },
      ),
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
        return _GalleryStep(
          controller: _controller,
          onPickImage: _pickAndUpload,
          onPickVideo: (fromCamera) => _pickAndUploadVideo(fromCamera: fromCamera),
        );
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
    controller.shortDescCtrl.addListener(_onDescriptionChanged);
  }

  @override
  void dispose() {
    _descDebounceTimer?.cancel();
    controller.descCtrl.removeListener(_onDescriptionChanged);
    controller.shortDescCtrl.removeListener(_onDescriptionChanged);
    super.dispose();
  }

  void _onDescriptionChanged() {
    _descDebounceTimer?.cancel();
    if (_showEnhanceButton) setState(() => _showEnhanceButton = false);
    // ✅ يظهر الزر بسرعة (نصف ثانية بعد التوقف) ما إن يكتب البائع 5 أحرف
    // أو أكثر في الوصف المختصر أو التفصيلي — ويحسّن الحقلين معاً.
    if (controller.descCtrl.text.trim().length < 5 &&
        controller.shortDescCtrl.text.trim().length < 5) { return; }
    _descDebounceTimer = Timer(const Duration(milliseconds: 500), () {
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
        content: const Text('✨ تم تحسين الوصف المختصر والتفصيلي'),
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

  // ✅ جديد — "+ إضافة فئة فرعية أخرى": يفتح حواراً لإدخال اسم فئة فرعية
  // مقترَحة غير موجودة رسمياً بعد (نصّي بحت، لا يُنشئ فئة حقيقية).
  void _showAddCustomSubcategoryDialog(BuildContext context) {
    final textCtrl = TextEditingController(text: controller.customSubcategoryLabel ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('فئة فرعية أخرى ضمن ${controller.currentRootCategory?.category.name ?? ''}'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'مثال: سماعات'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              await controller.setCustomSubcategory(textCtrl.text);
              nav.pop();
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
                  controller.isEnhancingDescription ? 'جاري التحسين...' : 'حسّن الوصفين بالذكاء الاصطناعي',
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

          const SizedBox(height: 16),
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

/// اختيار العملة — قائمة منسدلة ببحث ذكي (عربي/إنجليزي/رمز). تُغلق بعد اختيار عملة واحدة.
Future<void> _showCurrencyPickerSheet(BuildContext context, AddEditProductController controller) async {
  final picked = await showCurrencyPicker(context, selected: controller.selectedCurrency);
  if (picked != null) controller.setCurrency(picked);
}

/// ✅ بطاقة السعر والمخزون. منتج بلا خيارات: سعر + سعر قبل الخصم + كمية (مع كتابتها
/// بالحروف). منتج بخيارات: تبقى العملة هنا، والسعر والكمية في قسم "سعر وكمية كل خيار".
class _PricingStockCard extends StatelessWidget {
  final AddEditProductController controller;
  const _PricingStockCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasVariants = controller.hasVariants && controller.variantDrafts.isNotEmpty;

    final currencyField = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('العملة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showCurrencyPickerSheet(context, controller),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Text(controller.selectedCurrency.symbol, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${controller.selectedCurrency.name} (${controller.selectedCurrency.code})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
          ]),
        ),
      ),
    ]);

    return _SectionCard(
      title: 'السعر والمخزون',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        currencyField,
        const SizedBox(height: 16),
        if (!hasVariants) ...[
          _requiredLabel(context, 'السعر'),
          const SizedBox(height: 6),
          TextField(
            controller: controller.priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: kIntegerOnlyFormatters,
            textDirection: TextDirection.ltr,
            onChanged: (_) => controller.onBasePriceChanged(),
            decoration: const InputDecoration(isDense: true),
          ),
          NumberWordsHint(controller: controller.priceCtrl),
          const SizedBox(height: 16),
          Text('السعر قبل الخصم (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          const SizedBox(height: 6),
          TextField(
            controller: controller.originalPriceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: kIntegerOnlyFormatters,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(isDense: true),
          ),
          NumberWordsHint(controller: controller.originalPriceCtrl),
          const SizedBox(height: 16),
          _requiredLabel(context, 'الكمية المتوفرة'),
          const SizedBox(height: 6),
          TextField(
            controller: controller.stockCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: kIntegerOnlyFormatters,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(hintText: 'أدخل الكمية', isDense: true),
          ),
          NumberWordsHint(controller: controller.stockCtrl),
        ] else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.info_outline, size: 15, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text('السعر والكمية يُحدَّدان في قسم "سعر وكمية كل خيار" أدناه',
                    style: TextStyle(fontSize: 11.5, color: colors.primary)),
              ),
            ]),
          ),
      ]),
    );
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
          hint: Text(controller.customSubcategoryLabel ?? 'اختر الفئة الفرعية',
              style: controller.customSubcategoryLabel != null ? TextStyle(color: colors.primary, fontWeight: FontWeight.bold) : null),
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

  static final ButtonStyle _compactBtn = OutlinedButton.styleFrom(
    minimumSize: const Size(0, 36),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    visualDensity: VisualDensity.compact,
  );

  Color _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    final clean = hex.replaceAll('#', '');
    final parsed = int.tryParse('FF$clean', radix: 16);
    return parsed != null ? Color(parsed) : Colors.grey;
  }

  void _showAddCustomAttributeDialog(BuildContext context) {
    _customLabelCtrl.clear();
    var kind = 'options';
    String? error;
    const kinds = <String, (String, String)>{
      'options': ('خيارات للمشتري', 'مثل: الرام، التخزين، الموديل، المقاس — لكل خيار سعر وكمية'),
      'measure': ('قياس بوحدة', 'مثل: الحجم 5، 7، 12 لتر أو الوزن أو الطول — اختر الوحدة مرة واحدة وأضف عدة قيم'),
      'color': ('ألوان', 'عينات ألوان بدوائر ملوّنة — لكل لون سعر وكمية'),
      'spec': ('مواصفة ثابتة', 'مثل: بلد الصنع، الخامة — لا تؤثر على السعر أو الكمية'),
    };
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إضافة خاصية أخرى'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _customLabelCtrl,
                decoration: InputDecoration(hintText: 'اسم الخاصية، مثال: الحجم', errorText: error),
                onChanged: (_) {
                  if (error != null) setDialogState(() => error = null);
                },
              ),
              const SizedBox(height: 14),
              const Text('نوع الخاصية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: kinds.entries.map((e) {
                return _ChipOption(
                  label: e.value.$1,
                  selected: kind == e.key,
                  onTap: () => setDialogState(() => kind = e.key),
                );
              }).toList()),
              const SizedBox(height: 8),
              Text(kinds[kind]!.$2, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                final err = widget.controller.addCustomAttribute(_customLabelCtrl.text, kind: kind);
                if (err != null) {
                  setDialogState(() => error = err);
                  return;
                }
                Navigator.pop(ctx);
                // خاصية جديدة: افتح إدخال القيم فوراً ثم اسأل عن حفظها في المفضلة.
                final created = widget.controller.customAttributeDefs.last;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _afterCustomAttributeCreated(kind, created);
                });
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _afterCustomAttributeCreated(String kind, AttributeDefinitionModel created) async {
    final c = widget.controller;
    if (kind == 'color') {
      await showReadyColorsSheet(context, c, created.key);
    } else if (kind == 'spec') {
      final res = await showAddValuesDialog(context, attrName: created.name, allowUnit: false);
      if (res != null) c.addSpecValues(created.key, res.labels);
    } else {
      await _showAddValuesSheet(context, created);
    }
    if (!mounted) return;
    await promptSaveAttributeFavorite(context, c, created.key);
  }

  /// ✅ إضافة عدة قيم لخاصية اختيارية دفعة واحدة، بوحدة قياس واحدة اختيارية
  /// (5، 7، 12 + لتر → ثلاثة خيارات) أو بلا وحدة (S، M، L / 38، 40).
  Future<void> _showAddValuesSheet(BuildContext context, AttributeDefinitionModel attr) async {
    final c = widget.controller;
    final res = await showAddValuesDialog(
      context,
      attrName: attr.name,
      initialUnit: c.attributeUnits[attr.key],
      existingLabels: c.existingValueLabels(attr.key),
    );
    if (res == null || !mounted) return;
    final n = c.addVariantValues(attr.key, res.labels, unit: res.unit);
    if (!mounted) return;
    ScaffoldMessenger.of(this.context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('تمت إضافة $n ${n == 1 ? 'قيمة' : 'قيم'} إلى ${attr.name}')));
  }

  /// ✅ قيمة جديدة لخاصية "مواصفة" (وصفية): تُضاف كشريحة وتُختار فوراً.
  void _showAddCustomSpecValueDialog(BuildContext context, AttributeDefinitionModel attr, {required bool custom}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(custom ? 'إضافة ${attr.name}' : '${attr.name} أخرى'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: 'اكتب ${attr.name}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              widget.controller.addCustomSpecValue(attr.key, ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
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
      controller: controller,
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
            final isCustomAttr = controller.isCustomAttribute(attr.key);
            return _AttributeBlock(
              attr: attr,
              controller: controller,
              requiredMark: !isCustomAttr,
              onRemove: isCustomAttr ? () => controller.removeCustomAttribute(attr.key) : null,
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
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (isColor) ...[
                    OutlinedButton.icon(
                      onPressed: () => showReadyColorsSheet(context, controller, attr.key),
                      icon: const Icon(Icons.palette_outlined, size: 16),
                      label: const Text('ألوان جاهزة'),
                      style: _compactBtn,
                    ),
                    OutlinedButton.icon(
                      onPressed: () => createNewColor(context, controller, attr.key),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('إنشاء لون جديد'),
                      style: _compactBtn,
                    ),
                  ] else
                    OutlinedButton.icon(
                      onPressed: () => _showAddValuesSheet(context, attr),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text('+ إضافة قيم ${attr.name}'),
                      style: _compactBtn,
                    ),
                ]),
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
            final isCustomAttr = controller.isCustomAttribute(attr.key);
            // الشرائح = القيم الرسمية + قيم أضافها البائع (+ القيمة المحفوظة الحالية
            // إن لم تكن ضمنها) — فلا تختفي قيمة كتبها البائع يدوياً.
            final chipValues = <AttributeOptionValue>[...controller.optionValuesFor(attr)];
            final current = controller.attributeValues[attr.key];
            if (current != null && current.isNotEmpty && !chipValues.any((v) => v.label == current)) {
              chipValues.add(AttributeOptionValue(id: 'current_${attr.key}', label: current));
            }
            final showChips = chipValues.isNotEmpty || isCustomAttr;
            return _AttributeBlock(
              attr: attr,
              controller: controller,
              requiredMark: false,
              onRemove: isCustomAttr ? () => controller.removeCustomAttribute(attr.key) : null,
              child: showChips
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (chipValues.isNotEmpty)
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: chipValues.map((v) {
                            final selected = controller.attributeValues[attr.key] == v.label;
                            return _ChipOption(
                              label: v.label, selected: selected,
                              onTap: () => controller.setAttributeValue(attr.key, selected ? '' : v.label),
                            );
                          }).toList(),
                        ),
                      if (chipValues.isNotEmpty) const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _showAddCustomSpecValueDialog(context, attr, custom: isCustomAttr),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(isCustomAttr ? 'إضافة ${attr.name}' : '${attr.name} أخرى'),
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

          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => _showAddCustomAttributeDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('+ إضافة خاصية'),
            ),
            OutlinedButton.icon(
              onPressed: () => showReadyAttributesSheet(context, controller),
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('خصائص جاهزة'),
            ),
            OutlinedButton.icon(
              onPressed: controller.selectedCategory == null ? null : () => showFavoritesSheet(context, controller),
              icon: const Icon(Icons.bookmark_outline, size: 18),
              label: const Text('مفضلاتي'),
            ),
          ]),
        ]),
      ),

      // ── السعر والمخزون (نُقل من خطوة المعلومات الأساسية) ──
      _PricingStockCard(controller: controller),

      // ── سعر وكمية كل خيار: ظاهر دائماً عند وجود خيارات (لون/مقاس...) ──
      if (controller.hasVariants && controller.variantDrafts.isNotEmpty)
        _SectionCard(
          title: 'سعر وكمية كل خيار',
          child: _VariantPricingSection(controller: controller),
        ),
    ]);
  }
}

class _AttributeBlock extends StatelessWidget {
  final AttributeDefinitionModel attr;
  final Widget child;
  final bool requiredMark;
  final VoidCallback? onRemove; // ✅ يظهر فقط للخصائص التي أضافها البائع
  final AddEditProductController? controller; // عند وجوده: أدوات الإدارة (إدارة/تفعيل/إخفاء)
  const _AttributeBlock({required this.attr, required this.child, this.requiredMark = true, this.onRemove, this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = controller;
    final enabled = c == null || c.isAttributeEnabled(attr.key);
    final hidden = c != null && !attr.isVariant && c.hiddenFromBuyerKeys.contains(attr.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Row(children: [
              Flexible(
                child: requiredMark
                    ? _requiredLabel(context, attr.name)
                    : Text(attr.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
              ),
              if (hidden) ...[
                const SizedBox(width: 6),
                Icon(Icons.visibility_off_outlined, size: 16, color: colors.textHint),
              ],
            ]),
          ),
          if (c != null)
            IconButton(
              onPressed: () => showAttributeManagerSheet(context, c, attr.key),
              tooltip: 'إدارة الخاصية وقيمها',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.tune_rounded, size: 22, color: colors.primary),
            ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: 'حذف الخاصية',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline, size: 22, color: colors.error),
            ),
          if (c != null)
            Switch(
              value: enabled,
              activeThumbColor: colors.primary,
              onChanged: (v) => c.setAttributeEnabled(attr.key, v),
            ),
        ]),
        const SizedBox(height: 10),
        Opacity(
          opacity: enabled ? 1 : 0.4,
          child: IgnorePointer(ignoring: !enabled, child: child),
        ),
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
/// ✅ قسم "سعر وكمية كل خيار": سؤالا التوحيد (السعر / الكمية) ثم قائمة التركيبات.
class _VariantPricingSection extends StatelessWidget {
  final AddEditProductController controller;
  const _VariantPricingSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final phrase = controller.unifyAttrsPhrase;
    final label = phrase.isEmpty ? 'الخيارات' : phrase;

    Widget unifyCard({
      required bool value,
      required String question,
      required ValueChanged<bool> onToggle,
      required List<Widget> fields,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: value ? colors.primary.withValues(alpha: 0.05) : null,
          border: Border.all(color: value ? colors.primary.withValues(alpha: 0.4) : colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onToggle(!value),
            child: Row(children: [
              Checkbox(value: value, onChanged: (v) => onToggle(v ?? false), activeColor: colors.primary),
              Expanded(child: Text(question, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
            ]),
          ),
          if (value) ...fields,
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('حدّد السعر والكمية لكل خيار — الخيار بكمية صفر يظهر للمشتري "نفد المخزون"',
          style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
      const SizedBox(height: 12),
      unifyCard(
        value: controller.unifyPrice,
        question: 'هل جميع $label لها نفس السعر؟',
        onToggle: controller.setUnifyPrice,
        fields: [
          const SizedBox(height: 8),
          _requiredLabel(context, 'السعر الأساسي'),
          const SizedBox(height: 6),
          TextField(
            controller: controller.unifiedPriceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: kIntegerOnlyFormatters,
            textDirection: TextDirection.ltr,
            onChanged: (_) => controller.onUnifiedPriceChanged(),
            decoration: const InputDecoration(isDense: true),
          ),
          NumberWordsHint(controller: controller.unifiedPriceCtrl),
          const SizedBox(height: 12),
          Text('السعر قبل الخصم (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          const SizedBox(height: 6),
          TextField(
            controller: controller.unifiedOriginalCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: kIntegerOnlyFormatters,
            textDirection: TextDirection.ltr,
            onChanged: (_) => controller.onUnifiedPriceChanged(),
            decoration: const InputDecoration(isDense: true),
          ),
          NumberWordsHint(controller: controller.unifiedOriginalCtrl),
        ],
      ),
      unifyCard(
        value: controller.unifyStock,
        question: 'هل جميع $label لها نفس الكمية؟',
        onToggle: controller.setUnifyStock,
        fields: [
          const SizedBox(height: 8),
          _requiredLabel(context, 'الكمية لكل خيار'),
          const SizedBox(height: 6),
          TextField(
            controller: controller.unifiedStockCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: kIntegerOnlyFormatters,
            textDirection: TextDirection.ltr,
            onChanged: (_) => controller.onUnifiedStockChanged(),
            decoration: const InputDecoration(hintText: 'تُنسخ لكل خيار بصورة مستقلة', isDense: true),
          ),
          NumberWordsHint(controller: controller.unifiedStockCtrl),
        ],
      ),
      _VariantCombinationsEditor(controller: controller),
    ]);
  }
}

class _VariantCombinationsEditor extends StatelessWidget {
  final AddEditProductController controller;
  const _VariantCombinationsEditor({required this.controller});

  String _describe(VariantDraft draft) {
    final valuesByKey = <String, List<AttributeOptionValue>>{
      for (final attr in controller.variantAttributesAvailable) attr.key: controller.optionValuesFor(attr),
    };
    return draft.describeWith(valuesByKey);
  }

  @override
  Widget build(BuildContext context) {
    final drafts = controller.variantDrafts;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < drafts.length; i++)
        _VariantRow(
          key: ValueKey(drafts[i].optionValues.entries.map((e) => '${e.key}=${e.value}').join('|')),
          controller: controller,
          index: i,
          draft: drafts[i],
          title: _describe(drafts[i]),
        ),
    ]);
  }
}

/// صف تركيبة واحدة بمتحكماته الخاصة، يتزامن مع التوحيد دون المساس بما يكتبه البائع.
class _VariantRow extends StatefulWidget {
  final AddEditProductController controller;
  final int index;
  final VariantDraft draft;
  final String title;
  const _VariantRow({super.key, required this.controller, required this.index, required this.draft, required this.title});

  @override
  State<_VariantRow> createState() => _VariantRowState();
}

class _VariantRowState extends State<_VariantRow> {
  late final TextEditingController _price;
  late final TextEditingController _original;
  late final TextEditingController _stock;

  static String _num(double v) => v <= 0 ? '' : (v == v.roundToDouble() ? v.round().toString() : v.toString());

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(text: _num(widget.draft.price));
    _original = TextEditingController(text: _num(widget.draft.originalPrice));
    _stock = TextEditingController(text: widget.draft.stock <= 0 ? '' : widget.draft.stock.toString());
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(covariant _VariantRow old) {
    super.didUpdateWidget(old);
    if (!identical(old.draft, widget.draft)) _sync();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _price.dispose();
    _original.dispose();
    _stock.dispose();
    super.dispose();
  }

  void _setIfDiffers(TextEditingController c, String desired, num parsedCurrent, num wanted) {
    if (parsedCurrent != wanted) c.text = desired;
  }

  /// يحدّث الحقول عند تغيّر القيمة من الخارج (التوحيد)؛ لا يلمس ما يطابق المسوّدة.
  void _sync() {
    if (!mounted) return;
    final d = widget.draft;
    _setIfDiffers(_price, _num(d.price), double.tryParse(_price.text) ?? 0, d.price);
    _setIfDiffers(_original, _num(d.originalPrice), double.tryParse(_original.text) ?? 0, d.originalPrice);
    _setIfDiffers(_stock, d.stock <= 0 ? '' : d.stock.toString(), int.tryParse(_stock.text) ?? 0, d.stock);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = widget.controller;
    final d = widget.draft;
    final priceLocked = c.unifyPrice;
    final stockLocked = c.unifyStock;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Switch(value: d.isActive, onChanged: (_) => c.toggleDraftActive(widget.index), activeThumbColor: colors.primary),
        ]),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _price,
                enabled: !priceLocked,
                keyboardType: TextInputType.number,
                inputFormatters: kIntegerOnlyFormatters,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'السعر', isDense: true),
                onChanged: (v) => c.updateDraftPrice(widget.index, double.tryParse(v) ?? 0),
              ),
              NumberWordsHint(controller: _price),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _original,
                enabled: !priceLocked,
                keyboardType: TextInputType.number,
                inputFormatters: kIntegerOnlyFormatters,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'قبل الخصم', isDense: true),
                onChanged: (v) => c.updateDraftOriginalPrice(widget.index, double.tryParse(v) ?? 0),
              ),
              NumberWordsHint(controller: _original),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _stock,
          enabled: !stockLocked,
          keyboardType: TextInputType.number,
          inputFormatters: kIntegerOnlyFormatters,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'الكمية', isDense: true),
          onChanged: (v) => c.updateDraftStock(widget.index, int.tryParse(v) ?? 0),
        ),
        NumberWordsHint(controller: _stock),
        if (priceLocked || stockLocked)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('الحقول المقفلة تتبع القيمة الموحَّدة — ألغِ التوحيد لتعديلها يدوياً',
                style: TextStyle(fontSize: 10.5, color: colors.textSecondary)),
          ),
      ]),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
//  خطوة مرئية 2 — الصور
// ═══════════════════════════════════════════════════════════════════════════
class _GalleryStep extends StatelessWidget {
  final AddEditProductController controller;
  final Future<void> Function(void Function(String url) onUploaded) onPickImage;
  final Future<void> Function(bool fromCamera) onPickVideo;
  const _GalleryStep({required this.controller, required this.onPickImage, required this.onPickVideo});

  void _showVideoLinkDialog(BuildContext context, AddEditProductController controller) {
    final ctrl = TextEditingController(text: controller.videoUrlCtrl.text);
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('رابط فيديو المنتج'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: ctrl,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(hintText: 'https://...', errorText: error),
              onChanged: (_) {
                if (error != null) setDialogState(() => error = null);
              },
            ),
            const SizedBox(height: 10),
            const Text(
              'الأفضل رابط مباشر لملف الفيديو (ينتهي بـ mp4) فيُشغَّل داخل المنتج. '
              'روابط يوتيوب وتيك توك وإنستغرام تُفتح خارج التطبيق عند الضغط عليها. '
              'أو ارفع الفيديو مباشرة من الجهاز.',
              style: TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.5),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                var url = ctrl.text.trim();
                if (url.isNotEmpty && !url.contains('://')) url = 'https://$url';
                final uri = Uri.tryParse(url);
                if (url.isNotEmpty && (uri == null || uri.host.isEmpty || !uri.host.contains('.'))) {
                  setDialogState(() => error = 'الرابط غير صالح');
                  return;
                }
                controller.videoUrlCtrl.text = url;
                controller.refresh();
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    ).then((_) => ctrl.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasValueImages = controller.hasVariants &&
        controller.variantAttributesAvailable
            .any((a) => (controller.selectedVariantValueIds[a.key]?.isNotEmpty ?? false));

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
          Text('أضف فيديو قصير (حتى 30 ثانية و25MB) لزيادة ثقة المشترين',
              style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
          const SizedBox(height: 12),
          if (controller.uploadingVideo)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Column(children: [
                LinearProgressIndicator(
                  value: controller.videoUploadProgress.clamp(0.0, 1.0),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 10),
                Text('جاري رفع الفيديو... ${(controller.videoUploadProgress * 100).round()}%',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              ]),
            )
          else if (controller.videoUrlCtrl.text.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.success),
              ),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 64, height: 64,
                    child: Stack(alignment: Alignment.center, children: [
                      Container(color: colors.border),
                      if (ImageKitService.videoThumbnailUrl(controller.videoUrlCtrl.text.trim()).isNotEmpty)
                        Image.network(
                          ImageKitService.videoThumbnailUrl(controller.videoUrlCtrl.text.trim()),
                          width: 64, height: 64, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      const Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
                    ]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('تم إضافة الفيديو', style: TextStyle(fontSize: 13, color: colors.success, fontWeight: FontWeight.w600))),
                IconButton(
                  tooltip: 'حذف الفيديو',
                  onPressed: controller.clearVideo,
                  icon: Icon(Icons.delete_outline, color: colors.error),
                ),
              ]),
            )
          else
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => onPickVideo(false),
                icon: const Icon(Icons.video_library_outlined, size: 18),
                label: const Text('من المعرض'),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: () => onPickVideo(true),
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: const Text('تسجيل فيديو'),
              )),
            ]),
          const SizedBox(height: 8),
          if (!controller.uploadingVideo)
            TextButton(
              onPressed: () => _showVideoLinkDialog(context, controller),
              child: Text(
                controller.videoUrlCtrl.text.trim().isEmpty ? 'أو الصق رابط فيديو جاهز' : 'تغيير الرابط',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ]),
      ),

      if (hasValueImages)
        _SectionCard(
          title: 'صور الخيارات (اختياري)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('أضف صورة لأي قيمة تريد (لون، مقاس، سعة...) — تظهر للمشتري عند اختيارها، وإن لم تضف تُعرض الصورة الرئيسية.',
                  style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
              const SizedBox(height: 12),
              for (final attr in controller.variantAttributesAvailable)
                if ((controller.selectedVariantValueIds[attr.key] ?? const <String>{}).isNotEmpty) ...[
                  Text(attr.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final valueId in controller.selectedVariantValueIds[attr.key]!)
                    Builder(builder: (_) {
                      final label = controller.resolveOptionValue(attr, valueId)?.label ?? valueId;
                      final url = controller.valueImageFor(attr.key, valueId);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
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
                            onPressed: () => onPickImage((u) => controller.setValueImage(attr.key, valueId, u)),
                            child: Text(url == null ? 'اختيار' : 'تغيير'),
                          ),
                          if (url != null)
                            IconButton(
                              tooltip: 'إزالة الصورة',
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.delete_outline, size: 22, color: colors.error),
                              onPressed: () => controller.clearValueImage(attr.key, valueId),
                            ),
                        ]),
                      );
                    }),
                  const SizedBox(height: 6),
                ],
            ],
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
              Text('${controller.displayPriceText} ${controller.selectedCurrency.symbol}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary, fontSize: 14)),
            ])),
          ]),
          const Divider(height: 28),
          // ✅ ترتيب ثابت مطابق للتصميم المعتمد تماماً: الوصف، اللون،
          // المقاس، الخامة، (العلامة التجارية)، السعر، الكمية، الحالة، الفئة.
          _ReviewRow(label: 'الوصف', value: controller.descCtrl.text, icon: Icons.description_outlined),
          _ReviewRow(label: 'اللون', value: colorText, icon: Icons.palette_outlined),
          _ReviewRow(label: 'المقاس', value: sizeText, icon: Icons.straighten_outlined),
          // ✅ بقية خصائص الخيارات (رام/تخزين/حجم... سواء من الفئة أو أضافها البائع)
          ...controller.variantAttributesAvailable
              .where((a) => a.key != 'color' && a.key != 'size')
              .map((a) => _ReviewRow(
                    label: a.name,
                    value: _variantValuesText(a.key),
                    icon: Icons.tune_rounded,
                  )),
          _ReviewRow(label: 'الخامة', value: materialText, icon: Icons.texture_outlined),
          _ReviewRow(label: 'العلامة التجارية', value: brandText, icon: Icons.local_offer_outlined),
          _ReviewRow(
            label: 'السعر',
            value: '${controller.displayPriceText} ${controller.selectedCurrency.symbol}',
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
    // ✅ فئة فرعية كتبها البائع تحلّ محل الفرعية الرسمية: الرئيسية > المخصَّصة.
    if (customSubcategory != null && customSubcategory.isNotEmpty) {
      return '${parts.first} > $customSubcategory';
    }
    return parts.join(' > ');
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
