// lib/widgets/order_list_tools.dart
//
// أدوات مشتركة لقوائم الطلبات الثلاث (مشتري/بائع/مدير) — بدل تكرار الكود:
//   • OrderSort + applyOrderQuery : بحث وفرز.
//   • OrderToolbar                : شريط البحث وقائمة الفرز.
//   • OrderProductsPreview        : صورة مصغّرة + اسم كل منتج في الطلب.
//   • showUndoSnack               : SnackBar مع زر "تراجع".

import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/imagekit_service.dart';
import '../utils/app_colors.dart';
import '../utils/search_text.dart';
import 'product/product_gallery_view.dart' show ProductImageFrame;
import '../utils/currencies.dart';

enum OrderSort { newest, oldest, amountHigh, amountLow, status }

extension OrderSortX on OrderSort {
  String get label {
    switch (this) {
      case OrderSort.newest:     return 'الأحدث أولاً';
      case OrderSort.oldest:     return 'الأقدم أولاً';
      case OrderSort.amountHigh: return 'الأعلى قيمة';
      case OrderSort.amountLow:  return 'الأقل قيمة';
      case OrderSort.status:     return 'حسب الحالة';
    }
  }

  IconData get icon {
    switch (this) {
      case OrderSort.newest:     return Icons.arrow_downward_rounded;
      case OrderSort.oldest:     return Icons.arrow_upward_rounded;
      case OrderSort.amountHigh: return Icons.trending_up_rounded;
      case OrderSort.amountLow:  return Icons.trending_down_rounded;
      case OrderSort.status:     return Icons.flag_outlined;
    }
  }
}

int _statusRank(String s) {
  switch (s) {
    case OrderModel.pending:   return 0;
    case OrderModel.confirmed: return 1;
    case OrderModel.shipped:   return 2;
    case OrderModel.delivered: return 3;
    case OrderModel.cancelled: return 4;
    default:                   return 5;
  }
}

bool _orderMatches(OrderModel o, String q) {
  bool m(String s) => searchMatches(s, q);
  if (m(o.id) || m(o.customerName) || m(o.customerPhone) || m(o.sellerName) ||
      m(o.statusArabic) || m(o.totalAmount.toStringAsFixed(2))) {
    return true;
  }
  for (final p in o.products) {
    if (m(p.name)) return true;
    final opts = p.variantOptions;
    if (opts != null && opts.values.any(m)) return true;
  }
  return false;
}

List<OrderModel> applyOrderQuery(
  List<OrderModel> src, {
  String query = '',
  OrderSort sort = OrderSort.newest,
}) {
  final q = normalizeSearch(query);
  final list = q.isEmpty ? List<OrderModel>.of(src) : src.where((o) => _orderMatches(o, q)).toList();
  switch (sort) {
    case OrderSort.newest:     list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); break;
    case OrderSort.oldest:     list.sort((a, b) => a.createdAt.compareTo(b.createdAt)); break;
    case OrderSort.amountHigh: list.sort((a, b) => b.totalAmount.compareTo(a.totalAmount)); break;
    case OrderSort.amountLow:  list.sort((a, b) => a.totalAmount.compareTo(b.totalAmount)); break;
    case OrderSort.status:
      list.sort((a, b) {
        final c = _statusRank(a.status).compareTo(_statusRank(b.status));
        return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
      });
      break;
  }
  return list;
}

/// شريط البحث + قائمة الفرز.
class OrderToolbar extends StatefulWidget {
  final String hint;
  final OrderSort sort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<OrderSort> onSortChanged;
  const OrderToolbar({
    super.key,
    required this.sort,
    required this.onQueryChanged,
    required this.onSortChanged,
    this.hint = 'ابحث برقم الطلب أو اسم المنتج أو العميل...',
  });

  @override
  State<OrderToolbar> createState() => _OrderToolbarState();
}

class _OrderToolbarState extends State<OrderToolbar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            onChanged: (v) {
              widget.onQueryChanged(v);
              setState(() {});
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(fontSize: 13),
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _ctrl.clear();
                        widget.onQueryChanged('');
                        setState(() {});
                      },
                    ),
              filled: true,
              fillColor: colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.border),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<OrderSort>(
          tooltip: 'فرز',
          initialValue: widget.sort,
          onSelected: widget.onSortChanged,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          itemBuilder: (_) => OrderSort.values
              .map((s) => PopupMenuItem(
                    value: s,
                    child: Row(children: [
                      Icon(s.icon, size: 18, color: s == widget.sort ? colors.primary : colors.textSecondary),
                      const SizedBox(width: 10),
                      Text(s.label,
                          style: TextStyle(
                            fontWeight: s == widget.sort ? FontWeight.bold : FontWeight.normal,
                            color: s == widget.sort ? colors.primary : null,
                          )),
                    ]),
                  ))
              .toList(),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.sort_rounded, size: 20, color: colors.primary),
              const SizedBox(width: 4),
              Text('فرز', style: TextStyle(fontSize: 12.5, color: colors.textPrimary)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// صورة مصغّرة + اسم كل منتج داخل الطلب (حتى [maxRows] ثم "+ N أخرى").
class OrderProductsPreview extends StatelessWidget {
  final OrderModel order;
  final int maxRows;
  /// يُبرز خيارات التركيبة بلون التطبيق (يفيد البائع في تجهيز الطلب).
  final bool emphasizeVariants;
  const OrderProductsPreview({
    super.key,
    required this.order,
    this.maxRows = 3,
    this.emphasizeVariants = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shown = order.products.take(maxRows).toList();
    final more = order.products.length - shown.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final p in shown)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: p.image.isNotEmpty
                  ? ProductImageFrame(
                      url: ImageKitService.thumbnailUrl(p.image),
                      width: 54, height: 54,
                      blurBackdrop: false, memCacheWidth: 160,
                      fallback: _ph(colors),
                    )
                  : _ph(colors),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text('الكمية: ${p.quantity} • ${formatMoney(p.price)} ${order.currencySymbol}',
                    style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                if (p.variantOptions != null && p.variantOptions!.isNotEmpty)
                  Text(
                    p.variantOptions!.entries.map((e) => '${e.key}: ${e.value}').join(' • '),
                    style: TextStyle(
                      fontSize: 11,
                      color: emphasizeVariants ? colors.primary : colors.textHint,
                      fontWeight: emphasizeVariants ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      if (more > 0)
        Text('+ $more منتجات أخرى في هذا الطلب',
            style: TextStyle(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _ph(SougaColors colors) => Container(
        width: 54, height: 54, color: colors.border,
        child: Icon(Icons.image_outlined, color: colors.textHint),
      );
}

/// SnackBar بزر "تراجع".
void showUndoSnack(BuildContext context, String message, Future<void> Function() onUndo) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 6),
    action: SnackBarAction(
      label: 'تراجع',
      onPressed: () {
        onUndo();
      },
    ),
  ));
}

/// رسالة "لا نتائج" موحّدة.
Widget orderEmptyState(BuildContext context, {required bool searching, required String emptyText, IconData icon = Icons.receipt_long_outlined}) {
  final colors = context.colors;
  return Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(searching ? Icons.search_off_rounded : icon, size: 72, color: colors.border),
      const SizedBox(height: 12),
      Text(searching ? 'لا توجد نتائج مطابقة للبحث' : emptyText,
          style: TextStyle(fontSize: 15, color: colors.textSecondary)),
    ]),
  );
}
