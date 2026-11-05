// lib/screens/admin/admin_main_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/update_service.dart';
import '../../utils/app_colors.dart';
import 'admin_dashboard_screen.dart';
import 'admin_users_screen.dart';
import 'admin_products_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_profile_screen.dart';
import '../shared/chat_list_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});
  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    AdminDashboardScreen(),
    AdminUsersScreen(),
    AdminProductsScreen(),
    AdminOrdersScreen(),
    ChatListScreen(),
    AdminProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final uid    = context.watch<AuthProvider>().currentUser?.uid ?? '';
    final colors = context.colors;

    return Scaffold(
      body: Stack(children: [
        IndexedStack(index: _selectedIndex, children: _screens),
        // ── بانر التحديث ──────────────────────────────────────────────
        const Positioned(top: 0, right: 0, left: 0, child: UpdateBanner()),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex:        _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor:      colors.surface,
        indicatorColor:       colors.primaryDark.withValues(alpha: 0.15),
        destinations: [
          NavigationDestination(
            icon:         const Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: colors.primaryDark),
            label:        'لوحة التحكم',
          ),
          NavigationDestination(
            icon:         const Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people, color: colors.primaryDark),
            label:        'المستخدمون',
          ),
          NavigationDestination(
            icon:         const Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: colors.primaryDark),
            label:        'المنتجات',
          ),
          NavigationDestination(
            icon:         const Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: colors.primaryDark),
            label:        'الطلبات',
          ),
          NavigationDestination(
            icon: uid.isNotEmpty
                ? StreamBuilder<int>(
                    stream: ChatService.totalUnreadStream(uid),
                    builder: (_, snap) {
                      final count = snap.data ?? 0;
                      return Badge(
                        isLabelVisible: count > 0,
                        label: Text('$count'),
                        child: const Icon(Icons.chat_bubble_outline),
                      );
                    },
                  )
                : const Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: colors.primaryDark),
            label: 'المحادثات',
          ),
          NavigationDestination(
            icon:         const Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings, color: colors.primaryDark),
            label:        'حسابي',
          ),
        ],
      ),
    );
  }
}
