// lib/widgets/in_app_banner.dart
//
// بانر إشعار منبثق داخل التطبيق (على نمط فيسبوك) يظهر من أعلى الشاشة عند وصول
// إشعار والتطبيق مفتوح (نظام أندرويد لا يعرض إشعار FCM تلقائياً في هذه الحالة).
//   • ينزلق من الأعلى ويختفي تلقائياً بعد 5 ثوانٍ
//   • سحب للأعلى/للجانب لإغلاقه — النقر يفتح المحتوى
//   • واحد فقط في كل مرة (الجديد يستبدل القديم)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/deep_link_service.dart';
import '../utils/app_colors.dart';

class InAppBanner {
  InAppBanner._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show({
    required String title,
    required String body,
    String? imageUrl,
    required VoidCallback onTap,
  }) {
    final overlay = DeepLinkService.navigatorKey.currentState?.overlay;
    if (overlay == null) return;
    dismiss();
    HapticFeedback.lightImpact();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _BannerView(
        title: title, body: body, imageUrl: imageUrl,
        onTap: () { dismiss(); onTap(); },
        onDismiss: dismiss,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(seconds: 5), dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _BannerView extends StatefulWidget {
  final String title, body;
  final String? imageUrl;
  final VoidCallback onTap, onDismiss;
  const _BannerView({
    required this.title, required this.body, this.imageUrl,
    required this.onTap, required this.onDismiss,
  });

  @override
  State<_BannerView> createState() => _BannerViewState();
}

class _BannerViewState extends State<_BannerView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320))..forward();
  late final Animation<Offset> _slide = Tween(begin: const Offset(0, -1.4), end: Offset.zero)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 8, left: 12, right: 12,
      child: SlideTransition(
        position: _slide,
        child: Dismissible(
          key: UniqueKey(),
          direction: DismissDirection.up,
          onDismissed: (_) => widget.onDismiss(),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.border.withValues(alpha: 0.7)),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 22, offset: const Offset(0, 8))],
                ),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: colors.accent, width: 1.6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                        ? Image.network(widget.imageUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.notifications_active, color: Colors.white))
                        : const Icon(Icons.notifications_active, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: colors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(widget.body,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, height: 1.35, color: colors.textSecondary)),
                    ],
                  )),
                  Text('الآن', style: TextStyle(fontSize: 11, color: colors.textHint)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
