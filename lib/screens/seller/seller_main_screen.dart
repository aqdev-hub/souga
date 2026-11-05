// lib/screens/seller/seller_main_screen.dart
//
//  الإصلاح: البائع عند التصفح يمكنه الآن إكمال الشراء
//  - تاب "تصفح" → SellerShoppingScreen يحتوي على Browse + السلة + طلباتي
//  - الهيكل: IndexedStack داخلي بثلاث شاشات

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/chat_service.dart';
import '../../utils/app_colors.dart';
import 'seller_dashboard_screen.dart';
import 'seller_products_screen.dart';
import 'seller_orders_screen.dart';
import '../customer/home_screen.dart';
import '../customer/cart_screen.dart';
import '../customer/orders_screen.dart';
import '../shared/chat_list_screen.dart';
import 'seller_profile_screen.dart';

class SellerMainScreen extends StatefulWidget {
  const SellerMainScreen({super.key});
  @override
  State<SellerMainScreen> createState() => _SellerMainScreenState();
}

class _SellerMainScreenState extends State<SellerMainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    SellerDashboardScreen(),
    SellerProductsScreen(),
    SellerOrdersScreen(),
    ChatListScreen(),
    _SellerShoppingScreen(), // تصفح + سلة + طلبات
    SellerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final uid      = context.watch<AuthProvider>().currentUser?.uid ?? '';
    final cartCount = context.watch<CartProvider>().itemCount;
    final colors    = context.colors;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex:        _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor:      colors.surface,
        indicatorColor:       colors.primary.withValues(alpha: 0.12),
        destinations: [
          NavigationDestination(
            icon:         const Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: colors.primary),
            label:        'لوحتي',
          ),
          NavigationDestination(
            icon:         const Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: colors.primary),
            label:        'منتجاتي',
          ),
          NavigationDestination(
            icon:         const Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: colors.primary),
            label:        'طلباتي',
          ),
          // تاب المحادثات
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
            selectedIcon: Icon(Icons.chat_bubble, color: colors.primary),
            label: 'المحادثات',
          ),
          // تاب التصفح مع badge السلة
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.explore_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: Icon(Icons.explore, color: colors.primary),
            ),
            label: 'تصفح',
          ),
          NavigationDestination(
            icon:         const Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person, color: colors.primary),
            label:        'حسابي',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  شاشة التصفح للبائع — تحتوي على تاب داخلي: تصفح / سلة / طلباتي
// ─────────────────────────────────────────────────────────────────────────────
class _SellerShoppingScreen extends StatefulWidget {
  const _SellerShoppingScreen();
  @override
  State<_SellerShoppingScreen> createState() => _SellerShoppingScreenState();
}

class _SellerShoppingScreenState extends State<_SellerShoppingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;
    final colors     = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تصفح السوق'),
        bottom: TabBar(
          controller:        _tabCtrl,
          indicatorColor:    colors.primary,
          indicatorWeight:   3,
          labelColor:        Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle:        const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: [
            const Tab(icon: Icon(Icons.explore_outlined, size: 20), text: 'تصفح'),
            Tab(
              icon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount'),
                child: const Icon(Icons.shopping_cart_outlined, size: 20),
              ),
              text: 'السلة',
            ),
            const Tab(icon: Icon(Icons.receipt_long_outlined, size: 20), text: 'مشترياتي'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          HomeScreen(),
          CartScreen(),
          OrdersScreen(),
        ],
      ),
    );
  }
}
