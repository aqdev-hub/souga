// lib/models/chat_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool read;
  /// ✅ "حذف لدي": معرّفات المستخدمين الذين حذفوا الرسالة من عندهم فقط.
  final List<String> deletedFor;
  /// ✅ "حذف للجميع": أرسلها صاحبها وحذفها للطرفين (يُعرض أثرها "تم حذف هذه الرسالة").
  final bool deletedForAll;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.read,
    this.deletedFor = const [],
    this.deletedForAll = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    final ts = map['timestamp'];
    DateTime time;
    if (ts is Timestamp) {
      time = ts.toDate();
    } else if (ts is DateTime) {
      time = ts;
    } else {
      time = DateTime.now();
    }
    return ChatMessage(
      id:         id,
      senderId:   (map['senderId']   ?? '').toString(),
      senderName: (map['senderName'] ?? '').toString(),
      text:       (map['text']       ?? '').toString(),
      timestamp:  time,
      read:       map['read'] == true,
      deletedFor: (map['deletedFor'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      deletedForAll: map['deletedForAll'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'senderId':   senderId,
    'senderName': senderName,
    'text':       text,
    'timestamp':  FieldValue.serverTimestamp(),
    'read':       read,
  };
}

class ChatRoom {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String> participantImages;
  final String lastMessage;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCount;
  /// ✅ لكل مستخدم: وقت "مسح المحتوى" — الرسائل الأقدم منه مخفيّة عنده فقط.
  final Map<String, DateTime> clearedAt;
  /// ✅ لكل مستخدم: وقت "حذف المحادثة" — تُخفى من قائمته حتى تصله رسالة أحدث.
  final Map<String, DateTime> hiddenAt;

  const ChatRoom({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.participantImages,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    this.clearedAt = const {},
    this.hiddenAt = const {},
  });

  static Map<String, DateTime> _tsMap(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry(
        k.toString(), v is Timestamp ? v.toDate() : DateTime.now())); // null = serverTimestamp معلّق
  }

  /// محادثة محذوفة عندي ولم تصلني رسالة أحدث منذ حذفها.
  bool isHiddenFor(String uid) {
    final h = hiddenAt[uid];
    return h != null && !lastMessageTime.isAfter(h);
  }

  /// وقت آخر "مسح محتوى" عندي (الرسائل قبله مخفية).
  DateTime? clearedFor(String uid) => clearedAt[uid];

  /// آخر رسالة في الغرفة مخفية عندي (بعد مسح/حذف)؟ — فلا تُعرض كمعاينة.
  bool previewHiddenFor(String uid) {
    final c = clearedAt[uid];
    return c != null && !lastMessageTime.isAfter(c);
  }

  factory ChatRoom.fromMap(Map<String, dynamic> map, String id) {
    final ts = map['lastMessageTime'];
    DateTime time;
    if (ts is Timestamp) {
      time = ts.toDate();
    } else {
      time = DateTime.now();
    }

    final names  = (map['participantNames']  as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v.toString())) ?? {};
    final images = (map['participantImages'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v.toString())) ?? {};
    final unread = (map['unreadCount'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, (v as num).toInt())) ?? {};

    return ChatRoom(
      id:                id,
      participants:      List<String>.from(map['participants'] ?? []),
      participantNames:  names,
      participantImages: images,
      lastMessage:       (map['lastMessage'] ?? '').toString(),
      lastMessageTime:   time,
      unreadCount:       unread,
      clearedAt:         _tsMap(map['clearedAt']),
      hiddenAt:          _tsMap(map['hiddenAt']),
    );
  }

  /// اسم ظاهر للطرف الآخر
  String otherName(String myUid) {
    final other = participants.firstWhere((p) => p != myUid, orElse: () => '');
    return participantNames[other] ?? 'مستخدم';
  }

  /// صورة الطرف الآخر
  String otherImage(String myUid) {
    final other = participants.firstWhere((p) => p != myUid, orElse: () => '');
    return participantImages[other] ?? '';
  }

  /// عدد الرسائل غير المقروءة للمستخدم الحالي
  int myUnread(String myUid) => unreadCount[myUid] ?? 0;
}
