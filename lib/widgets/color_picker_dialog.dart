// lib/widgets/color_picker_dialog.dart
//
// ✅ منتقي لون كامل بلا مكتبات: مساحة تدرج (تشبّع/سطوع) + شريط درجة اللون (Hue)
// + قنوات RGB + معاينة فورية + حقل اسم اللون + إضافة/إلغاء.
// يعيد الاسم والـ hex كما أدخلهما البائع تماماً.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_colors.dart';
import '../utils/ready_colors.dart';

class PickedColor {
  final String name;
  final String hex;
  const PickedColor(this.name, this.hex);
}

Future<PickedColor?> showColorPickerDialog(
  BuildContext context, {
  String initialName = '',
  String? initialHex,
  String confirmLabel = 'إضافة اللون',
}) {
  return showDialog<PickedColor>(
    context: context,
    builder: (_) => _ColorPickerDialog(initialName: initialName, initialHex: initialHex, confirmLabel: confirmLabel),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  final String initialName;
  final String? initialHex;
  final String confirmLabel;
  const _ColorPickerDialog({required this.initialName, required this.initialHex, required this.confirmLabel});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv;
  late final TextEditingController _name;
  late final TextEditingController _hex;
  String? _error;

  @override
  void initState() {
    super.initState();
    final argb = hexToArgb(widget.initialHex) ?? 0xFF1E88E5;
    _hsv = HSVColor.fromColor(Color(argb));
    _name = TextEditingController(text: widget.initialName);
    _hex = TextEditingController(text: argbToHex(argb));
  }

  @override
  void dispose() {
    _name.dispose();
    _hex.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor();

  void _setHsv(HSVColor v) {
    setState(() {
      _hsv = v;
      _hex.text = argbToHex(_color.toARGB32());
    });
  }

  void _setRgb({int? r, int? g, int? b}) {
    final c = _color;
    final nc = Color.fromARGB(255, r ?? (c.r * 255).round(), g ?? (c.g * 255).round(), b ?? (c.b * 255).round());
    // نُبقي الدرجة/التشبع عند الرمادي/الأسود حتى لا تقفز الدرجة.
    final h = HSVColor.fromColor(nc);
    _setHsv(h.saturation == 0 || h.value == 0 ? h.withHue(_hsv.hue) : h);
  }

  void _onHexChanged(String v) {
    final argb = hexToArgb(v.startsWith('#') ? v : '#$v');
    if (argb != null) setState(() => _hsv = HSVColor.fromColor(Color(argb)));
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'اكتب اسم اللون');
      return;
    }
    Navigator.pop(context, PickedColor(name, argbToHex(_color.toARGB32())));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = _color;
    final r = (c.r * 255).round(), g = (c.g * 255).round(), b = (c.b * 255).round();

    Widget channel(String label, int value, Color tint, ValueChanged<int> onChanged) => Row(children: [
          SizedBox(width: 18, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(activeTrackColor: tint, thumbColor: tint, trackHeight: 3),
              child: Slider(min: 0, max: 255, value: value.toDouble(), onChanged: (v) => onChanged(v.round())),
            ),
          ),
          SizedBox(width: 30, child: Text('$value', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12))),
        ]);

    return AlertDialog(
      title: const Text('إنشاء لون جديد'),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // معاينة حية
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                _name.text.trim().isEmpty ? 'معاينة اللون' : _name.text.trim(),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: c.computeLuminance() > 0.55 ? Colors.black87 : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // مساحة اللون: أفقي = تشبّع، رأسي = سطوع
            SizedBox(
              height: 150,
              child: LayoutBuilder(builder: (ctx, cons) {
                final w = cons.maxWidth, h = 150.0;
                void update(Offset p) {
                  final s = (p.dx / w).clamp(0.0, 1.0);
                  final v = 1 - (p.dy / h).clamp(0.0, 1.0);
                  _setHsv(_hsv.withSaturation(s).withValue(v));
                }

                return GestureDetector(
                  onPanDown: (d) => update(d.localPosition),
                  onPanUpdate: (d) => update(d.localPosition),
                  child: Stack(children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CustomPaint(painter: _SvPainter(_hsv.hue)),
                      ),
                    ),
                    Positioned(
                      left: (_hsv.saturation * w) - 9,
                      top: ((1 - _hsv.value) * h) - 9,
                      child: IgnorePointer(
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                          ),
                        ),
                      ),
                    ),
                  ]),
                );
              }),
            ),
            const SizedBox(height: 8),
            // شريط درجة اللون
            SizedBox(
              height: 26,
              child: LayoutBuilder(builder: (ctx, cons) {
                final w = cons.maxWidth;
                void update(double x) => _setHsv(_hsv.withHue((x / w).clamp(0.0, 1.0) * 359.9));
                return GestureDetector(
                  onPanDown: (d) => update(d.localPosition.dx),
                  onPanUpdate: (d) => update(d.localPosition.dx),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          gradient: LinearGradient(colors: [
                            for (var i = 0; i <= 6; i++) HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor(),
                          ]),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (_hsv.hue / 359.9) * w - 11,
                      top: 2,
                      child: IgnorePointer(
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                          ),
                        ),
                      ),
                    ),
                  ]),
                );
              }),
            ),
            const SizedBox(height: 6),
            channel('R', r, Colors.red, (v) => _setRgb(r: v)),
            channel('G', g, Colors.green, (v) => _setRgb(g: v)),
            channel('B', b, Colors.blue, (v) => _setRgb(b: v)),
            const SizedBox(height: 4),
            TextField(
              controller: _hex,
              textDirection: TextDirection.ltr,
              maxLength: 7,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]'))],
              decoration: const InputDecoration(labelText: 'رمز اللون (HEX)', isDense: true, counterText: ''),
              onChanged: _onHexChanged,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              autofocus: false,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(labelText: 'اسم اللون', hintText: 'مثال: أخضر زيتي', isDense: true, errorText: _error),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

class _SvPainter extends CustomPainter {
  final double hue;
  _SvPainter(this.hue);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(colors: [Colors.white, HSVColor.fromAHSV(1, hue, 1, 1).toColor()]).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SvPainter old) => old.hue != hue;
}
