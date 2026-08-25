// lib/screens/wrapper.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/push_notification_service.dart';
import '../utils/app_colors.dart';
import 'admin/admin_main_screen.dart';
import 'auth/login_screen.dart';
import 'customer/customer_main_screen.dart';
import 'seller/seller_main_screen.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.currentUser;

        switch (auth.status) {
          case AuthStatus.initial:
            return const _SplashScreen();

          case AuthStatus.loading:
            return const _LoadingScreen();

          case AuthStatus.unauthenticated:
            // ✅ لا مستخدم مسجَّل — نربط السلة بمفتاح الزائر المحلي حتى لا
            // تبقى سلة الحساب السابق ظاهرة لمستخدم لاحق على نفس الجهاز.
            unawaited(context.read<CartProvider>().bindUser(null));
            return const LoginScreen();

          case AuthStatus.pendingRoleSelection:
            return const LoginScreen();

          case AuthStatus.guest:
            unawaited(context.read<CartProvider>().bindUser(null));
            return const CustomerMainScreen();

          case AuthStatus.authenticated:
            if (user == null) {
              return const LoginScreen();
            }
            // ✅ ربط السلة بـ uid الحساب الحالي فعلياً (إصلاح تسرّب السلة
            // بين الحسابات على نفس الجهاز) — Idempotent وآمن الاستدعاء
            // المتكرر (لا يفعل شيئاً إن كانت السلة مرتبطة بالفعل بنفس uid).
            unawaited(context.read<CartProvider>().bindUser(user.uid));
            unawaited(PushNotificationService.init(uid: user.uid));

            if (user.isAdmin) return const AdminMainScreen();
            if (user.isSeller) return const SellerMainScreen();
            return const CustomerMainScreen();
        }
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: context.colors.primary),
            const SizedBox(height: 16),
            Text('جاري التحميل...',
                style: TextStyle(color: context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 90,
                height: 90,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.storefront_rounded,
                  size: 90,
                  color: colors.primaryDark,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Souga',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colors.primaryDark,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
