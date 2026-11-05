// lib/screens/customer/customer_main_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/chat_service.dart';
import '../../utils/app_colors.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'cart_screen.dart';
import 'favorites_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import '../shared/chat_list_screen.dart';

class CustomerMainScreen extends StatefulWidget {
  const CustomerMainScreen({super.key});
  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    CartScreen(),
    FavoritesScreen(),
    ChatListScreen(),
    OrdersScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;
    final uid       = context.watch<AuthProvider>().currentUser?.uid ?? '';
    final colors    = context.colors;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex:        _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor:      colors.surface,
        indicatorColor:       colors.primary.withValues(alpha: 0.12),
        labelBehavior:        NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon:         const Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: colors.primary),
            label:        'الرئيسية',
          ),
          NavigationDestination(
            icon:         const Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search, color: colors.primary),
            label:        'بحث',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: Icon(Icons.shopping_cart, color: colors.primary),
            ),
            label: 'السلة',
          ),
          NavigationDestination(
            icon:         const Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite, color: colors.primary),
            label:        'المفضلة',
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
            selectedIcon: Icon(Icons.chat_bubble, color: colors.primary),
            label: 'المحادثات',
          ),
          NavigationDestination(
            icon:         const Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: colors.primary),
            label:        'طلباتي',
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
