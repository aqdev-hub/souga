// lib/screens/shared/chat_screen.dart
//
// شاشة المحادثة — بحث داخل الرسائل + تحديد رسائل بأسلوب واتساب:
//   • ضغطة مطوّلة على رسالة تبدأ التحديد، ثم الضغط يضيف/يزيل، و"تحديد الكل".
//   • نسخ المحدّد، أو حذفه "لدي" (يختفي عندي فقط)، أو "للجميع" (لرسائلي فقط).
//   • من القائمة ⋮: "مسح المحادثة" يمسح كل الرسائل عندي فقط.
//   كله بحقول على المستندات — لا يحتاج تعديل قواعد Firestore.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/imagekit_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/search_text.dart';

enum _DeleteChoice { forMe, forEveryone }

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
  final _searchCtrl   = TextEditingController();
  final _scrollCtrl   = ScrollController();
  bool  _sending      = false;

  // البحث والتحديد
  bool _searching = false;
  String _query = '';
  final Set<String> _selected = {};
  List<ChatMessage> _visibleMsgs = const []; // المعروض حالياً (لـ "تحديد الكل"/النسخ)
  List<ChatMessage> _rawMsgs = const [];     // كل رسائل الغرفة (لمعرفة آخر رسالة)
  int _lastCount = -1; // لتجنّب التمرير/تعليم المقروء عند كل setState

  bool get _selecting => _selected.isNotEmpty;

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
    _searchCtrl.dispose();
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

  // ── التحديد ───────────────────────────────────────────────────────────────
  void _toggle(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  void _selectAll() {
    setState(() {
      final ids = _visibleMsgs.map((m) => m.id).toSet();
      if (_selected.length == ids.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(ids);
      }
    });
  }

  void _copySelected() {
    final texts = _visibleMsgs
        .where((m) => _selected.contains(m.id) && !m.deletedForAll)
        .map((m) => m.text)
        .toList();
    if (texts.isEmpty) return;
    Clipboard.setData(ClipboardData(text: texts.join('\n')));
    setState(_selected.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الرسائل'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _deleteSelected(String myUid) async {
    final picked = _visibleMsgs.where((m) => _selected.contains(m.id)).toList();
    if (picked.isEmpty) return;
    final colors = context.colors;
    final messenger = ScaffoldMessenger.of(context);
    // "للجميع" فقط إن كانت كل المحدّد رسائلي ولم تُحذف للجميع سابقاً
    final allMine = picked.every((m) => m.senderId == myUid && !m.deletedForAll);

    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(picked.length == 1 ? 'حذف الرسالة' : 'حذف ${picked.length} رسائل'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _DeleteChoice.forMe),
            child: const Text('حذف لدي'),
          ),
          if (allMine)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, _DeleteChoice.forEveryone),
              child: Text('حذف للجميع', style: TextStyle(color: colors.error)),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
    if (choice == null) return;

    final ids = picked.map((m) => m.id).toList();
    try {
      if (choice == _DeleteChoice.forEveryone) {
        final lastId = _rawMsgs.isNotEmpty ? _rawMsgs.last.id : null;
        await ChatService.deleteMessagesForEveryone(
          roomId: widget.roomId,
          ids: ids,
          lastMessageAffected: lastId != null && ids.contains(lastId),
        );
      } else {
        await ChatService.deleteMessagesForMe(
            roomId: widget.roomId, ids: ids, myUid: myUid);
      }
      if (mounted) setState(_selected.clear);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('تعذّر الحذف: $e'),
        backgroundColor: colors.error,
      ));
    }
  }

  Future<void> _clearChat(String myUid) async {
    final colors = context.colors;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح المحادثة'),
        content: const Text('ستُمسح كل الرسائل عندك فقط ولن يتأثر الطرف الآخر.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('مسح', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ChatService.clearRooms(roomIds: [widget.roomId], myUid: myUid);
      messenger.showSnackBar(const SnackBar(content: Text('تم مسح المحادثة')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('تعذّر المسح: $e'),
        backgroundColor: colors.error,
      ));
    }
  }

  PreferredSizeWidget _appBar(String myUid) {
    final colors = context.colors;
    if (_selecting) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'إلغاء التحديد',
          onPressed: () => setState(_selected.clear),
        ),
        title: Text('${_selected.length} محدد'),
        actions: [
          IconButton(icon: const Icon(Icons.copy_outlined), tooltip: 'نسخ', onPressed: _copySelected),
          IconButton(
            icon: Icon(_selected.length == _visibleMsgs.length && _visibleMsgs.isNotEmpty
                ? Icons.deselect
                : Icons.select_all),
            tooltip: 'تحديد الكل',
            onPressed: _selectAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'حذف',
            onPressed: () => _deleteSelected(myUid),
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
            hintText: 'ابحث في الرسائل...',
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
      title: Row(children: [
        CircleAvatar(
          radius:          18,
          backgroundColor: colors.primary.withValues(alpha: 0.15),
          backgroundImage: widget.otherImage.isNotEmpty
              ? NetworkImage(ImageKitService.avatarUrl(widget.otherImage))
              : null,
          child: widget.otherImage.isEmpty
              ? Text(
                  widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '؟',
                  style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Flexible(child: Text(widget.otherName, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16))),
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'بحث في الرسائل',
          onPressed: () => setState(() => _searching = true),
        ),
        PopupMenuButton<String>(
          tooltip: 'المزيد',
          onSelected: (_) => _clearChat(myUid),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'clear', child: ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.cleaning_services_outlined), title: Text('مسح المحادثة'))),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<AuthProvider>().currentUser?.uid ?? '';
    final colors = context.colors;

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: _appBar(myUid),
        body: Column(children: [
          // قائمة الرسائل
          Expanded(
            child: StreamBuilder<ChatRoom?>(
              stream: ChatService.roomStream(widget.roomId),
              builder: (context, roomSnap) {
                final clearedAt = roomSnap.data?.clearedFor(myUid);
                return StreamBuilder<List<ChatMessage>>(
                  stream: ChatService.messagesStream(widget.roomId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final raw = snap.data ?? [];
                    _rawMsgs = raw;
                    // رسائلي بعد استبعاد: المحذوف لدي + ما قبل آخر "مسح محتوى"
                    var msgs = raw.where((m) =>
                        !m.deletedFor.contains(myUid) &&
                        (clearedAt == null || m.timestamp.isAfter(clearedAt))).toList();
                    final total = msgs.length;

                    // تعليم مقروء/تمرير للأسفل فقط عند تغيّر عدد الرسائل (لا عند كل setState)
                    if (total != _lastCount) {
                      final firstLoad = _lastCount == -1;
                      _lastCount = total;
                      if (total > 0) {
                        ChatService.markRead(roomId: widget.roomId, myUid: myUid);
                      }
                      if (_query.isEmpty && (firstLoad || total > 0)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                      }
                    }

                    final q = normalizeSearch(_query);
                    if (q.isNotEmpty) {
                      msgs = msgs.where((m) => !m.deletedForAll && searchMatches(m.text, q)).toList();
                    }
                    _visibleMsgs = msgs;

                    if (total == 0) {
                      return Center(
                        child: Text('ابدأ المحادثة...',
                            style: TextStyle(color: colors.textHint, fontSize: 14)),
                      );
                    }
                    if (msgs.isEmpty) {
                      return Center(
                        child: Text('لا توجد رسائل مطابقة',
                            style: TextStyle(color: colors.textHint, fontSize: 14)),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding:    const EdgeInsets.all(12),
                      itemCount:  msgs.length,
                      itemBuilder: (_, i) {
                        final msg    = msgs[i];
                        final isMe   = msg.senderId == myUid;
                        final isSel  = _selected.contains(msg.id);
                        final showTs = i == 0 ||
                            msgs[i].timestamp.difference(msgs[i - 1].timestamp).inMinutes > 5;

                        return Column(
                          children: [
                            if (showTs)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  _formatTs(msg.timestamp),
                                  style: TextStyle(fontSize: 11, color: colors.textHint),
                                ),
                              ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPress: () => _toggle(msg.id),
                              onTap: _selecting ? () => _toggle(msg.id) : null,
                              child: Container(
                                color: isSel
                                    ? colors.primary.withValues(alpha: 0.14)
                                    : Colors.transparent,
                                child: _MessageBubble(msg: msg, isMe: isMe),
                              ),
                            ),
                          ],
                        );
                      },
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
                    contentPadding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ]),
      ),
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
    final deleted = msg.deletedForAll;
    return Align(
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin:  const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: deleted
              ? colors.surface
              : (isMe ? colors.primary : colors.surface),
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(isMe ? 4 : 16),
            bottomRight: Radius.circular(isMe ? 16 : 4),
          ),
          border: deleted ? Border.all(color: colors.border) : null,
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
              deleted ? '🚫 تم حذف هذه الرسالة' : msg.text,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: deleted
                    ? colors.textHint
                    : (isMe ? Colors.white : colors.textPrimary),
                fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
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
                    color: (isMe && !deleted)
                        ? Colors.white.withValues(alpha: 0.7)
                        : colors.textHint,
                  ),
                ),
                if (isMe && !deleted) ...[
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
