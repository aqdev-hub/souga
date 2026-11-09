// lib/services/chat_service.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import 'push_notification_service.dart';

class ChatService {
  static final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// معرّف غرفة المحادثة بين مستخدمَين (ثابت بغض النظر عن الترتيب)
  static String roomId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// إنشاء أو جلب غرفة محادثة
  static Future<String> getOrCreateRoom({
    required String myUid,
    required String myName,
    required String myImage,
    required String otherUid,
    required String otherName,
    required String otherImage,
  }) async {
    final id = roomId(myUid, otherUid);
    final ref = _fs.collection('chat_rooms').doc(id);
    final doc = await ref.get();

    if (!doc.exists) {
      await ref.set({
        'participants':       [myUid, otherUid],
        'participantNames':   {myUid: myName,  otherUid: otherName},
        'participantImages':  {myUid: myImage, otherUid: otherImage},
        'lastMessage':        '',
        'lastMessageTime':    FieldValue.serverTimestamp(),
        'unreadCount':        {myUid: 0, otherUid: 0},
        'createdAt':          FieldValue.serverTimestamp(),
      });
    }

    return id;
  }

  /// إرسال رسالة
  static Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    required String text,
    required String receiverId,
  }) async {
    final batch = _fs.batch();

    // الرسالة
    final msgRef = _fs
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc();

    batch.set(msgRef, {
      'senderId':   senderId,
      'senderName': senderName,
      'text':       text.trim(),
      'timestamp':  FieldValue.serverTimestamp(),
      'read':       false,
    });

    // تحديث الغرفة
    final roomRef = _fs.collection('chat_rooms').doc(roomId);
    batch.update(roomRef, {
      'lastMessage':                  text.trim(),
      'lastMessageTime':              FieldValue.serverTimestamp(),
      'unreadCount.$receiverId':      FieldValue.increment(1),
    });

    await batch.commit();

    // ✅ إشعار نظام للطرف الآخر برسالة جديدة (بدون انتظار ولا تعطيل الإرسال)
    final preview = text.trim();
    unawaited(PushNotificationService.sendToUser(
      userId: receiverId,
      title: senderName.isEmpty ? 'رسالة جديدة' : senderName,
      body: preview.length > 120 ? '${preview.substring(0, 120)}…' : preview,
      type: 'chat',
      referenceId: roomId,
    ));
  }

  /// تعليم الرسائل كمقروءة
  static Future<void> markRead({
    required String roomId,
    required String myUid,
  }) async {
    await _fs.collection('chat_rooms').doc(roomId).update({
      'unreadCount.$myUid': 0,
    });

    // تعليم الرسائل غير المقروءة الموجهة لي
    final unread = await _fs
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .where('read', isEqualTo: false)
        .where('senderId', isNotEqualTo: myUid)
        .get();

    final batch = _fs.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    if (unread.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  /// Stream للرسائل
  static Stream<List<ChatMessage>> messagesStream(String roomId) {
    return _fs
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessage.fromMap(d.data(), d.id))
            .toList());
  }

  /// Stream لغرفة واحدة (لمعرفة وقت مسح المحتوى عندي).
  static Stream<ChatRoom?> roomStream(String roomId) {
    return _fs.collection('chat_rooms').doc(roomId).snapshots().map(
        (d) => d.exists && d.data() != null ? ChatRoom.fromMap(d.data()!, d.id) : null);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  ✅ حذف/مسح بأسلوب واتساب — كله "لدي أنا" عبر حقول على المستندات،
  //  فلا يحتاج تعديل قواعد Firestore (update مسموح للمشاركين أصلاً).
  // ═══════════════════════════════════════════════════════════════════

  /// حذف رسائل من عندي فقط.
  static Future<void> deleteMessagesForMe({
    required String roomId,
    required List<String> ids,
    required String myUid,
  }) async {
    for (var i = 0; i < ids.length; i += 400) {
      final batch = _fs.batch();
      for (final id in ids.skip(i).take(400)) {
        batch.update(
          _fs.collection('chat_rooms').doc(roomId).collection('messages').doc(id),
          {'deletedFor': FieldValue.arrayUnion([myUid])},
        );
      }
      await batch.commit();
    }
  }

  /// حذف رسائلي للجميع (يُستدعى لرسائل المستخدم نفسه فقط من الواجهة).
  static Future<void> deleteMessagesForEveryone({
    required String roomId,
    required List<String> ids,
    bool lastMessageAffected = false,
  }) async {
    for (var i = 0; i < ids.length; i += 400) {
      final batch = _fs.batch();
      for (final id in ids.skip(i).take(400)) {
        batch.update(
          _fs.collection('chat_rooms').doc(roomId).collection('messages').doc(id),
          {'deletedForAll': true, 'text': ''},
        );
      }
      await batch.commit();
    }
    if (lastMessageAffected) {
      await _fs.collection('chat_rooms').doc(roomId)
          .update({'lastMessage': 'تم حذف هذه الرسالة'});
    }
  }

  /// مسح محتوى محادثة (أو عدة محادثات) عندي: تبقى في القائمة بلا رسائل.
  static Future<void> clearRooms({
    required List<String> roomIds,
    required String myUid,
  }) async {
    final batch = _fs.batch();
    for (final id in roomIds) {
      batch.update(_fs.collection('chat_rooms').doc(id), {
        'clearedAt.$myUid': FieldValue.serverTimestamp(),
        'unreadCount.$myUid': 0,
      });
    }
    await batch.commit();
  }

  /// حذف محادثة (أو عدة محادثات) من قائمتي: تُمسح وتُخفى حتى تصلني رسالة جديدة.
  static Future<void> deleteRooms({
    required List<String> roomIds,
    required String myUid,
  }) async {
    final batch = _fs.batch();
    for (final id in roomIds) {
      batch.update(_fs.collection('chat_rooms').doc(id), {
        'clearedAt.$myUid': FieldValue.serverTimestamp(),
        'hiddenAt.$myUid': FieldValue.serverTimestamp(),
        'unreadCount.$myUid': 0,
      });
    }
    await batch.commit();
  }

  /// Stream لقائمة المحادثات
  static Stream<List<ChatRoom>> roomsStream(String uid) {
    return _fs
        .collection('chat_rooms')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatRoom.fromMap(d.data(), d.id))
            .toList());
  }

  /// إجمالي الرسائل غير المقروءة
  static Stream<int> totalUnreadStream(String uid) {
    return roomsStream(uid).map(
      (rooms) => rooms.fold(0, (int acc, r) => acc + r.myUnread(uid)),
    );
  }
}
