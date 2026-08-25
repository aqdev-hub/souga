// lib/services/chat_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';

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
