// lib/screens/admin/admin_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/update_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/theme_mode_sheet.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) { return const SizedBox(); }
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي — المدير')),
      body: ListView(padding: const EdgeInsets.all(16), children: [

        // ── بطاقة المدير ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.primaryDark, const Color(0xFF6A0024)],
              begin: Alignment.topRight,
              end:   Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white24,
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'M',
                style: const TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.name, style: const TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(user.email, style: TextStyle(color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color:        Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('مدير النظام',
                    style: TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ])),
          ]),
        ),
        const SizedBox(height: 20),

        // ── المظهر ────────────────────────────────────────────────────────
        _section(context, 'المظهر', [themeModeTile(context)]),
        const SizedBox(height: 8),

        // ── التحديثات ─────────────────────────────────────────────────────
        _section(context, 'التحديثات والنظام', [
          _AdminUpdateTile(),
          _tile(context,
            icon:  Icons.info_outline,
            title: 'معلومات الإصدار',
            subtitle: 'الإصدار ${AppUpdateService.currentVersion} — بناء ${AppUpdateService.currentBuild}',
            onTap: () => _showVersionInfo(context),
          ),
        ]),
        const SizedBox(height: 8),

        // ── حساب المدير ───────────────────────────────────────────────────
        _section(context, 'الحساب', [
          _tile(context,
            icon:  Icons.lock_outline,
            title: 'تغيير كلمة المرور',
            onTap: () => _resetPassword(context, user.email),
          ),
        ]),
        const SizedBox(height: 8),

        // ── سياسة الخصوصية وشروط الاستخدام ──────────────────────────────
        _section(context, 'عام', [
          _tile(context,
            icon:  Icons.privacy_tip_outlined,
            title: 'سياسة الخصوصية',
            onTap: () => _showPolicy(context, 'privacy'),
          ),
          _tile(context,
            icon:  Icons.article_outlined,
            title: 'شروط الاستخدام',
            onTap: () => _showPolicy(context, 'terms'),
          ),
        ]),
        const SizedBox(height: 8),

        _tile(context,
          icon:  Icons.logout,
          title: 'تسجيل الخروج',
          color: colors.error,
          onTap: () => _logout(context),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  // ── Widget helpers ──────────────────────────────────────────────────────
  Widget _section(BuildContext context, String title, List<Widget> tiles) {
    final colors = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 6),
        child: Text(title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
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
    required IconData     icon,
    required String       title,
    String?               subtitle,
    Color?                color,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap:        onTap,
      child: ListTile(
        leading:  Icon(icon, color: color ?? colors.primaryDark, size: 22),
        title:    Text(title, style: TextStyle(
            color: color ?? colors.textPrimary, fontSize: 14)),
        subtitle: subtitle != null
            ? Text(subtitle, style: TextStyle(
                fontSize: 12, color: colors.textSecondary))
            : null,
        trailing: Icon(Icons.arrow_forward_ios, size: 14,
            color: colors.textHint),
      ),
    );
  }

  // ── تغيير كلمة المرور ────────────────────────────────────────────────────
  void _resetPassword(BuildContext context, String email) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Text('سيُرسل رابط التغيير إلى:\n$email'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
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

  // ── معلومات الإصدار ──────────────────────────────────────────────────────
  void _showVersionInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('معلومات الإصدار'),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          _infoRow('الإصدار', AppUpdateService.currentVersion),
          _infoRow('رقم البناء', AppUpdateService.currentBuild.toString()),
          _infoRow('التطبيق', 'Souga — سوجا'),
        ]),
        actions: [TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'))],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold,
            fontSize: 13)),
        Text(value, style: const TextStyle(fontSize: 13,
            color: Colors.grey)),
      ]),
    );
  }

  // ── سياسة الخصوصية / شروط الاستخدام ─────────────────────────────────────
  void _showPolicy(BuildContext context, String type) {
    final isPrivacy = type == 'privacy';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isPrivacy ? 'سياسة الخصوصية' : 'شروط الاستخدام'),
        content: SingleChildScrollView(child: Text(
          isPrivacy
              ? 'نحن نحترم خصوصيتك ونلتزم بحماية بياناتك الشخصية.\n\n'
                '• لا نشارك بياناتك مع أطراف ثالثة.\n'
                '• تُحفظ البيانات بأمان على Firebase.\n'
                '• يمكنك حذف حسابك وبياناتك في أي وقت.'
              : 'باستخدام سوجا، توافق على:\n\n'
                '• عدم نشر محتوى مخالف للقانون أو الآداب العامة.\n'
                '• الالتزام بصحة المعلومات والأسعار المعلنة.\n'
                '• احترام حقوق البائعين والمشترين الآخرين.',
          style: const TextStyle(height: 1.7, fontSize: 14),
        )),
        actions: [TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'))],
      ),
    );
  }

  // ── تسجيل الخروج ─────────────────────────────────────────────────────────
  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
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

// ── Tile خاص للتحديث ────────────────────────────────────────────────────
class _AdminUpdateTile extends StatefulWidget {
  @override
  State<_AdminUpdateTile> createState() => _AdminUpdateTileState();
}

class _AdminUpdateTileState extends State<_AdminUpdateTile> {
  bool _checking = false;
  String _status = 'تحقق من توفر تحديثات';

  Future<void> _check() async {
    setState(() { _checking = true; _status = 'جاري التحقق...'; });
    final info = await AppUpdateService.checkForUpdate();
    if (!mounted) { return; }
    if (info == null) {
      setState(() { _checking = false; _status = '✅ أنت تستخدم أحدث إصدار'; });
    } else {
      setState(() { _checking = false; _status = '🔔 تحديث ${info.newVersion} متاح!'; });
      showDialog(
        context: context,
        builder: (_) => _UpdateDialog(info: info),
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
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.system_update_outlined, color: colors.primaryDark),
        title:    const Text('التحقق من التحديثات', style: TextStyle(fontSize: 14)),
        subtitle: Text(_status, style: TextStyle(fontSize: 12,
            color: colors.textSecondary)),
        trailing: Icon(Icons.arrow_forward_ios, size: 14,
            color: colors.textHint),
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  const _UpdateDialog({required this.info});
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.primaryDark.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.system_update, color: colors.primaryDark)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('تحديث جديد', style: TextStyle(fontSize: 16)),
          Text('الإصدار ${widget.info.newVersion}',
              style: TextStyle(fontSize: 12, color: colors.textSecondary)),
        ]),
      ]),
      content: widget.info.releaseNotes.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: colors.textHint.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(widget.info.releaseNotes,
                  style: const TextStyle(fontSize: 13)))
          : null,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('لاحقاً')),
        ElevatedButton.icon(
          onPressed: widget.info.downloadUrl.isEmpty ? null : () async {
            setState(() => _loading = true);
            final ok = await AppUpdateService.openDownloadUrl(widget.info.downloadUrl);
            if (!context.mounted) { return; }
            if (!ok) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('تعذر فتح رابط التحديث'),
                  backgroundColor: colors.error));
            }
            setState(() => _loading = false);
            if (ok) { Navigator.pop(context); }
          },
          icon: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.download_outlined, size: 18),
          label: Text(_loading ? 'جاري...' : 'تحديث الآن'),
          style: ElevatedButton.styleFrom(backgroundColor: colors.primaryDark),
        ),
      ],
    );
  }
}
