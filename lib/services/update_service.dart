// lib/services/update_service.dart
//
//  ═══════════════════════════════════════════════════════════════
//  كيف يعمل نظام التحديث بشكل صحيح:
//
//  1. هذا الملف يحتوي على _currentBuildNumber = رقم بناء النسخة المثبتة حالياً
//  2. Firestore يحتوي على buildNumber = رقم بناء آخر إصدار متاح
//  3. إذا Firestore.buildNumber > _currentBuildNumber → يظهر التحديث
//
//  المشكلة التي كانت تحدث:
//  كنت تُحدّث Firestore إلى buildNumber=2 لكن الكود لا يزال عنده buildNumber=1
//  فعند تثبيت التطبيق يبقى الكود عنده buildNumber=1 → يظهر التحديث دائماً
//
//  الحل الصحيح:
//  عند رفع نسخة جديدة من التطبيق:
//  A) غيّر _currentBuildNumber هنا ليساوي ما في Firestore
//  B) بنّي APK جديداً وارفعه على GitHub Releases
//  C) ثم غيّر downloadUrl في Firestore ليشير للـ APK الجديد
//
//  مثال عملي:
//  - الآن: _currentBuildNumber = 1, Firestore.buildNumber = 1 → لا تحديث ✓
//  - عند إصدار نسخة جديدة:
//    * غيّر هنا: _currentBuildNumber = 2
//    * ابنِ APK جديداً
//    * في Firestore: buildNumber = 3 (دائماً أعلى من الكود بواحد)
//    * المستخدمون القدامى (عندهم 2) سيروا: "تحديث 3 متاح"
//  ═══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  // ⚠️ هذا الرقم يمثّل رقم بناء هذه النسخة المثبتة على الهاتف
  // عند رفع نسخة جديدة: غيّر هذا الرقم ليطابق ما ستضعه في Firestore ثم ابنِ APK
  static const String _currentVersion     = '1.2.0';
  static const int    _currentBuildNumber = 5;
  // ────────────────────────────────────────────────────────────
  // إعداد Firestore الصحيح الآن:
  // version: "1.0.1", buildNumber: 2 → لا تحديث (متطابق)
  // ────────────────────────────────────────────────────────────

  static final FirebaseFirestore _fs = FirebaseFirestore.instance;

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
      final newBuild    = (data['buildNumber']   as num?)?.toInt() ?? 0;
      final downloadUrl = (data['downloadUrl']   ?? '').toString();
      final notes       = (data['releaseNotes']  ?? '').toString();
      final isForced    = data['forceUpdate']    == true;

      debugPrint('[Update] Firestore build=$newBuild, Current build=$_currentBuildNumber');

      // يظهر التحديث فقط إذا كان الرقم في Firestore أكبر
      if (newBuild <= _currentBuildNumber) {
        debugPrint('[Update] No update needed.');
        return null;
      }

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

// Banner
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
    if (info != null && mounted) {
      setState(() => _info = info);
      if (info.isForced) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showDialog(context: context, barrierDismissible: false,
                builder: (_) => _UpdateDialog(info: info, forced: true));
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_info == null || _dismissed || _info!.isForced) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)])),
      child: Row(children: [
        const Icon(Icons.system_update_outlined, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('تحديث جديد: الإصدار ${_info!.newVersion}',
            style: const TextStyle(color: Colors.white, fontSize: 13))),
        TextButton(
          onPressed: () => showDialog(context: context,
              builder: (_) => _UpdateDialog(info: _info!)),
          child: const Text('تحديث', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        GestureDetector(
          onTap: () => setState(() => _dismissed = true),
          child: const Icon(Icons.close, color: Colors.white60, size: 16)),
      ]),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  final bool forced;
  const _UpdateDialog({required this.info, this.forced = false});
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF1565C0).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.system_update, color: Color(0xFF1565C0))),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('تحديث جديد', style: TextStyle(fontSize: 16)),
          Text('الإصدار ${widget.info.newVersion}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF757575))),
        ]),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.info.releaseNotes.isNotEmpty)
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ما الجديد:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Text(widget.info.releaseNotes,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF616161))),
            ])),
        if (widget.forced) ...[
          const SizedBox(height: 12),
          const Row(children: [
            Icon(Icons.info_outline, color: Color(0xFFF57C00), size: 14),
            SizedBox(width: 4),
            Expanded(child: Text('هذا التحديث مطلوب للاستمرار.',
                style: TextStyle(fontSize: 11, color: Color(0xFFF57C00)))),
          ]),
        ],
      ]),
      actions: [
        if (!widget.forced)
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('لاحقاً')),
        ElevatedButton.icon(
          onPressed: widget.info.downloadUrl.isEmpty ? null : () async {
            setState(() => _loading = true);
            final ok = await AppUpdateService.openDownloadUrl(widget.info.downloadUrl);
            if (!context.mounted) { return; }
            if (!ok) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('تعذر فتح رابط التحديث.'),
                  backgroundColor: Color(0xFFDC143C)));
            }
            setState(() => _loading = false);
            if (!widget.forced && ok) { Navigator.pop(context); }
          },
          icon: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.download_outlined, size: 18),
          label: Text(_loading ? 'جاري...' : 'تحديث الآن'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
        ),
      ],
    );
  }
}
