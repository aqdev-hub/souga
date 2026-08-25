// lib/screens/customer/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../utils/app_colors.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final isGuest = context.watch<AuthProvider>().isGuest;
    final colors = context.colors;

    // زائر → رسالة تسجيل الدخول
    if (isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('السلة')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.shopping_cart_outlined, size: 90, color: colors.border),
            const SizedBox(height: 20),
            Text('للوصول للسلة يجب تسجيل الدخول',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: colors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.read<AuthProvider>().logout(),
              child: const Text('تسجيل الدخول'),
            ),
          ]),
        )),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('السلة'),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: () => showDialog(context: context, builder: (_) => AlertDialog(
                title: const Text('إفراغ السلة'),
                content: const Text('هل تريد إفراغ السلة؟'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                  TextButton(onPressed: () { context.read<CartProvider>().clearCart(); Navigator.pop(context); },
                      child: Text('إفراغ', style: TextStyle(color: context.colors.error))),
                ],
              )),
              child: const Text('إفراغ', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: cart.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.shopping_cart_outlined, size: 100, color: colors.border),
              const SizedBox(height: 16),
              Text('السلة فارغة', style: TextStyle(fontSize: 18, color: colors.textSecondary)),
              const SizedBox(height: 8),
              Text('أضف منتجات للسلة للبدء', style: TextStyle(color: colors.textHint)),
            ]))
          : Column(children: [
              Expanded(child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: cart.items.length,
                itemBuilder: (_, i) {
                  final item = cart.items[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.image.isNotEmpty
                            ? Image.network(item.image, width: 70, height: 70, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 70, height: 70, color: colors.border,
                                    child: const Icon(Icons.image_outlined)))
                            : Container(width: 70, height: 70, color: colors.border,
                                child: Icon(Icons.image_outlined, color: colors.textHint)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('${item.price.toStringAsFixed(2)} ${item.currencySymbol}',
                            style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Container(
                            decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [
                              IconButton(icon: const Icon(Icons.remove, size: 16),
                                  onPressed: () => context.read<CartProvider>().updateQuantity(item.productId, item.quantity - 1),
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                              Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(icon: const Icon(Icons.add, size: 16),
                                  onPressed: () => context.read<CartProvider>().updateQuantity(item.productId, item.quantity + 1),
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                            ]),
                          ),
                          const Spacer(),
                          Text('${item.total.toStringAsFixed(2)} ${item.currencySymbol}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ]),
                      ])),
                      IconButton(icon: Icon(Icons.delete_outline, color: colors.error),
                          onPressed: () => context.read<CartProvider>().removeItem(item.productId)),
                    ])),
                  );
                },
              )),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: colors.surface,
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))]),
                child: Column(children: [
                  // ✅ إصلاح باغ حسابي: كانت الشاشة تجمع كل الأسعار كرقم
                  // واحد بغض النظر عن العملة (خطأ إن اختلفت عملات المنتجات).
                  // الآن نعرض إجمالاً منفصلاً وصحيحاً لكل عملة موجودة فعلياً.
                  if (cart.hasMixedCurrencies)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline, size: 16, color: colors.warning),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          'سلتك تحتوي منتجات بعملات مختلفة — سيتم إنشاء طلب منفصل لكل عملة عند الدفع.',
                          style: TextStyle(fontSize: 11.5, color: colors.warning),
                        )),
                      ]),
                    ),
                  ...cart.totalsByCurrency.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('الإجمالي (${e.key}):', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('${e.value.toStringAsFixed(2)} ${e.key}',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: colors.primary)),
                    ]),
                  )),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                    child: const Text('إتمام الطلب'),
                  ),
                ]),
              ),
            ]),
    );
  }
}
