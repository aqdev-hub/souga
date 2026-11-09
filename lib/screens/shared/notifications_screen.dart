// lib/screens/shared/notifications_screen.dart
//
// ✅ إكمال الهجرة لنظام الألوان الديناميكي (SougaColors) — كانت هذه
// الشاشة من الشاشات التي بقيت على AppColors الثابت (وضع فاتح فقط)، ما كان
// يكسر الوضع الليلي فعلياً. الآن تستخدم context.colors في كل مكان.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/notifications_service.dart';
import '../../services/imagekit_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/product/product_gallery_view.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().currentUser?.uid ?? 'guest';
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          TextButton(
            onPressed: () => NotificationsService.markAllAsRead(uid),
            child: const Text('قراءة الكل', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: NotificationsService.getUserNotifications(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snap.data ?? [];
          if (notifications.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.notifications_none_outlined, size: 80, color: colors.border),
                const SizedBox(height: 16),
                Text('لا توجد إشعارات', style: TextStyle(fontSize: 16, color: colors.textSecondary)),
              ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (_, i) => _NotificationCard(notification: notifications[i]),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final color = notification.typeColor(context);
    final colors = context.colors;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => NotificationsService.delete(notification.id),
      child: GestureDetector(
        onTap: () => NotificationsService.markAsRead(notification.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notification.isRead ? colors.surface : colors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notification.isRead ? colors.border : colors.primary.withValues(alpha: 0.2),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
          ),
          child: Row(children: [
            _leading(color),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(notification.title,
                    style: TextStyle(
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                      color: colors.textPrimary,
                    ))),
                if (!notification.isRead)
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 4),
              Text(notification.body,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary)),
              const SizedBox(height: 4),
              Text(_formatTime(notification.createdAt),
                  style: TextStyle(fontSize: 11, color: colors.textHint)),
            ])),
          ]),
        ),
      ),
    );
  }

  // صورة المنتج إن وُجدت، وإلا أيقونة التطبيق، مع شارة صغيرة بنوع الإشعار.
  Widget _leading(Color color) {
    final hasImg = notification.imageUrl.isNotEmpty;
    return SizedBox(
      width: 52, height: 52,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: hasImg
                ? ProductImageFrame(
                    url: ImageKitService.thumbnailUrl(notification.imageUrl), blurBackdrop: false)
                : Image.asset('assets/images/app_icon.png', fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                          color: color.withValues(alpha: 0.12),
                          child: Icon(notification.typeIcon, color: color, size: 22),
                        )),
          ),
        ),
        PositionedDirectional(
          end: -4, bottom: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Icon(notification.typeIcon, color: Colors.white, size: 11),
          ),
        ),
      ]),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${time.day}/${time.month}/${time.year}';
  }
}
