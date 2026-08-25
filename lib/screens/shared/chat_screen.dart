// lib/screens/shared/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/imagekit_service.dart';
import '../../utils/app_colors.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String otherName;
  final String otherImage;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.otherName,
    required this.otherImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl         = TextEditingController();
  final _scrollCtrl   = ScrollController();
  bool  _sending      = false;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid != null) {
      ChatService.markRead(roomId: widget.roomId, myUid: uid);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve:    Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    // نحتاج لمعرفة uid الطرف الآخر من roomId
    final parts      = widget.roomId.split('_');
    final receiverId = parts.firstWhere((p) => p != user.uid,
        orElse: () => parts.last);

    setState(() => _sending = true);
    _ctrl.clear();

    try {
      await ChatService.sendMessage(
        roomId:     widget.roomId,
        senderId:   user.uid,
        senderName: user.name,
        text:       text,
        receiverId: receiverId,
      );
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text('فشل الإرسال: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<AuthProvider>().currentUser?.uid ?? '';
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(
            radius:          18,
            backgroundColor: colors.primary.withValues(alpha: 0.15),
            backgroundImage: widget.otherImage.isNotEmpty
                ? NetworkImage(
                    ImageKitService.avatarUrl(widget.otherImage))
                : null,
            child: widget.otherImage.isEmpty
                ? Text(
                    widget.otherName.isNotEmpty
                        ? widget.otherName[0].toUpperCase()
                        : '؟',
                    style: TextStyle(
                        color:      colors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize:   14),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Text(widget.otherName,
              style: const TextStyle(fontSize: 16)),
        ]),
      ),
      body: Column(children: [
        // قائمة الرسائل
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: ChatService.messagesStream(widget.roomId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final msgs = snap.data ?? [];

              // تعليم مقروء عند وصول رسائل جديدة
              if (msgs.isNotEmpty) {
                ChatService.markRead(
                    roomId: widget.roomId, myUid: myUid);
              }

              if (msgs.isEmpty) {
                return Center(
                  child: Text(
                    'ابدأ المحادثة...',
                    style:
                        TextStyle(color: colors.textHint, fontSize: 14),
                  ),
                );
              }

              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());

              return ListView.builder(
                controller: _scrollCtrl,
                padding:    const EdgeInsets.all(12),
                itemCount:  msgs.length,
                itemBuilder: (_, i) {
                  final msg    = msgs[i];
                  final isMe   = msg.senderId == myUid;
                  final showTs = i == 0 ||
                      msgs[i].timestamp
                          .difference(msgs[i - 1].timestamp)
                          .inMinutes >
                          5;

                  return Column(
                    children: [
                      if (showTs)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _formatTs(msg.timestamp),
                            style: TextStyle(
                                fontSize:  11,
                                color:     colors.textHint),
                          ),
                        ),
                      _MessageBubble(msg: msg, isMe: isMe),
                    ],
                  );
                },
              );
            },
          ),
        ),

        // مربع الإدخال
        Container(
          decoration: BoxDecoration(
            color:   colors.surface,
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset:     const Offset(0, -2),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left:   8,
            right:  8,
            top:    8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8,
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller:  _ctrl,
                minLines:    1,
                maxLines:    4,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText:        'اكتب رسالة...',
                  border:          OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:   BorderSide.none,
                  ),
                  filled:          true,
                  fillColor:       colors.background,
                  contentPadding:  const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width:  44,
                height: 44,
                decoration: BoxDecoration(
                  color:  colors.primary,
                  shape:  BoxShape.circle,
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send,
                        color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  String _formatTs(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) {
      return 'أمس ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool        isMe;

  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin:  const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMe ? colors.primary : colors.surface,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(isMe ? 4 : 16),
            bottomRight: Radius.circular(isMe ? 16 : 4),
          ),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset:     const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color:    isMe ? Colors.white : colors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize:     MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : colors.textHint,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.read ? Icons.done_all : Icons.done,
                    size:  12,
                    color: msg.read
                        ? const Color(0xFF4FC3F7)
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
