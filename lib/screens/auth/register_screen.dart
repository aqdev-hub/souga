// lib/screens/auth/register_screen.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/imagekit_service.dart';
import '../../utils/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // ── مشتري ───────────────────────────────────────────────────────────────────
  final _cFormKey   = GlobalKey<FormState>();
  final _cNameCtrl  = TextEditingController();
  final _cEmailCtrl = TextEditingController();
  final _cPassCtrl  = TextEditingController();
  final _cPhoneCtrl = TextEditingController();
  File?   _cProfileFile;
  String  _cProfileUrl      = '';
  bool    _cObscure         = true;
  double  _cProfileProgress = -1; // -1=idle, 0-1=uploading, -2=fail, -3=done

  // ── بائع ────────────────────────────────────────────────────────────────────
  final _sFormKey        = GlobalKey<FormState>();
  final _sNameCtrl       = TextEditingController();
  final _sEmailCtrl      = TextEditingController();
  final _sPassCtrl       = TextEditingController();
  final _sPhoneCtrl      = TextEditingController();
  final _storeNameCtrl   = TextEditingController();
  final _storeDescCtrl   = TextEditingController();
  File?   _sProfileFile;
  String  _sProfileUrl      = '';
  File?   _sLogoFile;
  String  _sLogoUrl         = '';
  bool    _sObscure         = true;
  double  _sProfileProgress = -1;
  double  _sLogoProgress    = -1;

  bool get _cUploading        => _cProfileProgress >= 0 && _cProfileProgress < 1;
  bool get _sProfileUploading => _sProfileProgress >= 0 && _sProfileProgress < 1;
  bool get _sLogoUploading    => _sLogoProgress    >= 0 && _sLogoProgress    < 1;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _cNameCtrl.dispose();     _cEmailCtrl.dispose();
    _cPassCtrl.dispose();     _cPhoneCtrl.dispose();
    _sNameCtrl.dispose();     _sEmailCtrl.dispose();
    _sPassCtrl.dispose();     _sPhoneCtrl.dispose();
    _storeNameCtrl.dispose(); _storeDescCtrl.dispose();
    super.dispose();
  }

  // ── رفع الصور — مستقل تماماً عن التسجيل ────────────────────────────────────
  Future<void> _pickAndUpload({required String target}) async {
    final file = await ImageKitService.pickImage(fromCamera: false);
    if (file == null || !mounted) return;

    final folder = (target == 'sLogo') ? 'logos' : 'profiles';

    if (target == 'cProfile') {
      setState(() { _cProfileFile = file; _cProfileProgress = 0.0; _cProfileUrl = ''; });
    } else if (target == 'sProfile') {
      setState(() { _sProfileFile = file; _sProfileProgress = 0.0; _sProfileUrl = ''; });
    } else if (target == 'sLogo') {
      setState(() { _sLogoFile = file; _sLogoProgress = 0.0; _sLogoUrl = ''; });
    }

    final url = await ImageKitService.uploadImage(file, folder, onProgress: (p) {
      if (!mounted) return;
      if (target == 'cProfile') { setState(() => _cProfileProgress = p); }
      else if (target == 'sProfile') { setState(() => _sProfileProgress = p); }
      else if (target == 'sLogo') { setState(() => _sLogoProgress = p); }
    });

    if (!mounted) return;

    if (url != null) {
      if (target == 'cProfile') {
        setState(() { _cProfileUrl = url; _cProfileProgress = -3; });
      } else if (target == 'sProfile') {
        setState(() { _sProfileUrl = url; _sProfileProgress = -3; });
      } else if (target == 'sLogo') {
        setState(() { _sLogoUrl = url; _sLogoProgress = -3; });
      }
    } else {
      if (target == 'cProfile') { setState(() => _cProfileProgress = -2); }
      else if (target == 'sProfile') { setState(() => _sProfileProgress = -2); }
      else if (target == 'sLogo') { setState(() => _sLogoProgress = -2); }
      _snack('تعذر رفع الصورة. يمكنك الاستمرار بدونها.', color: context.colors.warning);
    }
  }

  // ── تسجيل مشتري ─────────────────────────────────────────────────────────────
  Future<void> _registerCustomer() async {
    if (!_cFormKey.currentState!.validate()) return;

    final auth    = context.read<AuthProvider>();
    final success = await auth.registerAsCustomer(
      name:         _cNameCtrl.text.trim(),
      email:        _cEmailCtrl.text.trim(),
      password:     _cPassCtrl.text,
      phone:        _cPhoneCtrl.text.trim(),
      profileImage: _cProfileUrl,
    );

    if (!mounted) return;

    if (success) {
      // إذا كانت الصورة لا تزال ترفع، حدّث الملف الشخصي بعد انتهائها
      if (_cUploading) _watchAndUpdate(auth, 'cProfile');

      // ─── الإصلاح الجذري لـ BUG 1 ───────────────────────────────────────────
      // RegisterScreen مدفوعة فوق Wrapper في Navigator stack.
      // Wrapper يعرض الشاشة الصحيحة تحتنا لكننا نحجبه.
      // popUntil(isFirst) يُزيل RegisterScreen من الـ stack →
      // Wrapper (الذي حُدِّث بالفعل إلى authenticated) يصبح مرئياً.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _snack(auth.errorMessage, color: context.colors.error);
    }
  }

  // ── تسجيل بائع ──────────────────────────────────────────────────────────────
  Future<void> _registerSeller() async {
    if (!_sFormKey.currentState!.validate()) return;

    final auth    = context.read<AuthProvider>();
    final success = await auth.registerAsSeller(
      name:             _sNameCtrl.text.trim(),
      email:            _sEmailCtrl.text.trim(),
      password:         _sPassCtrl.text,
      phone:            _sPhoneCtrl.text.trim(),
      storeName:        _storeNameCtrl.text.trim(),
      storeDescription: _storeDescCtrl.text.trim(),
      profileImage:     _sProfileUrl,
      storeLogo:        _sLogoUrl,
    );

    if (!mounted) return;

    if (success) {
      if (_sProfileUploading) _watchAndUpdate(auth, 'sProfile');
      if (_sLogoUploading)    _watchAndUpdate(auth, 'sLogo');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _snack(auth.errorMessage, color: context.colors.error);
    }
  }

  // مراقبة انتهاء الرفع وتحديث الملف الشخصي في الخلفية
  void _watchAndUpdate(AuthProvider auth, String target) {
    Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!mounted) { t.cancel(); return; }
      final uploading = target == 'cProfile' ? _cUploading
          : (target == 'sProfile' ? _sProfileUploading : _sLogoUploading);
      if (uploading) return;
      t.cancel();
      String? url;
      if      (target == 'cProfile' && _cProfileUrl.isNotEmpty) {url = _cProfileUrl;}
      else if (target == 'sProfile' && _sProfileUrl.isNotEmpty) { url = _sProfileUrl; }
      else if (target == 'sLogo'    && _sLogoUrl.isNotEmpty)   {url = _sLogoUrl;} 
      if (url != null) {
        if (target == 'sLogo') { auth.updateProfile(storeLogo: url); }
        else { auth.updateProfile(profileImage: url); }
      }
    });
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: color,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin:          const EdgeInsets.all(12),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller:           _tabCtrl,
          indicatorColor:       Colors.white,
          labelColor:           Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'مشتري', icon: Icon(Icons.shopping_bag_outlined)),
            Tab(text: 'بائع',  icon: Icon(Icons.store_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children:   [_buildCustomerForm(), _buildSellerForm()],
      ),
    );
  }

  Widget _buildCustomerForm() {
    final colors = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _cFormKey,
        child: Column(
          children: [
            const SizedBox(height: 8),
            _ImagePickerTile(
              file:     _cProfileFile,
              progress: _cProfileProgress,
              label:    'صورة شخصية (اختيارية)',
              isCircle: true,
              onTap:    _cUploading ? null : () => _pickAndUpload(target: 'cProfile'),
            ),
            const SizedBox(height: 20),
            _field(_cNameCtrl,  'الاسم الكامل',      Icons.person_outlined),
            const SizedBox(height: 16),
            _field(_cEmailCtrl, 'البريد الإلكتروني', Icons.email_outlined,
                type: TextInputType.emailAddress, ltr: true),
            const SizedBox(height: 16),
            _field(_cPhoneCtrl, 'رقم الهاتف',         Icons.phone_outlined,
                type: TextInputType.phone),
            const SizedBox(height: 16),
            _passField(_cPassCtrl, _cObscure,
                () => setState(() => _cObscure = !_cObscure)),
            if (_cUploading) ...[
              const SizedBox(height: 8),
            Text('الصورة لا تزال ترفع — ستُضاف تلقائياً.',
                  style: TextStyle(fontSize: 12, color: colors.warning,
                      fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            Consumer<AuthProvider>(
              builder: (_, auth, __) => ElevatedButton(
                onPressed: auth.isLoading ? null : _registerCustomer,
                child: auth.isLoading
                    ? const SizedBox(height: 22, width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('إنشاء حساب مشتري'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerForm() {
    final colors = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _sFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'المعلومات الشخصية'),
            const SizedBox(height: 16),
            _ImagePickerTile(
              file:     _sProfileFile,
              progress: _sProfileProgress,
              label:    'صورة شخصية (اختيارية)',
              isCircle: true,
              onTap:    _sProfileUploading ? null : () => _pickAndUpload(target: 'sProfile'),
            ),
            const SizedBox(height: 16),
            _field(_sNameCtrl,  'الاسم الكامل',      Icons.person_outlined),
            const SizedBox(height: 16),
            _field(_sEmailCtrl, 'البريد الإلكتروني', Icons.email_outlined,
                type: TextInputType.emailAddress, ltr: true),
            const SizedBox(height: 16),
            _field(_sPhoneCtrl, 'رقم الهاتف',         Icons.phone_outlined,
                type: TextInputType.phone),
            const SizedBox(height: 16),
            _passField(_sPassCtrl, _sObscure,
                () => setState(() => _sObscure = !_sObscure)),
            const SizedBox(height: 28),
            _sectionTitle(context, 'معلومات المتجر'),
            const SizedBox(height: 16),
            _ImagePickerTile(
              file:     _sLogoFile,
              progress: _sLogoProgress,
              label:    'شعار المتجر (اختياري)',
              isCircle: false,
              onTap:    _sLogoUploading ? null : () => _pickAndUpload(target: 'sLogo'),
            ),
            const SizedBox(height: 16),
            _field(_storeNameCtrl, 'اسم المتجر', Icons.store_outlined),
            const SizedBox(height: 16),
            TextFormField(
              controller: _storeDescCtrl,
              maxLines:   3,
              decoration: const InputDecoration(
                labelText:          'وصف المتجر (اختياري)',
                prefixIcon:         Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
            ),
            if (_sProfileUploading || _sLogoUploading) ...[
              const SizedBox(height: 8),
            Text('الصور لا تزال ترفع — ستُضاف تلقائياً.',
                  style: TextStyle(fontSize: 12, color: colors.warning,
                      fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            Consumer<AuthProvider>(
              builder: (_, auth, __) => ElevatedButton(
                onPressed: auth.isLoading ? null : _registerSeller,
                child: auth.isLoading
                    ? const SizedBox(height: 22, width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('إنشاء حساب بائع'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String t) => Text(t,
      style: TextStyle(fontWeight: FontWeight.bold,
          color: context.colors.primary, fontSize: 15));

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text, bool ltr = false}) {
    return TextFormField(
      controller:    ctrl,
      keyboardType:  type,
      textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
      decoration:    InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (v) {
        final val = v?.trim() ?? '';
        if (val.isEmpty) return 'هذا الحقل مطلوب';
        if (label.contains('بريد') && !val.contains('@')) {
          return 'بريد إلكتروني غير صحيح';
        }
        return null;
      },
    );
  }

  Widget _passField(TextEditingController ctrl, bool obscure, VoidCallback toggle) {
    return TextFormField(
      controller:    ctrl,
      obscureText:   obscure,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText:  'كلمة المرور',
        prefixIcon: const Icon(Icons.lock_outlined),
        suffixIcon: IconButton(
          icon: Icon(obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: toggle,
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'أدخل كلمة المرور';
        if (v.length < 6) return 'كلمة المرور قصيرة (6 أحرف على الأقل)';
        return null;
      },
    );
  }
}

// ── Image Picker Widget ────────────────────────────────────────────────────────
class _ImagePickerTile extends StatelessWidget {
  final File?         file;
  final double        progress;
  final String        label;
  final bool          isCircle;
  final VoidCallback? onTap;

  const _ImagePickerTile({
    required this.file, required this.progress, required this.label,
    required this.isCircle, required this.onTap,
  });

  bool get _uploading => progress >= 0 && progress < 1;
  bool get _succeeded => progress == -3 || progress >= 1;
  bool get _failed    => progress == -2;
  int  get _percent   => _uploading ? (progress * 100).round() : (_succeeded ? 100 : 0);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(children: [
      GestureDetector(
        onTap: _uploading ? null : onTap,
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            _preview(colors),
            if (!_uploading)
              Container(
                padding:    const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _succeeded ? colors.success
                      : (_failed ? colors.error : colors.primary),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _succeeded ? Icons.check : (_failed ? Icons.refresh : Icons.camera_alt),
                  size: 14, color: Colors.white,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (_uploading) ...[
        SizedBox(
          width: isCircle ? 100 : 90,
          child: Column(children: [
            Text('$_percent%',
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.bold, color: colors.primary)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress, minHeight: 6,
                backgroundColor: colors.border,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text('جاري الرفع...',
                style: TextStyle(fontSize: 11, color: colors.textSecondary)),
          ]),
        ),
      ] else ...[
        Text(
          _succeeded ? '✅ تم الرفع' : (_failed ? '❌ فشل — اضغط للإعادة' : label),
          style: TextStyle(
            fontSize:   12,
            color:      _succeeded ? colors.success
                : (_failed ? colors.error : colors.textSecondary),
            fontWeight: (_succeeded || _failed) ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    ]);
  }

  Widget _preview(SougaColors colors) {
    if (isCircle) {
      return CircleAvatar(
        radius: 45,
        backgroundColor: colors.primary.withValues(alpha: 0.1),
        backgroundImage: file != null ? FileImage(file!) : null,
        child: file == null
            ? Icon(Icons.person_outlined, size: 38,
                color: colors.primary.withValues(alpha: 0.7))
            : null,
      );
    }
    return Container(
      width: 88, height: 88,
      decoration: BoxDecoration(
        color:        colors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: colors.border),
        image:        file != null
            ? DecorationImage(image: FileImage(file!), fit: BoxFit.cover)
            : null,
      ),
      child: file == null
          ? Icon(Icons.store_outlined, size: 34,
              color: colors.primary.withValues(alpha: 0.6))
          : null,
    );
  }
}
