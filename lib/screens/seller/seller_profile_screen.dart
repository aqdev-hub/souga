// lib/screens/seller/seller_profile_screen.dart
//
//  ✅ إصلاحات هذا الإصدار:
//  1. شعار المتجر (storeLogo) منفصل تماماً عن صورة الملف الشخصي (profileImage)
//  2. الهيدر يعرض صورة البائع الشخصية + شعار المتجر في مكانه الصحيح
//  3. موقع المتجر على الخريطة بزر فتح مباشر (مجاني عبر Google Maps URL)
//  4. علامات مائية (hints) في كل الحقول

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/imagekit_service.dart';
import '../../services/update_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/theme_mode_sheet.dart';

class SellerProfileScreen extends StatelessWidget {
  const SellerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) { return const SizedBox(); }
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: Column(children: [

        // ═══════════════════════════════════════════════════════════════
        //  هيدر البائع
        //  ┌──────────────────────────────────────────┐
        //  │  [صورة شخصية]  اسم البائع               │
        //  │                البريد الإلكتروني         │
        //  │  [شعار المتجر] اسم المتجر               │
        //  └──────────────────────────────────────────┘
        // ═══════════════════════════════════════════════════════════════
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: colors.primaryGradient),
          child: Column(children: [

            // ── صورة المستخدم الشخصية ─────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // الصورة الشخصية (profileImage) — دائماً منفصلة عن شعار المتجر
              Stack(children: [
                _buildAvatar(
                  imageUrl:  user.profileImage,
                  fallback:  user.name.isNotEmpty ? user.name[0].toUpperCase() : '؟',
                  radius:    36,
                ),
                Positioned(
                  bottom: 0, left: 0,
                  child: GestureDetector(
                    onTap: () => _changeProfileImage(context),
                    child: Container(
                      padding:    const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: colors.accent, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ]),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.name.isNotEmpty ? user.name : 'اسم المستخدم',
                    style: const TextStyle(color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(user.email,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12)),
              ])),
            ]),

            const SizedBox(height: 16),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 16),

            // ── شعار المتجر + معلوماته ────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // شعار المتجر (storeLogo) — منفصل تماماً عن profileImage
              Stack(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color:        Colors.white.withValues(alpha: 0.15),
                    border:       Border.all(color: Colors.white30, width: 1.5),
                  ),
                  child: user.storeLogo.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            ImageKitService.avatarUrl(user.storeLogo),
                            fit:          BoxFit.cover,
                            errorBuilder: (_, __, ___) => _storeLogoFallback(user),
                          ),
                        )
                      : _storeLogoFallback(user),
                ),
                Positioned(
                  bottom: -2, left: -2,
                  child: GestureDetector(
                    onTap: () => _changeStoreLogo(context),
                    child: Container(
                      padding:    const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color:        Color(0xFFFFB300),
                          shape:        BoxShape.circle,
                          border:       Border.fromBorderSide(BorderSide(color: Colors.white, width: 1.5))),
                      child: const Icon(Icons.store, size: 10, color: Colors.white),
                    ),
                  ),
                ),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.storeName.isNotEmpty ? user.storeName : 'اسم المتجر',
                    style: const TextStyle(color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (user.storeLocation.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  GestureDetector(
                    onTap: () => _openStoreOnMap(user.storeLocation),
                    child: const Row(children: [
                      Icon(Icons.location_on, color: Color(0xFFFFB300), size: 13),
                      SizedBox(width: 3),
                      Text('عرض موقع المتجر على الخريطة',
                          style: TextStyle(color: Color(0xFFFFB300), fontSize: 11,
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFFFFB300))),
                    ]),
                  ),
                ],
                if (user.storeDescription.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(user.storeDescription,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11)),
                ],
              ])),
            ]),
          ]),
        ),

        // ═══════════════════════════════════════════════════════════════
        //  القائمة
        // ═══════════════════════════════════════════════════════════════
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [

          // ── إعدادات المتجر ─────────────────────────────────────────
          _section(context, 'إعدادات المتجر', [
            _tile(context,
              icon:     Icons.store_outlined,
              title:    'بيانات المتجر',
              subtitle: 'الاسم، الموقع، الوصف',
              onTap:    () => _showStoreSettings(context, user),
            ),
            _tile(context,
              icon:     Icons.image_outlined,
              title:    'شعار المتجر',
              subtitle: user.storeLogo.isNotEmpty ? 'تم رفعه ✓' : 'لم يُضف بعد',
              onTap:    () => _changeStoreLogo(context),
            ),
            if (user.storeLocation.isNotEmpty)
              _tile(context,
                icon:     Icons.map_outlined,
                title:    'عرض موقع المتجر',
                subtitle: 'فتح الموقع على خريطة Google',
                onTap:    () => _openStoreOnMap(user.storeLocation),
                color:    colors.primary,
              ),
          ]),
          const SizedBox(height: 8),

          // ── الحساب الشخصي ─────────────────────────────────────────
          _section(context, 'الحساب الشخصي', [
            _tile(context,
              icon:  Icons.person_outline,
              title: 'تعديل الاسم',
              onTap: () => _showEditName(context),
            ),
            _tile(context,
              icon:     Icons.camera_alt_outlined,
              title:    'الصورة الشخصية',
              subtitle: 'صورة بروفايل المستخدم (غير الشعار)',
              onTap:    () => _changeProfileImage(context),
            ),
            _tile(context,
              icon:  Icons.lock_outline,
              title: 'تغيير كلمة المرور',
              onTap: () => _resetPassword(context),
            ),
            _tile(context,
              icon:     Icons.phone_outlined,
              title:    'رقم الهاتف',
              subtitle: user.phone.isNotEmpty ? user.phone : 'لم يُضف بعد',
              onTap:    () => _updatePhone(context),
            ),
          ]),
          const SizedBox(height: 8),

          // ── التحديثات ─────────────────────────────────────────────
          // ── المظهر ────────────────────────────────────────────────
          _section(context, 'المظهر', [themeModeTile(context)]),
          const SizedBox(height: 8),

          _section(context, 'التحديثات', [_UpdateCheckTile()]),
          const SizedBox(height: 8),

          // ── عام ───────────────────────────────────────────────────
          _section(context, 'عام', [
            _tile(context,
              icon:  Icons.privacy_tip_outlined,
              title: 'سياسة الخصوصية',
              onTap: () => _showPolicyDialog(context, 'privacy'),
            ),
            _tile(context,
              icon:  Icons.article_outlined,
              title: 'شروط الاستخدام',
              onTap: () => _showPolicyDialog(context, 'terms'),
            ),
            _tile(context,
              icon:  Icons.help_outline,
              title: 'المساعدة والدعم',
              onTap: () => _showSupport(context),
            ),
          ]),
          const SizedBox(height: 8),

          _tile(context,
            icon:  Icons.logout,
            title: 'تسجيل الخروج',
            color: colors.error,
            onTap: () => _handleLogout(context),
          ),
        ])),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Widget Helpers
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAvatar({required String imageUrl, required String fallback, required double radius}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white24,
      backgroundImage: imageUrl.isNotEmpty
          ? NetworkImage(ImageKitService.avatarUrl(imageUrl)) : null,
      child: imageUrl.isEmpty
          ? Text(fallback, style: TextStyle(fontSize: radius * 0.7,
              color: Colors.white, fontWeight: FontWeight.bold))
          : null,
    );
  }

  Widget _storeLogoFallback(UserModel user) {
    return Center(child: Text(
      user.storeName.isNotEmpty ? user.storeName[0].toUpperCase() : '🏪',
      style: const TextStyle(color: Colors.white, fontSize: 22,
          fontWeight: FontWeight.bold),
    ));
  }

  Widget _section(BuildContext context, String title, List<Widget> tiles) {
    final colors = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 6),
        child: Text(title, style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.bold, color: colors.textHint,
            letterSpacing: 0.5)),
      ),
      Container(
        decoration: BoxDecoration(color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border)),
        child: Column(children: tiles),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _tile(BuildContext context, {
    required IconData icon, required String title,
    String? subtitle, Color? color, required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: ListTile(
        leading:  Icon(icon, color: color ?? colors.primary, size: 22),
        title:    Text(title, style: TextStyle(
            color: color ?? colors.textPrimary, fontSize: 14)),
        subtitle: subtitle != null
            ? Text(subtitle, style: TextStyle(fontSize: 12,
                color: colors.textSecondary)) : null,
        trailing: Icon(Icons.arrow_forward_ios, size: 14,
            color: colors.textHint),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  إعدادات المتجر — مع علامات مائية في كل حقل
  // ═══════════════════════════════════════════════════════════════════════
  void _showStoreSettings(BuildContext context, UserModel user) {
    final auth        = context.read<AuthProvider>();
    final nameCtrl    = TextEditingController(text: user.storeName);
    final locationCtrl= TextEditingController(text: user.storeLocation);
    final descCtrl    = TextEditingController(text: user.storeDescription);
    final colors      = context.colors;

    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      useSafeArea:        true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Drag handle
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)))),
            const Text('بيانات المتجر',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // اسم المتجر
            TextField(
              controller:  nameCtrl,
              decoration: const InputDecoration(
                labelText:  'اسم المتجر',
                hintText:   'مثال: متجر الأناقة للعطور',   // ← علامة مائية
                prefixIcon: Icon(Icons.store_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // الموقع الجغرافي
            Row(children: [
              Expanded(
                child: TextField(
                  controller:  locationCtrl,
                  keyboardType: TextInputType.text,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText:  'الموقع الجغرافي (خط العرض، خط الطول)',
                    hintText:   'مثال: 15.3694, 44.1910',   // ← علامة مائية
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // زر تحديد الموقع التلقائي
              IconButton(
                icon: Icon(Icons.my_location, color: colors.primary),
                tooltip: 'استخدام موقعي الحالي',
                onPressed: () => _getCurrentLocation(ctx, locationCtrl),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
              child: Text(
                '💡 اضغط أيقونة الموقع للتحديد التلقائي، أو أدخل الإحداثيات يدوياً.\n'
                '   للحصول على الإحداثيات: افتح Google Maps → اضغط على موقع محلك → انسخ الأرقام.',
                style: TextStyle(fontSize: 11, color: colors.textHint),
              ),
            ),

            // وصف المتجر
            TextField(
              controller: descCtrl,
              maxLines:   3,
              decoration: const InputDecoration(
                labelText:          'وصف المتجر',
                hintText:           'مثال: نبيع أجود أنواع العطور العربية والعالمية بأسعار تنافسية',
                prefixIcon:         Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final snack = ScaffoldMessenger.of(context);
                  final success = await auth.updateProfile(
                    storeName:        nameCtrl.text.trim(),
                    storeLocation:    locationCtrl.text.trim(),
                    storeDescription: descCtrl.text.trim(),
                  );
                  if (!ctx.mounted) { return; }
                  Navigator.pop(ctx);
                  snack.showSnackBar(SnackBar(
                    content: Text(success
                        ? '✅ تم حفظ بيانات المتجر' : '❌ فشل الحفظ، أعد المحاولة'),
                    backgroundColor: success ? colors.success : colors.error,
                  ));
                },
                child: const Text('حفظ البيانات'),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ── تحديد الموقع الحالي ────────────────────────────────────────────────
  Future<void> _getCurrentLocation(BuildContext context,
      TextEditingController ctrl) async {
    // استخدام geolocator package لتحديد الموقع التلقائي
    // إذا لم يكن مثبتاً نعطي تعليمات يدوية
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'لتحديد موقعك: افتح Google Maps ← اضغط طويلاً على موقعك ← انسخ الإحداثيات',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }

  // ── فتح موقع المتجر على خريطة Google ────────────────────────────────────
  Future<void> _openStoreOnMap(String location) async {
    if (location.isEmpty) { return; }
    // تنسيق: "lat,lng" أو "lat, lng"
    final clean = location.replaceAll(' ', '');
    final uri   = Uri.parse('https://maps.google.com/?q=$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // إذا فشل Google Maps → فتح OpenStreetMap (مجاني بالكامل)
      final osmUri = Uri.parse('https://www.openstreetmap.org/?mlat=${clean.split(',')[0]}&mlon=${clean.split(',').length > 1 ? clean.split(',')[1] : ''}#map=15/${clean.replaceAll(',', '/')}');
      await launchUrl(osmUri, mode: LaunchMode.externalApplication);
    }
  }

  // ── شعار المتجر ────────────────────────────────────────────────────────
  Future<void> _changeStoreLogo(BuildContext context) async {
    final source = await _pickImageSource(context);
    if (source == null || !context.mounted) { return; }
    final snack = ScaffoldMessenger.of(context);
    final successColor = context.colors.success;
    snack.showSnackBar(const SnackBar(content: Text('جاري رفع الشعار...')));
    final file = await ImageKitService.pickImage(fromCamera: source);
    if (file == null || !context.mounted) { return; }
    // ✅ يرفع كـ storeLogo وليس profileImage
    final url = await ImageKitService.uploadImage(file, 'logos');
    if (url != null && context.mounted) {
      await context.read<AuthProvider>().updateProfile(storeLogo: url);
      snack.showSnackBar(SnackBar(content: const Text('✅ تم تحديث شعار المتجر'),
          backgroundColor: successColor));
    }
  }

  // ── الصورة الشخصية ────────────────────────────────────────────────────
  Future<void> _changeProfileImage(BuildContext context) async {
    final source = await _pickImageSource(context);
    if (source == null || !context.mounted) { return; }
    final snack = ScaffoldMessenger.of(context);
    final successColor = context.colors.success;
    final file  = await ImageKitService.pickImage(fromCamera: source);
    if (file == null || !context.mounted) { return; }
    // ✅ يرفع كـ profileImage وليس storeLogo
    final url = await ImageKitService.uploadImage(file, 'profiles');
    if (url != null && context.mounted) {
      await context.read<AuthProvider>().updateProfile(profileImage: url);
      snack.showSnackBar(SnackBar(content: const Text('✅ تم تحديث الصورة الشخصية'),
          backgroundColor: successColor));
    }
  }

  Future<bool?> _pickImageSource(BuildContext context) async {
    return showModalBottomSheet<bool>(
      context: context,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: Icon(Icons.photo_library_outlined, color: context.colors.primary),
          title:   const Text('من معرض الصور'),
          onTap:   () => Navigator.pop(context, false),
        ),
        ListTile(
          leading: Icon(Icons.camera_alt_outlined, color: context.colors.primary),
          title:   const Text('من الكاميرا'),
          onTap:   () => Navigator.pop(context, true),
        ),
      ])),
    );
  }

  // ── تعديل الاسم ───────────────────────────────────────────────────────
  void _showEditName(BuildContext context) {
    final nameCtrl = TextEditingController(
        text: context.read<AuthProvider>().currentUser?.name ?? '');
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('تعديل الاسم',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'الاسم الكامل',
              hintText:  'مثال: عبدالقدوس الشيباني',   // ← علامة مائية
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) { return; }
              await context.read<AuthProvider>().updateProfile(name: nameCtrl.text.trim());
              if (!ctx.mounted) { return; }
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          )),
        ]),
      ),
    );
  }

  // ── تغيير كلمة المرور ─────────────────────────────────────────────────
  void _resetPassword(BuildContext context) {
    final email = context.read<AuthProvider>().currentUser?.email ?? '';
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Text('سيُرسل رابط التغيير إلى:\n$email'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              await context.read<AuthProvider>().resetPassword(email);
              if (!context.mounted) { return; }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('✅ تم إرسال رابط التغيير'),
                    backgroundColor: colors.success));
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  // ── تحديث الهاتف ──────────────────────────────────────────────────────
  void _updatePhone(BuildContext context) {
    final phoneCtrl = TextEditingController(
        text: context.read<AuthProvider>().currentUser?.phone ?? '');
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('رقم الهاتف',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller:   phoneCtrl,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              hintText:  '+967 7XX XXX XXX',   // ← علامة مائية
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              if (phoneCtrl.text.trim().isEmpty) { return; }
              await context.read<AuthProvider>().updateProfile(phone: phoneCtrl.text.trim());
              if (!ctx.mounted) { return; }
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          )),
        ]),
      ),
    );
  }

  // ── سياسة الخصوصية / شروط الاستخدام ─────────────────────────────────
  void _showPolicyDialog(BuildContext context, String type) {
    final isPrivacy = type == 'privacy';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isPrivacy ? 'سياسة الخصوصية' : 'شروط الاستخدام'),
        content: SingleChildScrollView(child: Text(
          isPrivacy
              ? 'نحن نحترم خصوصيتك وملتزمون بحماية بياناتك.\n\n'
                '• لا نشارك بياناتك مع أطراف ثالثة.\n'
                '• البيانات محفوظة بأمان على Firebase.\n'
                '• يمكنك حذف حسابك في أي وقت.\n'
                '• نستخدم البيانات لتحسين تجربتك فقط.'
              : 'باستخدام سوجا توافق على:\n\n'
                '• عدم نشر محتوى مخالف للقانون أو الآداب.\n'
                '• الالتزام بصحة المعلومات والأسعار.\n'
                '• احترام باقي المستخدمين.\n'
                '• نحتفظ بحق إيقاف الحسابات المخالفة.',
          style: const TextStyle(height: 1.7, fontSize: 14),
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'))],
      ),
    );
  }


  // ── دعم فني محسّن: بريد + واتساب قابلان للنقر ─────────────────────────
  void _showSupport(BuildContext context) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.support_agent_rounded,
                color: colors.primary, size: 22),
          ),
          const SizedBox(width: 10),
          const Text('الدعم الفني',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('تواصل معنا عبر:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 14),
          // ── البريد الإلكتروني ──
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              Navigator.pop(context);
              launchUrl(Uri.parse('mailto:sba849198@gmail.com?subject=دعم فني - سوجا'));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEA4335).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEA4335).withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA4335),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.mail_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('البريد الإلكتروني',
                      style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                  const Text('sba849198@gmail.com',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: Color(0xFFEA4335))),
                ])),
                Icon(Icons.arrow_forward_ios_rounded, size: 13, color: colors.textSecondary),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          // ── واتساب ──
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              Navigator.pop(context);
              launchUrl(
                Uri.parse('https://wa.me/967778942829?text=${Uri.encodeComponent('مرحباً، أحتاج دعم فني في تطبيق سوجا')}'),
                mode: LaunchMode.externalApplication,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('واتساب',
                      style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                  const Text('+967 778 942 829',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: Color(0xFF25D366))),
                ])),
                Icon(Icons.arrow_forward_ios_rounded, size: 13, color: colors.textSecondary),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Text('الرد خلال 24 ساعة',
              style: TextStyle(fontSize: 11, color: colors.textSecondary)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  // ── تسجيل الخروج ──────────────────────────────────────────────────────
  Future<void> _handleLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('خروج',
                  style: TextStyle(color: context.colors.error))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Update Check Tile
// ═══════════════════════════════════════════════════════════════════════════
class _UpdateCheckTile extends StatefulWidget {
  @override
  State<_UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends State<_UpdateCheckTile> {
  bool   _checking = false;
  String _status   = 'تحقق من توفر تحديثات';

  Future<void> _check() async {
    setState(() { _checking = true; _status = 'جاري التحقق...'; });
    final info = await AppUpdateService.checkForUpdate();
    if (!mounted) { return; }
    if (info == null) {
      setState(() { _checking = false; _status = '✅ أنت تستخدم أحدث إصدار'; });
    } else {
      setState(() { _checking = false; _status = '🔔 إصدار ${info.newVersion} متاح!'; });
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Row(children: [
            Icon(Icons.system_update, color: context.colors.primary),
            const SizedBox(width: 8),
            Text('إصدار ${info.newVersion} متاح'),
          ]),
          content: info.releaseNotes.isNotEmpty
              ? Text(info.releaseNotes) : null,
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('لاحقاً')),
            ElevatedButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                await AppUpdateService.openDownloadUrl(info.downloadUrl);
                nav.pop();
              },
              child: const Text('تحديث الآن'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _checking ? null : _check,
      child: ListTile(
        leading: _checking
            ? SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
            : Icon(Icons.system_update_outlined, color: colors.primary, size: 22),
        title:    const Text('التحقق من التحديثات',
            style: TextStyle(fontSize: 14)),
        subtitle: Text(_status,
            style: TextStyle(fontSize: 12, color: colors.textSecondary)),
        trailing: Icon(Icons.arrow_forward_ios, size: 14,
            color: colors.textHint),
      ),
    );
  }
}
