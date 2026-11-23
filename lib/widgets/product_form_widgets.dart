// lib/widgets/product_form_widgets.dart
//
// عناصر واجهة مشتركة لشاشة إضافة/تعديل المنتج:
//   • NumberWordsHint        : الرقم المكتوب بالحروف أسفل حقل السعر/الكمية (تلقائي أثناء الكتابة)
//   • showCurrencyPicker     : قائمة العملات بحث ذكي (عربي/إنجليزي/رمز)
//   • MeasureUnitField       : حقل وحدة القياس (قائمة منسدلة ببحث)
//   • showAddValuesDialog    : إدخال عدة قيم لخاصية بوحدة واحدة (5، 7، 12 لتر) أو بلا وحدة (S, M, L)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_colors.dart';
import '../utils/arabic_number_words.dart';
import '../utils/currencies.dart';
import '../utils/currency_search.dart';
import '../utils/measure_units.dart';
import 'searchable_picker_sheet.dart';

/// يسمح بالأرقام الصحيحة فقط (لاتينية/عربية-هندية تُحوَّل إلى لاتينية).
final List<TextInputFormatter> kIntegerOnlyFormatters = [_ArabicDigitsToLatin(), FilteringTextInputFormatter.digitsOnly];

class _ArabicDigitsToLatin extends TextInputFormatter {
  static const _ai = '٠١٢٣٤٥٦٧٨٩';
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var t = newValue.text;
    if (!RegExp('[$_ai]').hasMatch(t)) return newValue;
    for (var i = 0; i < 10; i++) {
      t = t.replaceAll(_ai[i], '$i');
    }
    return newValue.copyWith(text: t);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  الرقم بالحروف أسفل الحقل
// ═══════════════════════════════════════════════════════════════════════════
class NumberWordsHint extends StatelessWidget {
  final TextEditingController controller;
  const NumberWordsHint({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, v, __) {
        final words = numberToArabicWords(v.text);
        return AnimatedSize(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.topCenter,
          child: words == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6, end: 6, top: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      words,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: colors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  منتقي العملة
// ═══════════════════════════════════════════════════════════════════════════
Future<SougaCurrency?> showCurrencyPicker(BuildContext context, {SougaCurrency? selected}) {
  return showSearchablePicker<SougaCurrency>(
    context: context,
    title: 'اختر العملة',
    hint: 'ابحث: ريال، ريال يمني، USD، \$ ...',
    items: kSougaCurrencies,
    selected: selected,
    search: searchCurrencies,
    emptyMessage: 'لا توجد عملة مطابقة للبحث',
    itemBuilder: (ctx, c, sel) {
      final colors = ctx.colors;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(children: [
          Container(
            width: 46,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Text(c.symbol, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
              if (c.en.isNotEmpty)
                Text('${c.code} · ${c.en}', textDirection: TextDirection.ltr, style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
            ]),
          ),
          if (sel) Icon(Icons.check_circle_rounded, color: colors.primary, size: 22),
        ]),
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  حقل وحدة القياس
// ═══════════════════════════════════════════════════════════════════════════
Future<MeasureUnit?> showMeasureUnitPicker(BuildContext context, {MeasureUnit? selected}) {
  return showSearchablePicker<MeasureUnit>(
    context: context,
    title: 'اختر وحدة القياس',
    hint: 'ابحث: لتر، كجم، سم، kg ...',
    items: kMeasureUnits,
    selected: selected,
    search: searchMeasureUnits,
    emptyMessage: 'لا توجد وحدة مطابقة للبحث',
    itemBuilder: (ctx, u, sel) {
      final colors = ctx.colors;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(children: [
          Container(
            constraints: const BoxConstraints(minWidth: 46),
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Text(u.symbol, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: colors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(u.ar, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: colors.textPrimary))),
          Text(u.group, style: TextStyle(fontSize: 11.5, color: colors.textHint)),
          if (sel) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle_rounded, color: colors.primary, size: 22),
          ],
        ]),
      );
    },
  );
}

class MeasureUnitField extends StatelessWidget {
  final MeasureUnit? unit;
  final ValueChanged<MeasureUnit?> onChanged;
  final String emptyText;
  const MeasureUnitField({
    super.key,
    required this.unit,
    required this.onChanged,
    this.emptyText = 'بدون وحدة (مثل S, M, L أو 38, 40)',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final u = await showMeasureUnitPicker(context, selected: unit);
        if (u != null) onChanged(u);
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(Icons.straighten_rounded, size: 20, color: unit == null ? colors.textHint : colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              unit == null ? emptyText : unit!.display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: unit == null ? colors.textHint : colors.textPrimary, fontWeight: unit == null ? FontWeight.w400 : FontWeight.w700),
            ),
          ),
          if (unit != null)
            IconButton(
              tooltip: 'بدون وحدة',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 20, color: colors.textSecondary),
              onPressed: () => onChanged(null),
            )
          else
            Icon(Icons.keyboard_arrow_down_rounded, color: colors.textSecondary),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  إدخال قيم متعددة لخاصية (وحدة واحدة × عدة قيم)
// ═══════════════════════════════════════════════════════════════════════════
class AddValuesResult {
  final MeasureUnit? unit;
  final List<String> labels; // التسميات النهائية: "5 لتر" أو "XL"
  const AddValuesResult(this.unit, this.labels);
}

Future<AddValuesResult?> showAddValuesDialog(
  BuildContext context, {
  required String attrName,
  MeasureUnit? initialUnit,
  bool allowUnit = true,
  Iterable<String> existingLabels = const [],
}) {
  return showModalBottomSheet<AddValuesResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => _AddValuesBody(
      attrName: attrName,
      initialUnit: initialUnit,
      allowUnit: allowUnit,
      existing: existingLabels.map((e) => e.trim().toLowerCase()).toSet(),
    ),
  );
}

class _AddValuesBody extends StatefulWidget {
  final String attrName;
  final MeasureUnit? initialUnit;
  final bool allowUnit;
  final Set<String> existing;
  const _AddValuesBody({required this.attrName, required this.initialUnit, required this.allowUnit, required this.existing});

  @override
  State<_AddValuesBody> createState() => _AddValuesBodyState();
}

class _AddValuesBodyState extends State<_AddValuesBody> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late MeasureUnit? _unit = widget.initialUnit;
  final List<String> _raw = []; // أرقام نظيفة (مع وحدة) أو نصوص (بدون وحدة)
  String? _msg;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _labelOf(String raw) => _unit == null ? raw : measureLabel(raw, _unit!);

  /// يُضيف كل القيم الموجودة في النص (مفصولة بفاصلة/سطر، وبمسافة أيضاً عند وجود وحدة).
  void _commit(String text) {
    final sep = _unit == null ? RegExp(r'[,،;\n]+') : RegExp(r'[,،;\s\n]+');
    final tokens = text.split(sep).map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return;
    final skipped = <String>[];
    final bad = <String>[];
    setState(() {
      for (final t in tokens) {
        String? v;
        if (_unit != null) {
          v = normalizeMeasureNumber(t);
          if (v == null) {
            bad.add(t);
            continue;
          }
        } else {
          v = t.length > 40 ? t.substring(0, 40) : t;
        }
        final label = _labelOf(v).toLowerCase();
        final dup = _raw.any((r) => _labelOf(r).toLowerCase() == label) || widget.existing.contains(label);
        if (dup) {
          skipped.add(t);
          continue;
        }
        _raw.add(v);
      }
      _ctrl.clear();
      _msg = bad.isNotEmpty
          ? 'قيمة غير صالحة: ${bad.join('، ')} (أرقام فقط، ويمكن 2.5)'
          : (skipped.isNotEmpty ? 'موجودة مسبقاً: ${skipped.join('، ')}' : null);
    });
    _focus.requestFocus();
  }

  void _changeUnit(MeasureUnit? u) {
    setState(() {
      _unit = u;
      if (u != null) {
        // مع وحدة: تبقى القيم الرقمية فقط
        final before = _raw.length;
        final keep = <String>[];
        for (final r in _raw) {
          final n = normalizeMeasureNumber(r);
          if (n != null && !keep.contains(n)) keep.add(n);
        }
        _raw
          ..clear()
          ..addAll(keep);
        _msg = _raw.length < before ? 'حُذفت القيم غير الرقمية لأن الوحدة تتطلب أرقاماً' : null;
      } else {
        _msg = null;
      }
    });
  }

  void _addPreset(List<String> values) => setState(() {
        for (final v in values) {
          if (!_raw.contains(v) && !widget.existing.contains(v.toLowerCase())) _raw.add(v);
        }
        _msg = null;
      });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final labels = [for (final r in _raw) _labelOf(r)];

    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Text('إضافة قيم — ${widget.attrName}', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: colors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            widget.allowUnit
                ? 'اختر الوحدة مرة واحدة ثم أضف أي عدد من القيم — لا تحتاج لتكرارها.'
                : 'أضف أي عدد من القيم ثم اضغط إضافة.',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 14),
          if (widget.allowUnit) ...[
            Text('وحدة القياس', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            const SizedBox(height: 6),
            MeasureUnitField(unit: _unit, onChanged: _changeUnit),
            const SizedBox(height: 14),
          ],
          Text('القيمة', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            textInputAction: TextInputAction.done,
            keyboardType: _unit == null ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: _commit,
            decoration: InputDecoration(
              hintText: _unit == null ? 'اكتب قيمة ثم Enter (أو افصل بفاصلة)' : 'مثال: 5 ثم Enter — يقبل 2.5',
              isDense: true,
              suffixIcon: IconButton(
                tooltip: 'إضافة القيمة',
                icon: Icon(Icons.add_circle_rounded, color: colors.primary, size: 26),
                onPressed: () => _commit(_ctrl.text),
              ),
            ),
          ),
          if (_msg != null) ...[
            const SizedBox(height: 6),
            Text(_msg!, style: TextStyle(fontSize: 12, color: colors.error)),
          ],
          if (_unit == null) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _PresetChip(label: 'مقاسات ملابس XS–XXL', onTap: () => _addPreset(const ['XS', 'S', 'M', 'L', 'XL', 'XXL'])),
              _PresetChip(label: 'مقاسات أحذية 36–46', onTap: () => _addPreset([for (var i = 36; i <= 46; i++) '$i'])),
            ]),
          ],
          const SizedBox(height: 14),
          if (labels.isEmpty)
            Text('لم تُضف قيم بعد', style: TextStyle(fontSize: 12.5, color: colors.textHint))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < labels.length; i++)
                _ValueChip(
                  label: labels[i],
                  onEdit: () {
                    // تعديل: تُرجع القيمة إلى الحقل وتُحذف من القائمة قبل الحفظ
                    setState(() {
                      _ctrl.text = _raw[i];
                      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
                      _raw.removeAt(i);
                    });
                    _focus.requestFocus();
                  },
                  onDelete: () => setState(() => _raw.removeAt(i)),
                ),
            ]),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء'))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_ctrl.text.trim().isNotEmpty) _commit(_ctrl.text); // قيمة مكتوبة ولم تُضَف بعد
                  if (_raw.isEmpty) return;
                  Navigator.pop(context, AddValuesResult(_unit, [for (final r in _raw) _labelOf(r)]));
                },
                icon: const Icon(Icons.check_rounded, size: 20),
                label: Text(_raw.isEmpty ? 'إضافة' : 'إضافة (${_raw.length})'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PresetChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w600)),
      avatar: Icon(Icons.bolt_rounded, size: 16, color: colors.primary),
      onPressed: onTap,
      backgroundColor: colors.primary.withValues(alpha: 0.06),
      side: BorderSide(color: colors.primary.withValues(alpha: 0.25)),
    );
  }
}

class _ValueChip extends StatelessWidget {
  final String label;
  final VoidCallback onEdit, onDelete;
  const _ValueChip({required this.label, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 2),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
          ),
        ),
        IconButton(
          tooltip: 'حذف',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          padding: EdgeInsets.zero,
          icon: Icon(Icons.close_rounded, size: 18, color: colors.error),
          onPressed: onDelete,
        ),
      ]),
    );
  }
}
