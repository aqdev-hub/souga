// lib/widgets/theme_mode_sheet.dart
//
// ✅ عنصر واجهة مشترك لاختيار مظهر التطبيق (فاتح / داكن / تلقائي)
// يُستخدم من شاشات الإعدادات الثلاث: العميل، البائع، الإدارة —
// بدل تكرار نفس الكود في كل شاشة على حدة.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../utils/app_colors.dart';

String themeModeLabel(ThemeMode m) {
  switch (m) {
    case ThemeMode.light:  return 'فاتح';
    case ThemeMode.dark:   return 'داكن';
    case ThemeMode.system: return 'تلقائي (حسب النظام)';
  }
}

/// نافذة سفلية لاختيار وضع المظهر — تُستدعى من أي شاشة.
void showThemeModeSheet(BuildContext context) {
  final themeService = context.read<ThemeService>();
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('مظهر التطبيق',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        Consumer<ThemeService>(
          builder: (_, service, __) => Column(children: [
            ThemeModeOption(
              icon: Icons.brightness_auto_outlined,
              label: 'تلقائي (حسب النظام)',
              selected: service.mode == ThemeMode.system,
              onTap: () { themeService.setMode(ThemeMode.system); Navigator.pop(ctx); },
            ),
            ThemeModeOption(
              icon: Icons.light_mode_outlined,
              label: 'فاتح',
              selected: service.mode == ThemeMode.light,
              onTap: () { themeService.setMode(ThemeMode.light); Navigator.pop(ctx); },
            ),
            ThemeModeOption(
              icon: Icons.dark_mode_outlined,
              label: 'داكن',
              selected: service.mode == ThemeMode.dark,
              onTap: () { themeService.setMode(ThemeMode.dark); Navigator.pop(ctx); },
            ),
          ]),
        ),
        const SizedBox(height: 12),
      ]),
    ),
  );
}

/// خيار واحد ضمن نافذة اختيار المظهر.
class ThemeModeOption extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     selected;
  final VoidCallback onTap;

  const ThemeModeOption({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      leading: Icon(icon,
          color: selected ? colors.primary : colors.textSecondary),
      title: Text(label,
          style: TextStyle(
            color: selected ? colors.primary : colors.textPrimary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          )),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: colors.primary)
          : null,
      onTap: onTap,
    );
  }
}

/// عنصر ListTile جاهز لإدراجه مباشرة في أي شاشة إعدادات/حساب —
/// يعرض الوضع الحالي ويفتح نافذة الاختيار عند الضغط.
Widget themeModeTile(BuildContext context) {
  final mode   = context.watch<ThemeService>().mode;
  final colors = context.colors;
  return ListTile(
    leading: Icon(Icons.dark_mode_outlined, color: colors.primary),
    title: const Text('مظهر التطبيق'),
    subtitle: Text(themeModeLabel(mode)),
    trailing: Icon(Icons.arrow_forward_ios, size: 14, color: colors.textHint),
    onTap: () => showThemeModeSheet(context),
  );
}
