// lib/screens/shared/chat_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/imagekit_service.dart';
import '../../utils/app_colors.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final colors = context.colors;
    if (user == null || user.uid == 'guest') {
      return const Scaffold(
        body: Center(child: Text('يجب تسجيل الدخول أولاً')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('المحادثات')),
      body: StreamBuilder<List<ChatRoom>>(
        stream: ChatService.roomsStream(user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snap.data ?? [];

          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children:  [
                  Icon(Icons.chat_bubble_outline,
                      size: 64, color: colors.textHint),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد محادثات بعد',
                    style: TextStyle(
                        color: colors.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تواصل مع البائعين من صفحة المنتج',
                    style: TextStyle(
                        color: colors.textHint, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount:     rooms.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final room      = rooms[i];
              final otherName = room.otherName(user.uid);
              final otherImg  = room.otherImage(user.uid);
              final unread    = room.myUnread(user.uid);
              final time      = _formatTime(room.lastMessageTime);

              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: colors.primary.withValues(alpha: 0.15),
                  backgroundImage: otherImg.isNotEmpty
                      ? NetworkImage(
                          ImageKitService.avatarUrl(otherImg))
                      : null,
                  child: otherImg.isEmpty
                      ? Text(
                          otherName.isNotEmpty
                              ? otherName[0].toUpperCase()
                              : '؟',
                          style: TextStyle(
                            color:      colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  otherName,
                  style: TextStyle(
                    fontWeight:
                        unread > 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  room.lastMessage.isNotEmpty
                      ? room.lastMessage
                      : 'ابدأ المحادثة...',
                  maxLines:  1,
                  overflow:  TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unread > 0
                        ? colors.textPrimary
                        : colors.textSecondary,
                    fontWeight:
                        unread > 0 ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(time,
                        style: TextStyle(
                          fontSize: 11,
                          color: unread > 0
                              ? colors.primary
                              : colors.textHint,
                        )),
                    if (unread > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:       colors.primary,
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      roomId:    room.id,
                      otherName: otherName,
                      otherImage: otherImg,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)   return 'الآن';
    if (diff.inHours   < 1)   return 'منذ ${diff.inMinutes}د';
    if (diff.inDays    < 1)   return 'منذ ${diff.inHours}س';
    if (diff.inDays    < 7)   return 'منذ ${diff.inDays}ي';
    return '${dt.day}/${dt.month}';
  }
}
