// lib/widgets/searchable_picker_sheet.dart
//
// قائمة اختيار منسدلة أنيقة (Bottom Sheet) بحقل بحث ذكي — تُستخدم للعملات والوحدات.
//   • تمرير سلس (ListView.builder) وارتفاع متكيّف مع الشاشة والكيبورد (لا تغطي عناصر مهمة).
//   • نتيجة واحدة محددة ← تُختار تلقائياً بعد توقف الكتابة قليلاً ثم تُغلق القائمة.
//   • عدة نتائج ← تُعرض كلها. لا نتائج ← رسالة واضحة.
//   • اختيار عنصر واحد فقط ثم تُغلق القائمة.

import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

Future<T?> showSearchablePicker<T>({
  required BuildContext context,
  required String title,
  required String hint,
  required List<T> items,
  required List<T> Function(String query) search,
  required Widget Function(BuildContext context, T item, bool selected) itemBuilder,
  T? selected,
  bool autoPickSingle = true,
  String emptyMessage = 'لا توجد نتائج مطابقة',
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => _PickerBody<T>(
      title: title,
      hint: hint,
      items: items,
      search: search,
      itemBuilder: itemBuilder,
      selected: selected,
      autoPickSingle: autoPickSingle,
      emptyMessage: emptyMessage,
    ),
  );
}

class _PickerBody<T> extends StatefulWidget {
  final String title, hint, emptyMessage;
  final List<T> items;
  final List<T> Function(String) search;
  final Widget Function(BuildContext, T, bool) itemBuilder;
  final T? selected;
  final bool autoPickSingle;

  const _PickerBody({
    required this.title,
    required this.hint,
    required this.items,
    required this.search,
    required this.itemBuilder,
    required this.selected,
    required this.autoPickSingle,
    required this.emptyMessage,
  });

  @override
  State<_PickerBody<T>> createState() => _PickerBodyState<T>();
}

class _PickerBodyState<T> extends State<_PickerBody<T>> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  late List<T> _results = widget.items;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    final r = q.trim().isEmpty ? widget.items : widget.search(q);
    setState(() => _results = r);
    _debounce?.cancel();
    if (widget.autoPickSingle && q.trim().isNotEmpty && r.length == 1) {
      // نتيجة واحدة محددة: نختارها بعد توقف الكتابة (لا نقطع من يكمل الكتابة).
      _debounce = Timer(const Duration(milliseconds: 450), () {
        if (mounted && _results.length == 1) Navigator.pop(context, _results.first);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final h = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: SizedBox(
        height: (h * 0.72).clamp(320.0, 640.0),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(width: 42, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(children: [
              Expanded(child: Text(widget.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colors.textPrimary))),
              IconButton(
                tooltip: 'إغلاق',
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: colors.textSecondary),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              autofocus: false,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _ctrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          _ctrl.clear();
                          _onChanged('');
                        },
                      ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.search_off_rounded, size: 44, color: colors.textHint),
                        const SizedBox(height: 10),
                        Text(widget.emptyMessage, style: TextStyle(color: colors.textSecondary, fontSize: 14)),
                      ]),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: colors.divider),
                    itemBuilder: (ctx, i) {
                      final item = _results[i];
                      final isSel = widget.selected != null && widget.selected == item;
                      return InkWell(
                        onTap: () => Navigator.pop(ctx, item),
                        child: widget.itemBuilder(ctx, item, isSel),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
