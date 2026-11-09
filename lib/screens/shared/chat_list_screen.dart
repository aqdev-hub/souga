// lib/screens/shared/chat_list_screen.dart
//
// قائمة المحادثات — بحث + تحديد متعدد بأسلوب واتساب:
//   • ضغطة مطوّلة على محادثة تبدأ وضع التحديد، ثم الضغط يضيف/يزيل.
//   • "تحديد الكل" + حذف المحادثات المحدّدة أو مسح محتواها فقط.
//   • الحذف/المسح "لدي أنا" فقط (الطرف الآخر لا يتأثر)، وتعود المحادثة
//     المحذوفة للظهور تلقائياً عند وصول رسالة جديدة.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/imagekit_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/search_text.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  String _query = '';
  final Set<String> _selected = {};
  List<ChatRoom> _visibleRooms = const []; // آخر قائمة ظاهرة (لـ "تحديد الكل")

  bool get _selecting => _selected.isNotEmpty;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggle(String roomId) {
    setState(() {
      if (!_selected.add(roomId)) _selected.remove(roomId);
    });
  }

  void _selectAll() {
    setState(() {
      if (_selected.length == _visibleRooms.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_visibleRooms.map((r) => r.id));
      }
    });
  }

  Future<void> _confirmAndRun({
    required String uid,
    required bool delete,
  }) async {
    final colors = context.colors;
    final count = _selected.length;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(delete
            ? (count == 1 ? 'حذف المحادثة' : 'حذف $count محادثات')
            : (count == 1 ? 'مسح محتوى المحادثة' : 'مسح محتوى $count محادثات')),
        content: Text(delete
            ? 'ستُحذف من قائمتك ويُمسح محتواها عندك فقط. لن يتأثر الطرف الآخر، وتعود المحادثة للظهور إذا وصلتك رسالة جديدة.'
            : 'ستُمسح كل الرسائل عندك فقط وتبقى المحادثة في القائمة. لن يتأثر الطرف الآخر.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(delete ? 'حذف' : 'مسح', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final ids = _selected.toList();
    try {
      if (delete) {
        await ChatService.deleteRooms(roomIds: ids, myUid: uid);
      } else {
        await ChatService.clearRooms(roomIds: ids, myUid: uid);
      }
      if (mounted) setState(_selected.clear);
      messenger.showSnackBar(SnackBar(
        content: Text(delete ? 'تم حذف المحادثات' : 'تم مسح محتوى المحادثات'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('تعذّر تنفيذ العملية: $e'),
        backgroundColor: colors.error,
      ));
    }
  }

  PreferredSizeWidget _appBar(String uid) {
    if (_selecting) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'إلغاء التحديد',
          onPressed: () => setState(_selected.clear),
        ),
        title: Text('${_selected.length} محدد'),
        actions: [
          IconButton(
            icon: Icon(_selected.length == _visibleRooms.length && _visibleRooms.isNotEmpty
                ? Icons.deselect
                : Icons.select_all),
            tooltip: 'تحديد الكل',
            onPressed: _selectAll,
          ),
          PopupMenuButton<String>(
            tooltip: 'المزيد',
            onSelected: (v) => _confirmAndRun(uid: uid, delete: v == 'delete'),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline), title: Text('حذف المحادثة'))),
              PopupMenuItem(value: 'clear', child: ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.cleaning_services_outlined), title: Text('مسح المحتوى'))),
            ],
          ),
        ],
      );
    }
    if (_searching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _searching = false;
            _query = '';
            _searchCtrl.clear();
          }),
        ),
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: 'ابحث بالاسم أو نص الرسالة...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            border: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _query = '';
                _searchCtrl.clear();
              }),
            ),
        ],
      );
    }
    return AppBar(
      title: const Text('المحادثات'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'بحث في المحادثات',
          onPressed: () => setState(() => _searching = true),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final colors = context.colors;
    if (user == null || user.uid == 'guest') {
      return const Scaffold(
        body: Center(child: Text('يجب تسجيل الدخول أولاً')),
      );
    }

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: _appBar(user.uid),
        body: StreamBuilder<List<ChatRoom>>(
          stream: ChatService.roomsStream(user.uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // المحادثات المحذوفة عندي تُخفى حتى تصلني رسالة أحدث
            final all = (snap.data ?? []).where((r) => !r.isHiddenFor(user.uid)).toList();
            final q = normalizeSearch(_query);
            final rooms = q.isEmpty
                ? all
                : all.where((r) =>
                    searchMatches(r.otherName(user.uid), q) ||
                    (!r.previewHiddenFor(user.uid) && searchMatches(r.lastMessage, q))).toList();
            _visibleRooms = rooms;

            if (all.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: colors.textHint),
                    const SizedBox(height: 16),
                    Text('لا توجد محادثات بعد',
                        style: TextStyle(color: colors.textSecondary, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('تواصل مع البائعين من صفحة المنتج',
                        style: TextStyle(color: colors.textHint, fontSize: 13)),
                  ],
                ),
              );
            }
            if (rooms.isEmpty) {
              return Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.search_off_rounded, size: 64, color: colors.textHint),
                  const SizedBox(height: 12),
                  Text('لا توجد نتائج مطابقة', style: TextStyle(color: colors.textSecondary)),
                ]),
              );
            }

            return ListView.separated(
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final room      = rooms[i];
                final otherName = room.otherName(user.uid);
                final otherImg  = room.otherImage(user.uid);
                final unread    = room.myUnread(user.uid);
                final time      = _formatTime(room.lastMessageTime);
                final isSel     = _selected.contains(room.id);
                final preview   = room.previewHiddenFor(user.uid) || room.lastMessage.isEmpty
                    ? 'ابدأ المحادثة...'
                    : room.lastMessage;

                return ListTile(
                  selected: isSel,
                  selectedTileColor: colors.primary.withValues(alpha: 0.10),
                  leading: Stack(clipBehavior: Clip.none, children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colors.primary.withValues(alpha: 0.15),
                      backgroundImage: otherImg.isNotEmpty
                          ? NetworkImage(ImageKitService.avatarUrl(otherImg))
                          : null,
                      child: otherImg.isEmpty
                          ? Text(
                              otherName.isNotEmpty ? otherName[0].toUpperCase() : '؟',
                              style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    if (isSel)
                      Positioned(
                        bottom: -2, right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: colors.primary, shape: BoxShape.circle,
                            border: Border.all(color: colors.surface, width: 2),
                          ),
                          child: const Icon(Icons.check, size: 12, color: Colors.white),
                        ),
                      ),
                  ]),
                  title: Text(
                    otherName,
                    style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal),
                  ),
                  subtitle: Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unread > 0 ? colors.textPrimary : colors.textSecondary,
                      fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(time,
                          style: TextStyle(
                            fontSize: 11,
                            color: unread > 0 ? colors.primary : colors.textHint,
                          )),
                      if (unread > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Text('$unread',
                              style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ],
                    ],
                  ),
                  onLongPress: () => _toggle(room.id),
                  onTap: () {
                    if (_selecting) {
                      _toggle(room.id);
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          roomId: room.id,
                          otherName: otherName,
                          otherImage: otherImg,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
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
