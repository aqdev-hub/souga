// lib/screens/admin/admin_users_screen.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../utils/app_colors.dart';
import '../shared/chat_screen.dart';
import '../../services/api_client.dart';

const _superName  = 'عبدالقدوس الشيباني';
const _superEmail = 'sba849198@gmail.com';
const _superPhone = '778942829';

bool isSuperAdmin(UserModel? u) {
  if (u == null || !u.isAdmin) return false;
  final phoneClean = u.phone.replaceAll(RegExp(r'[^0-9]'), '');
  return u.name.trim()  == _superName  &&
         u.email.trim() == _superEmail &&
         phoneClean.endsWith(_superPhone);
}

class AdminUsersScreen extends StatefulWidget {
  final String? filterRole;
  const AdminUsersScreen({super.key, this.filterRole});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final me      = context.watch<AuthProvider>().currentUser;
    final isSuper = isSuperAdmin(me);
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        actions: [
          if (!isSuper)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Chip(
                label: const Text('نائب', style: TextStyle(fontSize: 11)),
                backgroundColor: Colors.orange.withValues(alpha: 0.15),
                side: const BorderSide(color: Colors.orange),
              ),
            ),
        ],
      ),
      body: Column(children: [
        if (!isSuper)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.orange.withValues(alpha: 0.08),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 15),
              SizedBox(width: 8),
              Expanded(child: Text(
                'أنت نائب المدير. الأرقام مخفية وبعض العمليات تتطلب إذن عبدالقدوس الشيباني.',
                style: TextStyle(fontSize: 11, color: Colors.orange),
              )),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: isSuper ? 'بحث بالاسم أو البريد أو رقم الهاتف...' : 'بحث بالاسم أو البريد...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear),
                      onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
                  : null,
            ),
          ),
        ),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: (() {
            Query q = FirebaseFirestore.instance.collection('users');
            if (widget.filterRole?.isNotEmpty == true) {
              q = q.where('role', isEqualTo: widget.filterRole);
            }
            return q.orderBy('createdAt', descending: true).snapshots();
          })(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const Center(child: Text('لا يوجد مستخدمون'));
            }
            var users = snap.data!.docs
                .map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                .toList();
            if (_searchQuery.isNotEmpty) {
              users = users.where((u) {
                final nameOk  = u.name.toLowerCase().contains(_searchQuery);
                final emailOk = u.email.toLowerCase().contains(_searchQuery);
                final phoneOk = isSuper && u.phone.contains(_searchQuery);
                return nameOk || emailOk || phoneOk;
              }).toList();
            }
            if (users.isEmpty) return const Center(child: Text('لا توجد نتائج'));
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: users.length,
              itemBuilder: (_, i) => _UserCard(user: users[i], me: me, isSuper: isSuper),
            );
          },
        )),
      ]),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel  user;
  final UserModel? me;
  final bool       isSuper;
  const _UserCard({required this.user, required this.me, required this.isSuper});

  Color  _color(SougaColors colors) => user.isAdmin ? const Color(0xFF7B1FA2) : user.isSeller ? colors.primary : const Color(0xFF1565C0);
  String get _label => user.isAdmin ? 'مدير' : user.isSeller ? 'بائع' : 'مشتري';

  void _snack(BuildContext ctx, String msg, Color color) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  Future<bool> _confirm(BuildContext ctx, String title, String msg) async =>
      await showDialog<bool>(context: ctx, builder: (_) => AlertDialog(
        title: Text(title), content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
        ],
      )) ?? false;

  Future<void> _changeRole(BuildContext ctx, String newRole) async {
    if (!isSuper && newRole == 'admin') { _snack(ctx, '⛔ ترقية لمدير للمدير المطلق فقط', Colors.deepOrange); return; }
    if (!isSuper && user.isAdmin)       { _snack(ctx, '⛔ لا يمكنك تعديل دور مدير آخر',    Colors.deepOrange); return; }
    if (!await _confirm(ctx, 'تغيير الدور', 'تحويل "${user.name}" إلى $newRole؟')) return;
    if (!ctx.mounted) return;
    // ✅ تحديث أمني: تغيير الدور لم يعد كتابة مباشرة على Firestore، بل عبر
    // خادم موثوق يضبط Custom Claim الحقيقي (admin/seller) بجانب حقل role
    // للعرض — لأن قواعد Firestore الجديدة تعتمد على Custom Claims فقط.
    final snack = ScaffoldMessenger.of(ctx);
    final successColor = ctx.colors.success;
    final errorColor = ctx.colors.error;
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.post(
        Uri.parse('${ApiClient.serverBaseUrl}/set-user-role'),
        headers: headers,
        body: jsonEncode({'uid': user.uid, 'role': newRole}),
      ).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        snack.showSnackBar(SnackBar(content: const Text('✅ تم تغيير الدور'), backgroundColor: successColor));
      } else {
        snack.showSnackBar(SnackBar(
          content: Text('❌ ${ApiClient.friendlyAuthError(res.statusCode)}'),
          backgroundColor: errorColor,
        ));
      }
    } catch (e) {
      snack.showSnackBar(SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: errorColor));
    }
  }

  Future<void> _toggleActive(BuildContext ctx) async {
    if (!isSuper && user.isAdmin) { _snack(ctx, '⛔ لا يمكنك تعطيل مدير آخر', Colors.deepOrange); return; }
    final action = user.isActive ? 'تعطيل' : 'تفعيل';
    if (!await _confirm(ctx, '$action الحساب', '$action حساب "${user.name}"؟')) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isActive': !user.isActive});
    if (ctx.mounted) _snack(ctx, '✅ تم $action الحساب', ctx.colors.success);
  }

  Future<void> _delete(BuildContext ctx) async {
    if (!isSuper) { await _showPermDialog(ctx); return; }
    if (!ctx.mounted) return;
    // ignore: use_build_context_synchronously
    final snack = ScaffoldMessenger.of(ctx);
    final errorColor = ctx.colors.error;
    final successColor = ctx.colors.success;
    if (!await _confirm(ctx, '⚠️ حذف نهائي', 'سيتم حذف "${user.name}" نهائياً. لا يمكن التراجع!')) return;
     if (!ctx.mounted) return;
    if (!await _confirm(ctx, 'تأكيد نهائي', 'هل أنت متأكد تماماً؟')) return;
    try {
      final headers = await ApiClient.authHeaders();
      final delRes = await http.delete(
        Uri.parse('${ApiClient.serverBaseUrl}/delete-user'),
        headers: headers,
        body: jsonEncode({'uid': user.uid}),
      ).timeout(const Duration(seconds: 30));
      if (delRes.statusCode != 200) {
        snack.showSnackBar(SnackBar(
          content: Text('❌ ${ApiClient.friendlyAuthError(delRes.statusCode)}'),
          backgroundColor: errorColor,
        ));
        return;
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      if (user.isSeller) {
        final prods = await FirebaseFirestore.instance
            .collection('products').where('sellerId', isEqualTo: user.uid).get();
        if (prods.docs.isNotEmpty) {
          final b = FirebaseFirestore.instance.batch();
          for (final d in prods.docs) { b.delete(d.reference); }
          await b.commit();
        }
      }
      snack.showSnackBar(SnackBar(content: const Text('✅ تم الحذف النهائي'), backgroundColor: successColor));
    } catch (e) {
      snack.showSnackBar(SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: errorColor));
    }
  }

  Future<void> _showPermDialog(BuildContext ctx) async {
    await showDialog(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.lock_outline, color: Colors.orange, size: 22),
          SizedBox(width: 8),
          Text('إذن مطلوب'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('لا يمكنك حذف هذا الحساب بدون إذن من المدير:'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: dlgCtx.colors.textHint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Text('👤 عبدالقدوس الشيباني\n📧 sba849198@gmail.com', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 8),
          const Text('يمكنك إرسال طلب استئذان عبر المحادثة.', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('إلغاء')),
          ElevatedButton.icon(
            icon: const Icon(Icons.chat_outlined, size: 16),
            label: const Text('مراسلة المدير'),
            onPressed: () { Navigator.pop(dlgCtx); _openChat(ctx); },
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(BuildContext ctx) async {
    // ✅ حفظ Navigator وMessenger قبل أي await لتجنب context async gap
    final nav   = Navigator.of(ctx);
    final snack = ScaffoldMessenger.of(ctx);
    final errorColor = ctx.colors.error;
    final myId  = me?.uid ?? '';

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users').where('email', isEqualTo: _superEmail).limit(1).get();

      if (snap.docs.isEmpty) {
        snack.showSnackBar(SnackBar(content: const Text('لم يتم العثور على حساب المدير'), backgroundColor: errorColor));
        return;
      }

      final superUser = UserModel.fromMap(snap.docs.first.data(), snap.docs.first.id);

      // ✅ بناء roomId باستخدام ChatService.roomId
      final roomId = ChatService.roomId(myId, superUser.uid);

      // إنشاء الغرفة إن لم تكن موجودة
      await ChatService.getOrCreateRoom(
        myUid:      myId,
        otherUid:   superUser.uid,
        myName:     me?.name ?? 'نائب المدير',
        otherName:  superUser.name,
        myImage:    me?.profileImage ?? '',
        otherImage: superUser.profileImage,
      );

      // ✅ استخدام ChatScreen بالمعاملات الصحيحة: roomId, otherName, otherImage
      nav.push(MaterialPageRoute(builder: (_) => ChatScreen(
        roomId:     roomId,
        otherName:  superUser.name,
        otherImage: superUser.profileImage,
      )));

      // إرسال رسالة الاستئذان تلقائياً
      await Future.delayed(const Duration(milliseconds: 600));
      await ChatService.sendMessage(
        roomId:     roomId,
        senderId:   myId,
        senderName: me?.name ?? 'نائب المدير',
        text:       'السلام عليكم مديرنا ${superUser.name}،\n'
                    'أطلب إذنك بحذف حساب:\n'
                    '👤 ${user.name}\n'
                    '📧 ${user.email}\n'
                    'شكراً.',
        receiverId: superUser.uid,
      );
    } catch (e) {
      snack.showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: errorColor));
    }
  }

  /// المدير يراسل أي مستخدم مباشرة من بطاقته
  Future<void> _openChatWithUser(BuildContext ctx) async {
    final nav   = Navigator.of(ctx);
    final snack = ScaffoldMessenger.of(ctx);
    final errorColor = ctx.colors.error;
    if (me == null) return;
    try {
      final roomId = await ChatService.getOrCreateRoom(
        myUid:      me!.uid,
        myName:     me!.name,
        myImage:    me!.profileImage,
        otherUid:   user.uid,
        otherName:  user.name,
        otherImage: user.profileImage,
      );
      nav.push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          roomId:     roomId,
          otherName:  user.name,
          otherImage: user.profileImage,
        ),
      ));
    } catch (e) {
      snack.showSnackBar(SnackBar(
        content: Text('تعذر فتح المحادثة: $e'),
        backgroundColor: errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color  = _color(colors);
    final showPhone = isSuper && user.phone.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              backgroundImage: user.profileImage.isNotEmpty ? NetworkImage(user.profileImage) : null,
              child: user.profileImage.isEmpty
                  ? Text(user.name.isNotEmpty ? user.name[0] : 'م',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(user.email, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              if (showPhone)
                Text(user.phone, style: TextStyle(fontSize: 11, color: colors.textHint))
              else if (user.phone.isNotEmpty)
                const Text('📵 الرقم مخفي', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(_label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
          if (user.isSeller && user.storeName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('🏪 ${user.storeName}', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Icon(user.isActive ? Icons.check_circle : Icons.cancel, size: 14,
                color: user.isActive ? colors.success : colors.error),
            const SizedBox(width: 4),
            Text(user.isActive ? 'نشط' : 'معطّل',
                style: TextStyle(fontSize: 12, color: user.isActive ? colors.success : colors.error)),
            const Spacer(),
            if (isSuper || !user.isAdmin) ...[
              PopupMenuButton<String>(
                onSelected: (r) => _changeRole(context, r),
                itemBuilder: (_) => [
                  if (user.role != 'customer') const PopupMenuItem(value: 'customer', child: Text('تحويل لمشتري')),
                  if (user.role != 'seller')   const PopupMenuItem(value: 'seller',   child: Text('ترقية لبائع')),
                  if (isSuper && user.role != 'admin') const PopupMenuItem(value: 'admin', child: Text('ترقية لمدير ⭐')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(border: Border.all(color: colors.primary), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('الدور', style: TextStyle(fontSize: 12, color: colors.primary)),
                    Icon(Icons.arrow_drop_down, size: 16, color: colors.primary),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _toggleActive(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color:        (user.isActive ? colors.error : colors.success).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:       Border.all(color: user.isActive ? colors.error : colors.success),
                  ),
                  child: Text(user.isActive ? 'تعطيل' : 'تفعيل',
                      style: TextStyle(fontSize: 12, color: user.isActive ? colors.error : colors.success)),
                ),
              ),
              const SizedBox(width: 6),
              // ── زر مراسلة المستخدم ──
              if (user.uid != me?.uid)
                GestureDetector(
                  onTap: () => _openChatWithUser(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1976D2)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.chat_outlined, size: 13, color: Color(0xFF1976D2)),
                      SizedBox(width: 3),
                      Text('راسل', style: TextStyle(fontSize: 12,
                          color: Color(0xFF1976D2), fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _delete(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color:        colors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border:       Border.all(color: isSuper ? colors.error : Colors.orange),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isSuper ? Icons.delete_forever_outlined : Icons.lock_outline, size: 13,
                        color: isSuper ? colors.error : Colors.orange),
                    const SizedBox(width: 3),
                    Text(isSuper ? 'حذف' : 'طلب حذف',
                        style: TextStyle(fontSize: 12, color: isSuper ? colors.error : Colors.orange, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}
