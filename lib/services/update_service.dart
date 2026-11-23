// lib/services/update_service.dart
//
//  ═══════════════════════════════════════════════════════════════
//  نظام التحديث
//
//  • رقم النسخة المثبّتة يُقرأ تلقائياً من التطبيق نفسه (package_info_plus =
//    version/build من pubspec.yaml) — لا حاجة لتعديل رقم يدوياً داخل الكود.
//  • Firestore: المستند app_config/version
//        version        : "1.3.0"      نص يُعرض للمستخدم
//        buildNumber    : 6            آخر بناء متاح (رقم بعد + في pubspec)
//        downloadUrl    : "https://…apk"
//        releaseNotes   : "سطر لكل ميزة"   (كل سطر يظهر كنقطة)
//        forceUpdate    : false        true = تحديث إجباري
//        minBuildNumber : 4            (اختياري) أي بناء أقل منه يُجبَر على التحديث
//  • يظهر تحديث متاح إذا buildNumber > البناء المثبّت.
//  • النافذة المنبثقة تظهر تلقائياً لكل المستخدمين (زائر/مشتري/بائع/مدير):
//    بعد الإقلاع بثوانٍ، وعند العودة للتطبيق (بحدّ أدنى 6 ساعات بين فحصين).
//    "لاحقاً" تُسكِت التذكير 24 ساعة لنفس البناء. الإجباري لا يُسكَت.
//  ⚠️ يجب أن يطابق `version:` في pubspec.yaml البناء الذي ترفعه (مثال
//     version: 1.3.0+6) وإلا ظهر التحديث لمن ثبّتها فعلاً.
//  ═══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_colors.dart';
import 'deep_link_service.dart';

class AppUpdateService {
  // قيم احتياطية فقط إن تعذّرت قراءة معلومات الحزمة
  static String _currentVersion     = '1.3.1';
  static int    _currentBuildNumber = 7;

  static final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// يُستدعى مرة واحدة في main() قبل runApp.
  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) _currentVersion = info.version;
      final b = int.tryParse(info.buildNumber);
      if (b != null && b > 0) _currentBuildNumber = b;
    } catch (e) {
      debugPrint('[Update] PackageInfo error (using fallback): $e');
    }
  }

  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final doc = await _fs
          .collection('app_config')
          .doc('version')
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists || doc.data() == null) { return null; }

      final data        = doc.data()!;
      final newVersion  = (data['version']      ?? '').toString();
      final newBuild    = (data['buildNumber']  as num?)?.toInt() ?? 0;
      final minBuild    = (data['minBuildNumber'] as num?)?.toInt() ?? 0;
      final downloadUrl = (data['downloadUrl']  ?? '').toString();
      final notes       = (data['releaseNotes'] ?? '').toString();
      final isForced    = data['forceUpdate'] == true ||
                          (minBuild > 0 && _currentBuildNumber < minBuild);

      debugPrint('[Update] remote build=$newBuild, current=$_currentBuildNumber');

      if (newBuild <= _currentBuildNumber) { return null; }

      return AppUpdateInfo(
        newVersion:   newVersion,
        newBuild:     newBuild,
        downloadUrl:  downloadUrl,
        releaseNotes: notes,
        isForced:     isForced,
      );
    } catch (e) {
      debugPrint('[Update] check error: $e');
      return null;
    }
  }

  static Future<bool> openDownloadUrl(String url) async {
    if (url.isEmpty) {
      debugPrint('[Update] downloadUrl is empty');
      return false;
    }
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      debugPrint('[Update] launchUrl=$launched');
      return launched;
    } catch (e) {
      debugPrint('[Update] launch error: $e');
      try {
        return await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
      } catch (_) { return false; }
    }
  }

  // ── "لاحقاً": إسكات 24 ساعة لنفس البناء ────────────────────────────────
  static String _snoozeKey(int build) => 'update_snooze_until_$build';

  static Future<bool> isSnoozed(int build) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final until = sp.getInt(_snoozeKey(build)) ?? 0;
      return DateTime.now().millisecondsSinceEpoch < until;
    } catch (_) { return false; }
  }

  static Future<void> snooze(int build, {Duration duration = const Duration(hours: 24)}) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_snoozeKey(build),
          DateTime.now().add(duration).millisecondsSinceEpoch);
    } catch (_) {}
  }

  static String get currentVersion => _currentVersion;
  static int    get currentBuild   => _currentBuildNumber;
}

class AppUpdateInfo {
  final String newVersion;
  final int    newBuild;
  final String downloadUrl;
  final String releaseNotes;
  final bool   isForced;

  const AppUpdateInfo({
    required this.newVersion,
    required this.newBuild,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isForced,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
//  UpdateGate — يلفّ التطبيق كله (في MaterialApp.builder) ويعرض نافذة التحديث
//  تلقائياً لأي مستخدم. لا يغيّر الواجهة نفسها إطلاقاً.
// ═════════════════════════════════════════════════════════════════════════════
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  static const _recheckEvery = Duration(hours: 6);
  DateTime? _lastCheck;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // نترك الشاشة الأولى تستقر (Splash/تسجيل الدخول) قبل أي نافذة.
    Future.delayed(const Duration(seconds: 4), _check);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastCheck;
    if (last == null || DateTime.now().difference(last) >= _recheckEvery) {
      _check();
    }
  }

  Future<void> _check() async {
    if (_showing || !mounted) return;
    _lastCheck = DateTime.now();
    final info = await AppUpdateService.checkForUpdate();
    if (info == null || !mounted) return;
    if (!info.isForced && await AppUpdateService.isSnoozed(info.newBuild)) return;

    final ctx = DeepLinkService.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    _showing = true;
    try {
      await showDialog<void>(
        context: ctx,
        barrierDismissible: !info.isForced,
        builder: (_) => AppUpdateDialog(info: info),
      );
    } finally {
      _showing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ═════════════════════════════════════════════════════════════════════════════
//  AppUpdateDialog — نافذة التحديث (هوية سوجا). الإجباري لا يُغلَق.
// ═════════════════════════════════════════════════════════════════════════════
class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  const AppUpdateDialog({super.key, required this.info});

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _opening = false;

  Future<void> _update() async {
    setState(() => _opening = true);
    final ok = await AppUpdateService.openDownloadUrl(widget.info.downloadUrl);
    if (!mounted) return;
    setState(() => _opening = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('تعذّر فتح رابط التحديث. حاول لاحقاً.'),
        backgroundColor: context.colors.error,
      ));
    } else if (!widget.info.isForced) {
      Navigator.pop(context);
    }
  }

  Future<void> _later() async {
    await AppUpdateService.snooze(widget.info.newBuild);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final info = widget.info;
    final notes = info.releaseNotes
        .split('\n')
        .map((l) => l.trim().replaceFirst(RegExp(r'^[-•*]\s*'), ''))
        .where((l) => l.isNotEmpty)
        .toList();

    return PopScope(
      canPop: !info.isForced,
      child: AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.primaryDark],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update_alt_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 14),
            Text(info.isForced ? 'تحديث مطلوب' : 'تحديث جديد متاح',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
            const SizedBox(height: 6),
            Text('من ${AppUpdateService.currentVersion} إلى ${info.newVersion}',
                style: TextStyle(fontSize: 13, color: colors.textSecondary)),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ما الجديد',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary)),
                  const SizedBox(height: 8),
                  for (final n in notes.take(8))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.check_circle_rounded, size: 15, color: colors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(n,
                              style: TextStyle(
                                  fontSize: 12.5, height: 1.4, color: colors.textSecondary)),
                        ),
                      ]),
                    ),
                ]),
              ),
            ],
            if (info.isForced) ...[
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.info_outline, color: colors.warning, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('هذا التحديث مطلوب للاستمرار في استخدام التطبيق.',
                      style: TextStyle(fontSize: 12, color: colors.warning)),
                ),
              ]),
            ],
          ]),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_opening || info.downloadUrl.isEmpty) ? null : _update,
              icon: _opening
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded, size: 20),
              label: Text(_opening ? 'جاري الفتح...' : 'تحديث الآن'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          if (!info.isForced)
            TextButton(
              onPressed: _later,
              child: Text('لاحقاً', style: TextStyle(color: colors.textSecondary)),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  UpdateBanner — شريط علوي (يستخدمه المدير). يفتح نفس النافذة الموحّدة.
// ═════════════════════════════════════════════════════════════════════════════
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});
  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  AppUpdateInfo? _info;
  bool _dismissed = false;

  @override
  void initState() { super.initState(); _check(); }

  Future<void> _check() async {
    final info = await AppUpdateService.checkForUpdate();
    if (info != null && mounted) setState(() => _info = info);
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    // الإجباري تتولاه النافذة التلقائية (UpdateGate)، فلا شريط له.
    if (info == null || _dismissed || info.isForced) return const SizedBox.shrink();
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.primaryDark, colors.primary]),
      ),
      child: Row(children: [
        const Icon(Icons.system_update_outlined, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text('تحديث جديد: الإصدار ${info.newVersion}',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
        TextButton(
          onPressed: () => showDialog<void>(
              context: context, builder: (_) => AppUpdateDialog(info: info)),
          child: const Text('تحديث',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        GestureDetector(
          onTap: () => setState(() => _dismissed = true),
          child: const Icon(Icons.close, color: Colors.white60, size: 16),
        ),
      ]),
    );
  }
}
