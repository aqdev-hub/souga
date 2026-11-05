// lib/screens/customer/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/imagekit_service.dart';
import '../../services/update_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/theme_mode_sheet.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user    = context.watch<AuthProvider>().currentUser;
    if (user == null) { return const SizedBox(); }
    final isGuest = user.uid == 'guest';
    final colors  = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي'),
        actions: [
          // ── زر الإعدادات ──────────────────────────────────────────────────
          IconButton(
            icon:    const Icon(Icons.settings_outlined),
            tooltip: 'الإعدادات',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // ── هيدر الملف الشخصي ──────────────────────────────────────────────
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: colors.primaryGradient),
          child: Column(children: [
            Stack(alignment: Alignment.bottomLeft, children: [
              CircleAvatar(
                radius:          45,
                backgroundColor: Colors.white24,
                backgroundImage: user.profileImage.isNotEmpty
                    ? NetworkImage(ImageKitService.avatarUrl(user.profileImage))
                    : null,
                child: user.profileImage.isEmpty
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'م',
                        style: const TextStyle(
                            fontSize: 36, fontWeight: FontWeight.bold,
                            color: Colors.white))
                    : null,
              ),
              if (!isGuest)
                GestureDetector(
                  onTap: () => _changeProfileImage(context),
                  child: Container(
                    padding:    const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: colors.accent, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            Text(isGuest ? 'زائر' : user.name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(isGuest ? 'غير مسجل' : user.email,
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
            if (!isGuest && user.isSeller && user.storeName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color:        Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('🏪 ${user.storeName}',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
            if (isGuest) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (r) => false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side:            const BorderSide(color: Colors.white),
                ),
                child: const Text('تسجيل الدخول / إنشاء حساب'),
              ),
            ],
          ]),
        ),

        // ── قائمة الخيارات ───────────────────────────────────────────────────
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (!isGuest) ...[
              _section(context, 'حسابي', [
                _tile(context, icon: Icons.person_outline,
                    title: 'تعديل الملف الشخصي',
                    onTap: () => _showEditProfile(context)),
                _tile(context, icon: Icons.camera_alt_outlined,
                    title: 'تغيير الصورة الشخصية',
                    onTap: () => _changeProfileImage(context)),
                _tile(context, icon: Icons.lock_outline,
                    title: 'تغيير كلمة المرور',
                    onTap: () => _resetPassword(context)),
                _tile(context, icon: Icons.phone_outlined,
                    title: 'تحديث رقم الهاتف',
                    onTap: () => _updatePhone(context)),
              ]),
              const SizedBox(height: 8),
            ],

            _section(context, 'عام', [
              _tile(context, icon: Icons.settings_outlined,
                  title: 'الإعدادات',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()))),
              _tile(context, icon: Icons.info_outline,
                  title: 'عن التطبيق',
                  onTap: () => _showAbout(context)),
              _tile(context, icon: Icons.help_outline,
                  title: 'المساعدة والدعم',
                  onTap: () => _showSupport(context)),
            ]),
            const SizedBox(height: 8),

            _tile(context,
              icon:    Icons.logout,
              title:   isGuest ? 'الخروج' : 'تسجيل الخروج',
              color:   colors.error,
              onTap:   () => _handleLogout(context, isGuest),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> tiles) {
    final colors = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 6),
        child: Text(title,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold,
                color: colors.textHint, letterSpacing: 0.5)),
      ),
      Container(
        decoration: BoxDecoration(
          color:        colors.surface,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: colors.border),
        ),
        child: Column(children: tiles),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _tile(BuildContext context, {
    required IconData    icon,
    required String      title,
    String?              subtitle,
    Widget?              trailing,
    Color?               color,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final c = color ?? colors.textPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap:        onTap,
      child: ListTile(
        leading: Icon(icon, color: color ?? colors.primary, size: 22),
        title:   Text(title, style: TextStyle(color: c, fontSize: 14)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: TextStyle(fontSize: 12, color: colors.textSecondary))
            : null,
        trailing: trailing ??
            Icon(Icons.arrow_forward_ios,
                size: 14, color: colors.textHint.withValues(alpha: 0.5)),
      ),
    );
  }

  Future<void> _changeProfileImage(BuildContext context) async {
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
    if (source == null || !context.mounted) { return; }
    final file = await ImageKitService.pickImage(fromCamera: source);
    if (file == null || !context.mounted) { return; }

    final snackCtx = ScaffoldMessenger.of(context);
    final successColor = context.colors.success;
    final url = await ImageKitService.uploadImage(file, 'profiles');
    if (url != null && context.mounted) {
      await context.read<AuthProvider>().updateProfile(profileImage: url);
      snackCtx.showSnackBar(
        SnackBar(content: const Text('✅ تم تحديث الصورة'),
            backgroundColor: successColor));
    }
  }

  void _showEditProfile(BuildContext context) {
    final auth     = context.read<AuthProvider>();
    final user     = auth.currentUser!;
    final nameCtrl = TextEditingController(text: user.name);
    final storeCtrl = TextEditingController(text: user.storeName);
    final descCtrl  = TextEditingController(text: user.storeDescription);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('تعديل الملف الشخصي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'الاسم',
                  prefixIcon: Icon(Icons.person_outline))),
          if (user.isSeller) ...[
            const SizedBox(height: 12),
            TextFormField(controller: storeCtrl,
                decoration: const InputDecoration(labelText: 'اسم المتجر',
                    prefixIcon: Icon(Icons.store_outlined))),
            const SizedBox(height: 12),
            TextFormField(controller: descCtrl, maxLines: 2,
                decoration: const InputDecoration(labelText: 'وصف المتجر',
                    prefixIcon: Icon(Icons.description_outlined),
                    alignLabelWithHint: true)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final success = await auth.updateProfile(
                name:             nameCtrl.text.trim(),
                storeName:        user.isSeller ? storeCtrl.text.trim() : null,
                storeDescription: user.isSeller ? descCtrl.text.trim() : null,
              );
              if (!ctx.mounted) { return; }
              final colors = context.colors;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(success ? '✅ تم التحديث' : '❌ فشل التحديث'),
                backgroundColor: success ? colors.success : colors.error,
              ));
            },
            child: const Text('حفظ'),
          ),
        ]),
      ),
    );
  }

  void _resetPassword(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Text('سيتم إرسال رابط تغيير كلمة المرور إلى:\n${user.email}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final successColor = context.colors.success;
              await context.read<AuthProvider>().resetPassword(user.email);
              if (!context.mounted) { return; }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('✅ تم إرسال رابط التغيير'),
                    backgroundColor: successColor));
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  void _updatePhone(BuildContext context) {
    final phoneCtrl = TextEditingController(
        text: context.read<AuthProvider>().currentUser?.phone ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('تحديث رقم الهاتف',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            controller:   phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration:   const InputDecoration(labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              if (phoneCtrl.text.trim().isEmpty) { return; }
              final colors = context.colors;
              final success = await context.read<AuthProvider>()
                  .updateProfile(phone: phoneCtrl.text.trim());
              if (!ctx.mounted) { return; }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(success ? '✅ تم التحديث' : '❌ فشل التحديث'),
                backgroundColor: success ? colors.success : colors.error,
              ));
            },
            child: const Text('حفظ'),
          ),
        ]),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/images/app_icon.png', width: 32, height: 32,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.storefront_rounded, color: colors.primary))),
          const SizedBox(width: 10),
          const Text('Souga'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('سوجا - Souga',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('سوق إلكتروني يربط البائعين بالمشترين محلياً.'),
          const SizedBox(height: 12),
          _InfoRow(label: 'الإصدار',
              value: '${AppUpdateService.currentVersion} (${AppUpdateService.currentBuild})'),
          const _InfoRow(label: 'طريقة الدفع', value: 'عند الاستلام'),
          const _InfoRow(label: 'العمولة',      value: 'صفر (فترة تجريبية)'),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('حسناً'))
        ],
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
                Uri.parse('https://wa.me/967778942829?text=${Uri.encodeComponent("مرحباً، أحتاج دعم فني في تطبيق سوجا")}'),
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

  Future<void> _handleLogout(BuildContext context, bool isGuest) async {
    if (isGuest) {
      await context.read<AuthProvider>().logout();
      return;
    }
    final colors = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('خروج', style: TextStyle(color: colors.error))),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  شاشة الإعدادات
// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _arabicNumbers = true;
  bool _checkingUpdate = false;
  AppUpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    _checkUpdate(silent: true);
  }

  void _showPolicy(BuildContext ctx, String type) {
    final isP = type == 'privacy';
    showDialog(context: ctx, builder: (_) => AlertDialog(
      title: Text(isP ? 'سياسة الخصوصية' : 'شروط الاستخدام'),
      content: SingleChildScrollView(child: Text(
        isP
          ? 'نحن نحترم خصوصيتك وملتزمون بحماية بياناتك.\n\n'
            '• لا نشارك بياناتك مع أطراف ثالثة.\n'
            '• البيانات محفوظة بأمان على Firebase.\n'
            '• يمكنك حذف حسابك في أي وقت.'
          : 'باستخدام سوجا توافق على:\n\n'
            '• عدم نشر محتوى مخالف للقانون.\n'
            '• الالتزام بصحة المعلومات.\n'
            '• احترام باقي المستخدمين.',
        style: const TextStyle(height: 1.7, fontSize: 14),
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
    ));
  }

  Future<void> _checkUpdate({bool silent = false}) async {
    if (!silent) { setState(() => _checkingUpdate = true); }
    final info = await AppUpdateService.checkForUpdate();
    if (mounted) {
      setState(() {
        _updateInfo    = info;
        _checkingUpdate = false;
      });
      if (!silent && info == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('التطبيق محدَّث إلى آخر إصدار'),
            ]),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(children: [

        // ── تحديث التطبيق ──────────────────────────────────────────────────
        _sectionHeader(context, 'التطبيق'),
        _buildUpdateTile(),

        const Divider(height: 1, indent: 16, endIndent: 16),

        // إصدار التطبيق
        ListTile(
          leading:  Icon(Icons.info_outline, color: colors.primary),
          title:    const Text('الإصدار الحالي'),
          subtitle: Text('${AppUpdateService.currentVersion}'
              ' (build ${AppUpdateService.currentBuild})'),
          trailing: const SizedBox.shrink(),
        ),

        const SizedBox(height: 8),

        // ── الإشعارات ────────────────────────────────────────────────────
        _sectionHeader(context, 'الإشعارات'),
        SwitchListTile(
          secondary:    Icon(Icons.notifications_outlined, color: colors.primary),
          title:        const Text('إشعارات الطلبات'),
          subtitle:     const Text('تلقي إشعار عند وصول طلب جديد'),
          value:        _notifications,
          activeThumbColor: colors.primary,
          onChanged:    (v) => setState(() => _notifications = v),
        ),

        const SizedBox(height: 8),

        // ── المظهر ───────────────────────────────────────────────────────
        _sectionHeader(context, 'المظهر'),
        // ✅ الوضع الليلي — مفعّل الآن بثلاث حالات: فاتح / داكن / تلقائي
        themeModeTile(context),
        SwitchListTile(
          secondary:   Icon(Icons.format_list_numbered_rtl,
              color: colors.primary),
          title:       const Text('الأرقام العربية'),
          value:       _arabicNumbers,
          activeThumbColor: colors.primary,
          onChanged:   (v) => setState(() => _arabicNumbers = v),
        ),

        const SizedBox(height: 8),

        // ── الخصوصية ─────────────────────────────────────────────────────
        _sectionHeader(context, 'الخصوصية'),
        ListTile(
          leading:  Icon(Icons.privacy_tip_outlined, color: colors.primary),
          title:    const Text('سياسة الخصوصية'),
          trailing: Icon(Icons.arrow_forward_ios,
              size: 14, color: colors.textHint),
          onTap:    () => _showPolicy(context, 'privacy'),
        ),
        ListTile(
          leading:  Icon(Icons.article_outlined, color: colors.primary),
          title:    const Text('شروط الاستخدام'),
          trailing: Icon(Icons.arrow_forward_ios,
              size: 14, color: colors.textHint),
          onTap:    () => _showPolicy(context, 'terms'),
        ),

        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold,
              color: context.colors.textHint, letterSpacing: 0.5)),
    );
  }

  Widget _buildUpdateTile() {
    if (_checkingUpdate) {
      return const ListTile(
        leading: SizedBox(width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text('جارٍ التحقق من التحديثات...'),
      );
    }

    if (_updateInfo != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient:     const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1976D2)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: const Icon(Icons.system_update, color: Colors.white),
          title:   Text('تحديث متاح: ${_updateInfo!.newVersion}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: const Text('اضغط للتحديث الآن',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1565C0),
                minimumSize:     const Size(70, 32),
                padding:         const EdgeInsets.symmetric(horizontal: 12)),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => _UpdateDialog(info: _updateInfo!),
            ),
            child: const Text('تحديث', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    return ListTile(
      leading:  Icon(Icons.system_update_outlined, color: context.colors.primary),
      title:    const Text('التحقق من التحديثات'),
      subtitle: Text('الإصدار الحالي: ${AppUpdateService.currentVersion}',
          style: const TextStyle(fontSize: 12)),
      trailing: TextButton(
        onPressed: () => _checkUpdate(),
        child: Text('تحقق الآن',
            style: TextStyle(color: context.colors.primary, fontSize: 12)),
      ),
    );
  }
}


class _UpdateDialog extends StatelessWidget {
  final AppUpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Container(
          padding:    const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:        const Color(0xFF1565C0).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.system_update, color: Color(0xFF1565C0)),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('تحديث جديد', style: TextStyle(fontSize: 16)),
          Text('الإصدار ${info.newVersion}',
              style: TextStyle(fontSize: 12, color: colors.textSecondary)),
        ]),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding:    const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:        colors.textHint.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ما الجديد:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Text(info.releaseNotes.isNotEmpty
                ? info.releaseNotes : 'تحسينات وإصلاحات عامة.',
                style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          ]),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('لاحقاً')),
        ElevatedButton.icon(
          onPressed: () {
            AppUpdateService.openDownloadUrl(info.downloadUrl);
            Navigator.pop(context);
          },
          icon:  const Icon(Icons.download_outlined, size: 18),
          label: const Text('تحديث الآن'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
      Expanded(child: Text(value,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13))),
    ]);
  }
}
