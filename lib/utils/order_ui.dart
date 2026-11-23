// lib/utils/order_ui.dart
//
// ✅ ألوان/أيقونات/نصوص حالات الطلب في مكان واحد (كانت مكررة في 3 شاشات).

import 'package:flutter/material.dart';
import '../models/order_model.dart';
import 'app_colors.dart';

class OrderUi {
  OrderUi._();

  static Color statusColor(SougaColors c, OrderModel o) {
    switch (o.status) {
      case OrderModel.pending:
        return o.awaitingBuyerPayment ? c.textSecondary : c.warning;
      case OrderModel.confirmed:
        return c.info;
      case OrderModel.shipped:
        return c.primary;
      case OrderModel.delivered:
      case OrderModel.completed:
        return c.success;
      case OrderModel.cancelled:
      case OrderModel.deliveryFailed:
        return c.error;
      case OrderModel.disputed:
        return c.warning;
      default:
        return c.textSecondary;
    }
  }

  static IconData statusIcon(OrderModel o) {
    switch (o.status) {
      case OrderModel.pending:
        return o.awaitingBuyerPayment ? Icons.payments_outlined : Icons.hourglass_empty;
      case OrderModel.confirmed:
        return Icons.inventory_2_outlined;
      case OrderModel.shipped:
        return Icons.local_shipping_outlined;
      case OrderModel.delivered:
        return Icons.done_all;
      case OrderModel.completed:
        return Icons.verified_outlined;
      case OrderModel.cancelled:
        return Icons.cancel_outlined;
      case OrderModel.deliveryFailed:
        return Icons.assignment_return_outlined;
      case OrderModel.disputed:
        return Icons.gavel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  static String money(double v, String symbol) {
    final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return '$s $symbol';
  }

  /// "قبل 5 د" / "بعد 3 س" — لعرض المهل بشكل بشري.
  static String remaining(DateTime? due) {
    if (due == null) return '';
    final d = due.difference(DateTime.now());
    if (d.isNegative) return 'انتهت المهلة';
    if (d.inMinutes < 60) return 'تنتهي بعد ${d.inMinutes.clamp(1, 59)} دقيقة';
    if (d.inHours < 24) return 'تنتهي بعد ${d.inHours} ساعة';
    return 'تنتهي بعد ${d.inDays} يوم';
  }

  static String dateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  static const Map<String, String> disputeReasons = {
    'not_received': 'لم أستلم الطلب',
    'damaged': 'المنتج تالف',
    'not_as_described': 'يختلف عن الوصف',
    'missing_items': 'ناقص / ناقصة قطع',
    'other': 'سبب آخر',
  };

  static const Map<String, String> failReasons = {
    'refused': 'رفض المشتري الاستلام',
    'unreachable': 'لم يرد على الهاتف',
    'wrong_address': 'العنوان غير صحيح',
    'other': 'سبب آخر',
  };

  static SnackBar snack(BuildContext context, String msg, {bool error = false}) {
    final c = context.colors;
    return SnackBar(
      content: Text(msg),
      backgroundColor: error ? c.error : c.success,
    );
  }
}
