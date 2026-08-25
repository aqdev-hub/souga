// lib/models/notification_model.dart

import 'package:flutter/material.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;        // 'new_order' | 'order_status' | 'review' | 'system'
  final String referenceId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.referenceId = '',
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'system',
      referenceId: map['referenceId'] ?? '',
      isRead: map['isRead'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'title': title,
    'body': body,
    'type': type,
    'referenceId': referenceId,
    'isRead': isRead,
    'createdAt': createdAt,
  };

  IconData get typeIcon {
    switch (type) {
      case 'new_order': return Icons.shopping_bag_outlined;
      case 'order_status': return Icons.local_shipping_outlined;
      case 'review': return Icons.star_outline;
      default: return Icons.notifications_outlined;
    }
  }

  Color typeColor(BuildContext context) {
    switch (type) {
      case 'new_order': return const Color(0xFFDC143C);
      case 'order_status': return const Color(0xFF1565C0);
      case 'review': return const Color(0xFFFFB300);
      default: return const Color(0xFF757575);
    }
  }
}
