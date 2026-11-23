// lib/widgets/attribute_manager_sheet.dart
//
// ✅ إدارة الخصائص (القسم 2): نافذة إدارة خاصية، الألوان الجاهزة + إنشاء لون،
// الخصائص الجاهزة، المفضلات، وسؤال حفظ المفضلة. كلها تعمل على المتحكم مباشرة
// (حفظ/تحميل/تحديث حقيقي) وبأيقونات متوسطة الحجم موحّدة لكل أنواع الخصائص.

import 'package:flutter/material.dart';

import '../controllers/add_edit_product_controller.dart';
import '../models/attribute_favorite.dart';
import '../models/attribute_model.dart';
import '../utils/app_colors.dart';
import '../utils/measure_units.dart';
import '../utils/ready_colors.dart';
import 'color_picker_dialog.dart';
import 'product_form_widgets.dart';

const double _kIcon = 22;

Color _hexColor(String? hex) => Color(hexToArgb(hex) ?? 0xFF9E9E9E);

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// سؤال الحفظ في المفضلة (نعم/لا). يعيد true عند "نعم".
Future<bool> askSaveToFavorites(BuildContext context, {required bool isColor}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('حفظ في المفضلة'),
      content: Text(isColor
          ? 'هل ترغب بحفظ هذا اللون في مفضلاتك لاستخدامه لاحقًا في هذه الفئة؟'
          : 'هل ترغب بحفظ هذه الخاصية في مفضلاتك لاستخدامها لاحقًا في هذه الفئة؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('نعم')),
      ],
    ),
  );
  return r == true;
}

Future<void> promptSaveAttributeFavorite(BuildContext context, AddEditProductController c, String attrKey) async {
  if (!await askSaveToFavorites(context, isColor: false)) return;
  final ok = await c.saveAttributeToFavorites(attrKey);
  if (context.mounted) _snack(context, ok ? 'تم الحفظ في مفضلاتك' : 'تعذّر الحفظ في المفضلة');
}

/// ينشئ لوناً جديداً عبر المنتقي ويضيفه ويختاره، ثم يسأل عن حفظه في المفضلة.
Future<void> createNewColor(BuildContext context, AddEditProductController c, String attrKey) async {
  final picked = await showColorPickerDialog(context);
  if (picked == null || !context.mounted) return;
  final n = c.addColors(attrKey, [ReadyColor(picked.name, picked.hex)]);
  if (n == 0) _snack(context, 'هذا اللون موجود بالفعل');
  if (!context.mounted) return;
  if (await askSaveToFavorites(context, isColor: true)) {
    final ok = await c.saveColorToFavorites(picked.name, picked.hex);
    if (context.mounted) _snack(context, ok ? 'تم حفظ اللون في مفضلاتك' : 'تعذّر الحفظ في المفضلة');
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  الألوان الجاهزة
// ───────────────────────────────────────────────────────────────────────────
Future<void> showReadyColorsSheet(BuildContext context, AddEditProductController c, String attrKey) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => _ReadyColorsBody(controller: c, attrKey: attrKey, parentContext: context),
  );
}

class _ReadyColorsBody extends StatefulWidget {
  final AddEditProductController controller;
  final String attrKey;
  final BuildContext parentContext;
  const _ReadyColorsBody({required this.controller, required this.attrKey, required this.parentContext});

  @override
  State<_ReadyColorsBody> createState() => _ReadyColorsBodyState();
}

class _ReadyColorsBodyState extends State<_ReadyColorsBody> {
  final Set<String> _picked = {}; // hex

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = widget.controller;
    final attr = c.attributeByKey(widget.attrKey);
    final existingHex = <String>{
      if (attr != null)
        for (final v in c.optionValuesFor(attr))
          if (c.isVariantValueSelected(widget.attrKey, v.id) && v.hex != null) v.hex!.toUpperCase(),
    };
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(children: [
            const Expanded(child: Text('ألوان جاهزة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            TextButton.icon(
              onPressed: () async {
                final parent = widget.parentContext;
                Navigator.pop(context);
                await createNewColor(parent, c, widget.attrKey);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إنشاء لون جديد'),
            ),
          ]),
        ),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            shrinkWrap: true,
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final rc in kReadyColors)
                  Builder(builder: (_) {
                    final already = existingHex.contains(rc.hex.toUpperCase());
                    final sel = _picked.contains(rc.hex) || already;
                    return GestureDetector(
                      onTap: already ? null : () => setState(() => sel ? _picked.remove(rc.hex) : _picked.add(rc.hex)),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                        decoration: BoxDecoration(
                          color: sel ? colors.primary.withValues(alpha: 0.10) : null,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: sel ? colors.primary : colors.border, width: sel ? 1.6 : 1),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _hexColor(rc.hex),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black26),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(rc.name, style: const TextStyle(fontSize: 12.5)),
                          if (already) ...[const SizedBox(width: 4), Icon(Icons.check, size: 14, color: colors.primary)],
                        ]),
                      ),
                    );
                  }),
              ]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _picked.isEmpty
                  ? null
                  : () {
                      final chosen = [for (final rc in kReadyColors) if (_picked.contains(rc.hex)) rc];
                      c.addColors(widget.attrKey, chosen);
                      Navigator.pop(context);
                    },
              child: Text(_picked.isEmpty ? 'اختر ألواناً' : 'إضافة ${_picked.length} لون'),
            ),
          ),
        ),
      ]),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  الخصائص الجاهزة
// ───────────────────────────────────────────────────────────────────────────
Future<void> showReadyAttributesSheet(BuildContext context, AddEditProductController c) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) {
      final colors = ctx.colors;
      return ListenableBuilder(
        listenable: c,
        builder: (ctx, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 2),
            child: Text('خصائص جاهزة شائعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('تُضاف مع قيمها المعبّأة، ويمكنك تعديلها أو حذفها بعد الإضافة',
                style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final t in kReadyAttributeTemplates)
                Builder(builder: (_) {
                  final exists = c.attributeByKey(t.name) != null;
                  return ListTile(
                    title: Text(t.name),
                    subtitle: Text(
                      t.values.isEmpty ? (t.kind == 'measure' ? 'قياس بوحدة' : 'أضف القيم بنفسك') : t.values.join('، '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: exists
                        ? Icon(Icons.check_circle, color: colors.primary, size: _kIcon)
                        : Icon(Icons.add_circle_outline, color: colors.primary, size: _kIcon),
                    onTap: exists
                        ? null
                        : () {
                            final r = c.addAttributeWithValues(t.name, t.kind, t.values);
                            if (r.error != null) {
                              _snack(ctx, r.error!);
                            } else {
                              Navigator.pop(ctx);
                            }
                          },
                  );
                }),
              const SizedBox(height: 12),
            ]),
          ),
        ]),
      );
    },
  );
}

// ───────────────────────────────────────────────────────────────────────────
//  المفضلات
// ───────────────────────────────────────────────────────────────────────────
Future<void> showFavoritesSheet(BuildContext context, AddEditProductController c) {
  c.loadFavorites();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) {
      final colors = ctx.colors;
      return ListenableBuilder(
        listenable: c,
        builder: (ctx, _) {
          final favs = c.favorites;
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 2),
              child: Text('مفضلاتي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('خاصة بك وبهذه الفئة الرئيسية فقط — لا تُضاف للمنتج إلا باختيارك',
                  style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
            ),
            if (c.loadingFavorites)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (c.favoritesError != null)
              Padding(padding: const EdgeInsets.all(20), child: Text(c.favoritesError!, style: TextStyle(color: colors.error)))
            else if (favs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('لا توجد مفضلات بعد في هذه الفئة', style: TextStyle(color: colors.textHint))),
              )
            else
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final f in favs)
                    ListTile(
                      leading: f.isColor
                          ? Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _hexColor(f.hex),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black26),
                              ),
                            )
                          : Icon(Icons.bookmark_outline, color: colors.primary, size: _kIcon),
                      title: Text(f.name),
                      subtitle: f.isColor
                          ? null
                          : Text(f.values.map((v) => v.label).join('، '),
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: 'إضافة للمنتج',
                          icon: Icon(Icons.add_circle_outline, color: colors.primary, size: _kIcon),
                          onPressed: () {
                            final err = c.applyFavorite(f);
                            _snack(ctx, err ?? 'تمت الإضافة');
                          },
                        ),
                        IconButton(
                          tooltip: 'حذف من المفضلة',
                          icon: Icon(Icons.delete_outline, color: colors.error, size: _kIcon),
                          onPressed: () => c.deleteFavorite(f),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 12),
                ]),
              ),
          ]);
        },
      );
    },
  );
}

// ───────────────────────────────────────────────────────────────────────────
//  نافذة إدارة خاصية واحدة
// ───────────────────────────────────────────────────────────────────────────
Future<void> showAttributeManagerSheet(BuildContext context, AddEditProductController c, String attrKey) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => ListenableBuilder(
      listenable: c,
      builder: (ctx, _) {
        final attr = c.attributeByKey(attrKey);
        if (attr == null) return const SizedBox(height: 80);
        return _ManagerBody(controller: c, attr: attr, parentContext: context);
      },
    ),
  );
}

Future<String?> _textDialog(BuildContext context, {required String title, String initial = '', String hint = ''}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: hint), onSubmitted: (v) => Navigator.pop(ctx, v)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('حفظ')),
      ],
    ),
  ).whenComplete(ctrl.dispose);
}

class _ManagerBody extends StatelessWidget {
  final AddEditProductController controller;
  final AttributeDefinitionModel attr;
  final BuildContext parentContext;
  const _ManagerBody({required this.controller, required this.attr, required this.parentContext});

  bool get _isColor => attr.type == AttributeType.colorSwatch || attr.key == 'color';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = controller;
    final custom = c.isCustomAttribute(attr.key);
    final enabled = c.isAttributeEnabled(attr.key);
    final values = c.optionValuesFor(attr);

    Widget iconBtn(IconData icon, String tip, VoidCallback? onTap, {Color? color}) => IconButton(
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: _kIcon, color: onTap == null ? colors.textHint : (color ?? colors.textSecondary)),
          onPressed: onTap,
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // رأس الخاصية: الاسم + تعديل + حذف + تفعيل
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
          child: Row(children: [
            Expanded(child: Text(attr.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            if (custom)
              iconBtn(Icons.edit_outlined, 'إعادة تسمية الخاصية', () async {
                final name = await _textDialog(context, title: 'اسم الخاصية', initial: attr.name);
                if (name == null) return;
                final err = c.renameAttribute(attr.key, name);
                if (err != null && context.mounted) _snack(context, err);
                // المفتاح تغيّر: نغلق النافذة لتُعاد بالاسم الجديد.
                if (err == null && context.mounted) Navigator.pop(context);
              }),
            if (custom)
              iconBtn(Icons.delete_outline, 'حذف الخاصية', () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('حذف الخاصية'),
                    content: Text('سيتم حذف "${attr.name}" وكل قيمها من هذا المنتج.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
                    ],
                  ),
                );
                if (ok == true) {
                  c.removeCustomAttribute(attr.key);
                  if (context.mounted) Navigator.pop(context);
                }
              }, color: colors.error),
            Switch(value: enabled, activeThumbColor: colors.primary, onChanged: (v) => c.setAttributeEnabled(attr.key, v)),
          ]),
        ),
        if (!custom)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('خاصية من النظام: يمكنك تعطيلها وإدارة قيمها لهذا المنتج، واسمها ثابت.',
                style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
          ),
        // إظهار للمشتري (للخصائص الوصفية فقط؛ خيارات الشراء تظهر دائماً)
        if (!attr.isVariant)
          SwitchListTile(
            dense: true,
            value: !c.hiddenFromBuyerKeys.contains(attr.key),
            activeThumbColor: colors.primary,
            title: const Text('إظهار للمشتري', style: TextStyle(fontSize: 13)),
            subtitle: const Text('عند الإيقاف تبقى محفوظة لك فقط ولا تظهر في صفحة المنتج', style: TextStyle(fontSize: 11)),
            onChanged: (v) => c.setHiddenFromBuyer(attr.key, !v),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('خيارات للمشتري: كل قيمة مفعّلة تظهر للمشتري كخيار بسعر وكمية.',
                style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
          ),
        const Divider(height: 14),
        Flexible(
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: !enabled,
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
                if (values.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('لا توجد قيم بعد', style: TextStyle(color: colors.textHint)),
                  ),
                for (final v in values)
                  Row(children: [
                    if (_isColor)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _hexColor(v.hex),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black26),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                    Expanded(child: Text(v.label, style: const TextStyle(fontSize: 14))),
                    iconBtn(Icons.edit_outlined, 'تعديل القيمة', () async {
                      if (_isColor) {
                        final p = await showColorPickerDialog(context, initialName: v.label, initialHex: v.hex, confirmLabel: 'حفظ');
                        if (p == null) return;
                        final err = c.editOptionValue(attr.key, v.id, p.name, hex: p.hex);
                        if (err != null && context.mounted) _snack(context, err);
                      } else {
                        final t = await _textDialog(context, title: 'تعديل القيمة', initial: v.label);
                        if (t == null) return;
                        final err = c.editOptionValue(attr.key, v.id, t);
                        if (err != null && context.mounted) _snack(context, err);
                      }
                    }),
                    iconBtn(Icons.delete_outline, 'حذف القيمة', () => c.removeOptionValue(attr.key, v.id), color: colors.error),
                    Switch(
                      value: c.isValueEnabled(attr.key, v.id),
                      activeThumbColor: colors.primary,
                      onChanged: (on) => c.setValueEnabled(attr.key, v.id, on),
                    ),
                  ]),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(_isColor ? 'إنشاء لون جديد' : 'إضافة قيم'),
              onPressed: !enabled
                  ? null
                  : () async {
                      if (_isColor) {
                        await createNewColor(parentContext, c, attr.key);
                      } else if (attr.isVariant) {
                        final res = await showAddValuesDialog(
                          context,
                          attrName: attr.name,
                          initialUnit: c.attributeUnits[attr.key],
                          existingLabels: c.existingValueLabels(attr.key),
                        );
                        if (res != null) c.addVariantValues(attr.key, res.labels, unit: res.unit);
                      } else {
                        final res = await showAddValuesDialog(
                          context,
                          attrName: attr.name,
                          allowUnit: false,
                          existingLabels: c.existingValueLabels(attr.key),
                        );
                        if (res != null) c.addSpecValues(attr.key, res.labels);
                      }
                    },
            ),
            if (_isColor)
              OutlinedButton.icon(
                icon: const Icon(Icons.palette_outlined, size: 18),
                label: const Text('ألوان جاهزة'),
                onPressed: !enabled ? null : () => showReadyColorsSheet(context, c, attr.key),
              ),
            if (custom)
              OutlinedButton.icon(
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: const Text('حفظ في مفضلاتي'),
                onPressed: () async {
                  final ok = await c.saveAttributeToFavorites(attr.key);
                  if (context.mounted) _snack(context, ok ? 'تم الحفظ في مفضلاتك' : 'تعذّر الحفظ في المفضلة');
                },
              ),
          ]),
        ),
      ]),
    );
  }
}
