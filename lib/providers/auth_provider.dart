// lib/providers/auth_provider.dart

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/push_notification_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  pendingRoleSelection, // ← مستخدم جوجل جديد ينتظر اختيار الدور
  guest,
}

/// نتيجة محاولة تسجيل الدخول بجوجل
enum GoogleSignInResult {
  success,          // دخول ناجح لمستخدم موجود
  newUserNeedsRole, // مستخدم جديد يحتاج اختيار الدور
  cancelled,        // ألغى المستخدم نافذة جوجل
  error,            // خطأ غير متوقع
}

class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {
  final FirebaseAuth      _auth      = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn      _googleSignIn = GoogleSignIn();

  static const String _cacheKey   = 'souga_user_cache';
  static const String _pendingKey = 'souga_user_pending';

  AuthStatus _status       = AuthStatus.initial;
  UserModel? _currentUser;
  String     _errorMessage = '';

  int     _authOpDepth    = 0;
  String? _activeUid;
  bool    _syncInProgress = false;

  /// بيانات مؤقتة لمستخدم جوجل الجديد الذي لم يختر دوره بعد
  User? _pendingGoogleUser;

  StreamSubscription<User?>? _authSub;
  Timer?                     _retryTimer;

  AuthStatus get status          => _status;
  UserModel? get currentUser     => _currentUser;
  String     get errorMessage    => _errorMessage;
  bool       get isLoading       => _status == AuthStatus.loading || _status == AuthStatus.pendingRoleSelection;
  bool       get isAuthenticated => _status == AuthStatus.authenticated;
  bool       get isGuest         => _status == AuthStatus.guest;

  AuthProvider() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await _bootstrap();
    _authSub = _auth.authStateChanges().listen(_onExternalAuthChange);
    _scheduleRetry(delay: 6);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _retryPending();
  }

  void _onExternalAuthChange(User? fbUser) {
    if (_authOpDepth > 0) return;
    if (fbUser == null &&
        _status != AuthStatus.guest &&
        _status != AuthStatus.unauthenticated &&
        _status != AuthStatus.pendingRoleSelection) {
      _currentUser = null;
      _activeUid   = null;
      _status      = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  // ── BOOTSTRAP ──────────────────────────────────────────────────────────────
  Future<void> _bootstrap() async {
    try {
      final fbUser = _auth.currentUser;
      if (fbUser == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }
      final uid = fbUser.uid;
      final cached = await _loadCache(uid);
      if (cached != null) {
        _enter(cached, uid);
        _syncBg(uid);
        return;
      }
      final pending = await _getPending();
      if (pending != null && pending['uid'] == uid) {
        final user = _fromPending(pending, fbUser);
        await _saveCache(user);
        _enter(user, uid);
        _writeFsBg(user);
        return;
      }
      _status = AuthStatus.loading;
      notifyListeners();
      final user = await _fetchFs(uid);
      if (user != null) {
        await _saveCache(user);
        _enter(user, uid);
        return;
      }
      // لا مستند في Firestore — ندخل بـ minimal (قد يكون مستخدم جوجل جديد)
      // ننتظر أن يكمل التسجيل أو نُدخله كـ customer مؤقتاً
      final min = _minimal(fbUser);
      await _saveCache(min);
      _enter(min, uid);
      _writeFsBg(min);
    } catch (e) {
      debugPrint('[Auth] bootstrap error: $e');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  // ── LOGIN (email/password) ─────────────────────────────────────────────────
  Future<bool> login({required String email, required String password}) async {
    _authOpDepth++;
    try {
      _status       = AuthStatus.loading;
      _errorMessage = '';
      notifyListeners();

      final cred   = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      final fbUser = cred.user;
      if (fbUser == null) { _setErr('تعذر الدخول للحساب'); return false; }
      final uid = fbUser.uid;

      final cached = await _loadCache(uid);
      if (cached != null) {
        if (!cached.isActive) { await _auth.signOut(); _setErr('تم تعطيل هذا الحساب'); return false; }
        _enter(cached, uid); _syncBg(uid); return true;
      }
      final pending = await _getPending();
      if (pending != null && pending['uid'] == uid) {
        final user = _fromPending(pending, fbUser);
        await _saveCache(user); _enter(user, uid); _writeFsBg(user); return true;
      }
      final user = await _fetchFs(uid);
      if (user != null) {
        if (!user.isActive) { await _auth.signOut(); _setErr('تم تعطيل هذا الحساب'); return false; }
        await _saveCache(user); _enter(user, uid); return true;
      }
      final min = _minimal(fbUser);
      await _saveCache(min); _enter(min, uid); _writeFsBg(min); return true;

    } on FirebaseAuthException catch (e) {
      _setErr(_arabic(e.code)); return false;
    } catch (e) {
      debugPrint('[Auth] login error: $e');
      _setErr('تحقق من الاتصال وأعد المحاولة'); return false;
    } finally {
      _authOpDepth--;
    }
  }

  // ── GOOGLE SIGN-IN ─────────────────────────────────────────────────────────
  //  يستخدم google_sign_in package — يعمل على Android و iOS و Web
  // ──────────────────────────────────────────────────────────────────────────
  Future<GoogleSignInResult> loginWithGoogle() async {
    _authOpDepth++;
    try {
      _status       = AuthStatus.loading;
      _errorMessage = '';
      notifyListeners();

      // 1. تأكد من عدم وجود جلسة سابقة معلقة (يسبب null عند أول محاولة)
      try { await _googleSignIn.signOut(); } catch (_) {}

      // 2. فتح نافذة اختيار حساب جوجل
      final googleAccount = await _googleSignIn.signIn();
      if (googleAccount == null) {
        // المستخدم أغلق نافذة الاختيار
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return GoogleSignInResult.cancelled;
      }

      // 2. الحصول على بيانات المصادقة
      final googleAuth = await googleAccount.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      // 3. تسجيل الدخول في Firebase
      final cred   = await _auth.signInWithCredential(credential);
      final fbUser = cred.user;
      if (fbUser == null) {
        _setErr('تعذر الحصول على بيانات جوجل');
        return GoogleSignInResult.error;
      }
      final uid = fbUser.uid;

      // 4. تحقق من الكاش
      final cached = await _loadCache(uid);
      if (cached != null) {
        if (!cached.isActive) {
          await _auth.signOut(); await _googleSignIn.signOut();
          _setErr('تم تعطيل هذا الحساب');
          return GoogleSignInResult.error;
        }
        _enter(cached, uid); _syncBg(uid);
        return GoogleSignInResult.success;
      }

      // 5. تحقق من Firestore
      final existing = await _fetchFs(uid);
      if (existing != null) {
        if (!existing.isActive) {
          await _auth.signOut(); await _googleSignIn.signOut();
          _setErr('تم تعطيل هذا الحساب');
          return GoogleSignInResult.error;
        }
        await _saveCache(existing); _enter(existing, uid);
        return GoogleSignInResult.success;
      }

      // 6. مستخدم جديد — يحتاج اختيار الدور
      // نُبقي status=pendingRoleSelection حتى لا يُعيد Wrapper لشاشة التسجيل
      _pendingGoogleUser = fbUser;
      _status            = AuthStatus.pendingRoleSelection;
      notifyListeners();
      return GoogleSignInResult.newUserNeedsRole;

    } on FirebaseAuthException catch (e) {
      _setErr(_arabic(e.code));
      return GoogleSignInResult.error;
    } catch (e) {
      debugPrint('[Auth] loginWithGoogle error: $e');
      _setErr('تعذر الدخول بجوجل. حاول مجدداً');
      return GoogleSignInResult.error;
    } finally {
      _authOpDepth--;
    }
  }

  /// إكمال تسجيل مستخدم جوجل الجديد بعد اختيار الدور
  Future<bool> completeGoogleSignIn({
    required String role,
    String storeName        = '',
    String storeDescription = '',
  }) async {
    final fbUser = _pendingGoogleUser;
    if (fbUser == null) {
      _setErr('انتهت الجلسة، يرجى إعادة المحاولة');
      return false;
    }
    _authOpDepth++;
    try {
      _status       = AuthStatus.loading;
      _errorMessage = '';
      notifyListeners();

      final user = UserModel(
        uid:              fbUser.uid,
        name:             fbUser.displayName ?? '',
        email:            fbUser.email ?? '',
        role:             role,
        phone:            fbUser.phoneNumber ?? '',
        profileImage:     fbUser.photoURL ?? '',
        storeName:        storeName.trim(),
        storeDescription: storeDescription.trim(),
        createdAt:        DateTime.now(),
        isActive:         true,
      );

      await _savePending(user);
      await _saveCache(user);
      // ندخل المستخدم فوراً — لا ننتظر Firestore
      _enter(user, fbUser.uid);
      _pendingGoogleUser = null;
      // كتابة Firestore في الخلفية — لا تُوقف الدخول إذا فشلت
      _writeFsBg(user);
      return true;
    } catch (e) {
      debugPrint('[Auth] completeGoogleSignIn error: $e');
      _setErr('حدث خطأ أثناء إنشاء الحساب. حاول مرة أخرى.');
      return false;
    } finally {
      _authOpDepth--;
    }
  }

  /// إلغاء تسجيل جوجل الجديد
  Future<void> cancelGoogleSignIn() async {
    _pendingGoogleUser = null;
    try { await _auth.signOut(); } catch (_) {}
    try { await _googleSignIn.signOut(); } catch (_) {}
    _status       = AuthStatus.unauthenticated;
    _errorMessage = '';
    notifyListeners();
  }

  // ── REGISTER ───────────────────────────────────────────────────────────────
  Future<bool> registerAsCustomer({
    required String name, required String email,
    required String password, required String phone,
    String profileImage = '',
  }) => _register(
    name: name, email: email, password: password,
    phone: phone, role: 'customer', profileImage: profileImage,
  );

  Future<bool> registerAsSeller({
    required String name, required String email,
    required String password, required String phone,
    required String storeName, required String storeDescription,
    String profileImage = '', String storeLogo = '',
  }) => _register(
    name: name, email: email, password: password, phone: phone,
    role: 'seller', profileImage: profileImage,
    storeName: storeName, storeDescription: storeDescription,
    storeLogo: storeLogo,
  );

  Future<bool> _register({
    required String name, required String email,
    required String password, required String phone, required String role,
    String profileImage = '', String storeName = '',
    String storeDescription = '', String storeLogo = '',
  }) async {
    _authOpDepth++;
    try {
      _status       = AuthStatus.loading;
      _errorMessage = '';
      notifyListeners();

      final cred   = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      final fbUser = cred.user;
      if (fbUser == null) throw Exception('null user from Firebase');

      final user = UserModel(
        uid: fbUser.uid, name: name.trim(), email: email.trim(),
        role: role, phone: phone.trim(), profileImage: profileImage,
        storeName: storeName.trim(), storeDescription: storeDescription.trim(),
        storeLogo: storeLogo, createdAt: DateTime.now(), isActive: true,
      );

      await _savePending(user);
      await _saveCache(user);
      _enter(user, fbUser.uid);
      _writeFsBg(user);
      return true;

    } on FirebaseAuthException catch (e) {
      _setErr(_arabic(e.code)); return false;
    } catch (e) {
      debugPrint('[Auth] register error: $e');
      _setErr('حدث خطأ أثناء إنشاء الحساب. حاول مرة أخرى.');
      return false;
    } finally {
      _authOpDepth--;
    }
  }

  // ── LOGOUT ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    _authOpDepth++;
    // ✅ نلتقط uid الحساب الحالي قبل مسحه، لحذف رمز الإشعارات (FCM) الخاص
    // به من Firestore — يمنع وصول إشعارات هذا الحساب لأي مستخدم لاحق
    // يستخدم نفس الجهاز الفعلي.
    final uidBeforeLogout = _currentUser?.uid;
    try {
      _retryTimer?.cancel();
      _pendingGoogleUser = null;
      _currentUser  = null;
      _activeUid    = null;
      _status       = AuthStatus.unauthenticated;
      _errorMessage = '';
      notifyListeners();
      await _clearCache();
      unawaited(PushNotificationService.clearToken(uidBeforeLogout));
      try { await _auth.signOut(); } catch (_) {}
      try { await _googleSignIn.signOut(); } catch (_) {}
    } finally {
      _authOpDepth--;
    }
  }

  void loginAsGuest() {
    _currentUser = UserModel(
      uid: 'guest', name: 'زائر', email: '',
      role: 'customer', createdAt: DateTime.now(),
    );
    _activeUid = null;
    _status    = AuthStatus.guest;
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? name, String? phone, String? profileImage,
    String? storeName, String? storeDescription, String? storeLogo,
    String? storeLocation,
  }) async {
    final cur = _currentUser;
    if (cur == null || cur.uid == 'guest') return false;
    try {
      final upd = cur.copyWith(
        name: name, phone: phone, profileImage: profileImage,
        storeName: storeName, storeDescription: storeDescription,
        storeLogo: storeLogo, storeLocation: storeLocation,
      );
      _currentUser = upd;
      await _saveCache(upd);
      notifyListeners();

      final data = <String, dynamic>{};
      if (name             != null) data['name']             = name;
      if (phone            != null) data['phone']            = phone;
      if (profileImage     != null) data['profileImage']     = profileImage;
      if (storeName        != null) data['storeName']        = storeName;
      if (storeDescription != null) data['storeDescription'] = storeDescription;
      if (storeLogo        != null) data['storeLogo']        = storeLogo;
      if (storeLocation    != null) data['storeLocation']    = storeLocation;
      if (data.isNotEmpty) {
        _firestore.collection('users').doc(upd.uid)
            .set(data, SetOptions(merge: true))
            .catchError((dynamic e) => debugPrint('[Auth] updateProfile: $e'));
      }
      return true;
    } catch (_) { return false; }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _arabic(e.code); notifyListeners(); return false;
    } catch (_) {
      _errorMessage = 'تحقق من الاتصال وأعد المحاولة'; notifyListeners(); return false;
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  void _enter(UserModel user, String uid) {
    _currentUser = user; _activeUid = uid;
    _status = AuthStatus.authenticated; notifyListeners();
  }

  void _setErr(String msg) {
    _status = AuthStatus.unauthenticated; _errorMessage = msg; notifyListeners();
  }

  Future<void> _writeFsBg(UserModel user) async {
    final uid = user.uid;
    try {
      final payload = user.toMap();
      payload['createdAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(uid)
          .set(payload, SetOptions(merge: true));
      if (_activeUid != uid) return;
      await _clearPending();
      debugPrint('[Auth] ✅ Firestore written: $uid');
      _syncBg(uid);
    } catch (e) {
      debugPrint('[Auth] ⚠️ Firestore write failed: $e');
    }
  }

  Future<void> _syncBg(String uid) async {
    if (_syncInProgress || _activeUid != uid) return;
    _syncInProgress = true;
    try {
      final remote = await _fetchFs(uid);
      if (remote == null || _activeUid != uid) return;
      if (!remote.isActive) { await logout(); return; }
      final merged = _merge(_currentUser, remote);
      _currentUser = merged; await _saveCache(merged); notifyListeners();
    } catch (_) {
    } finally { _syncInProgress = false; }
  }

  Future<void> _retryPending() async {
    if (_activeUid == null) return;
    final p = await _getPending();
    if (p == null || p['uid'] != _activeUid) return;
    final fb = _auth.currentUser;
    if (fb == null) return;
    debugPrint('[Auth] 🔄 retrying pending write');
    _writeFsBg(_fromPending(p, fb));
  }

  void _scheduleRetry({int delay = 6}) {
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delay), _retryPending);
  }

  UserModel _merge(UserModel? local, UserModel remote) {
    if (local == null) return remote;
    const p = {'admin': 3, 'seller': 2, 'customer': 1};
    final role = (p[local.role] ?? 1) >= (p[remote.role] ?? 1) ? local.role : remote.role;
    return remote.copyWith(
      role: role,
      name:             remote.name.isNotEmpty             ? remote.name             : local.name,
      phone:            remote.phone.isNotEmpty            ? remote.phone            : local.phone,
      profileImage:     remote.profileImage.isNotEmpty     ? remote.profileImage     : local.profileImage,
      storeName:        remote.storeName.isNotEmpty        ? remote.storeName        : local.storeName,
      storeLogo:        remote.storeLogo.isNotEmpty        ? remote.storeLogo        : local.storeLogo,
      storeDescription: remote.storeDescription.isNotEmpty ? remote.storeDescription : local.storeDescription,
    );
  }

  UserModel _fromPending(Map<String, dynamic> m, User fb) => UserModel(
    uid:              fb.uid,
    name:             (m['name']             ?? '').toString(),
    email:            (m['email']            ?? fb.email ?? '').toString(),
    role:             (m['role']?.toString().trim().isNotEmpty == true) ? m['role'].toString() : 'customer',
    phone:            (m['phone']            ?? '').toString(),
    profileImage:     (m['profileImage']     ?? '').toString(),
    storeName:        (m['storeName']        ?? '').toString(),
    storeLogo:        (m['storeLogo']        ?? '').toString(),
    storeDescription: (m['storeDescription'] ?? '').toString(),
    createdAt:        DateTime.now(), isActive: true,
  );

  UserModel _minimal(User fb) => UserModel(
    uid: fb.uid, name: fb.displayName ?? '',
    email: fb.email ?? '', role: 'customer',
    createdAt: DateTime.now(), isActive: true,
  );

  Future<UserModel?> _fetchFs(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) return UserModel.fromMap(doc.data()!, uid);
    } catch (e) { debugPrint('[Auth] fetchFs error: $e'); }
    return null;
  }

  Future<UserModel?> _loadCache(String uid) async {
    try {
      final p   = await SharedPreferences.getInstance();
      final raw = p.getString(_cacheKey);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['uid']?.toString() != uid) return null;
      return UserModel.fromMap(map, uid);
    } catch (_) { return null; }
  }

  Future<void> _saveCache(UserModel u) async {
    try {
      final p   = await SharedPreferences.getInstance();
      final map = u.toMap();
      map['createdAt'] = u.createdAt?.toIso8601String() ?? '';
      await p.setString(_cacheKey, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    try { final p = await SharedPreferences.getInstance(); await p.remove(_cacheKey); } catch (_) {}
  }

  Future<void> _savePending(UserModel u) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_pendingKey, jsonEncode({
        'uid': u.uid, 'name': u.name, 'email': u.email, 'role': u.role,
        'phone': u.phone, 'profileImage': u.profileImage,
        'storeName': u.storeName, 'storeLogo': u.storeLogo,
        'storeDescription': u.storeDescription,
      }));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _getPending() async {
    try {
      final p   = await SharedPreferences.getInstance();
      final raw = p.getString(_pendingKey);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  Future<void> _clearPending() async {
    try { final p = await SharedPreferences.getInstance(); await p.remove(_pendingKey); } catch (_) {}
  }

  String _arabic(String code) {
    switch (code) {
      case 'email-already-in-use':   return 'البريد الإلكتروني مستخدم بالفعل';
      case 'invalid-email':          return 'البريد الإلكتروني غير صحيح';
      case 'weak-password':          return 'كلمة المرور ضعيفة (6 أحرف على الأقل)';
      case 'user-not-found':         return 'لا يوجد حساب بهذا البريد';
      case 'wrong-password':         return 'كلمة المرور غير صحيحة';
      case 'invalid-credential':     return 'البريد أو كلمة المرور غير صحيحة';
      case 'user-disabled':          return 'تم تعطيل هذا الحساب';
      case 'too-many-requests':      return 'كثرة المحاولات، انتظر قليلاً';
      case 'network-request-failed': return 'تحقق من الاتصال بالإنترنت';
      case 'operation-not-allowed':  return 'هذا النوع من الحسابات غير مفعَّل';
      case 'requires-recent-login':  return 'يرجى إعادة تسجيل الدخول';
      default:                       return 'حدث خطأ، حاول مرة أخرى';
    }
  }
}
