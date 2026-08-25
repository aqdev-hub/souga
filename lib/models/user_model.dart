// lib/models/user_model.dart
// ✅ يستخدم 'uid' (وليس 'id') ليتوافق مع جميع أجزاء المشروع

class UserModel {
  final String    uid;              // ← uid (وليس id)
  final String    name;
  final String    email;
  final String    phone;
  final String    role;
  final String    profileImage;     // صورة شخصية — منفصلة عن شعار المتجر
  final String    storeName;
  final String    storeLogo;        // شعار المتجر — مختلف عن profileImage
  final String    storeDescription;
  final String    storeLocation;    // إحداثيات الموقع "lat,lng"
  final bool      isActive;
  final DateTime? createdAt;        // nullable — قد لا يكون موجوداً

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone            = '',
    this.role             = 'customer',
    this.profileImage     = '',
    this.storeName        = '',
    this.storeLogo        = '',
    this.storeDescription = '',
    this.storeLocation    = '',
    this.isActive         = true,
    this.createdAt,
  });

  // ── Getters ──────────────────────────────────────────────────────────────
  bool get isSeller       => role == 'seller';
  bool get isAdmin        => role == 'admin';
  bool get isCustomer     => role == 'customer';
  bool get hasStoreLogo   => storeLogo.isNotEmpty;
  bool get hasProfileImage => profileImage.isNotEmpty;
  bool get hasLocation    => storeLocation.isNotEmpty;

  // ── fromMap ──────────────────────────────────────────────────────────────
  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? created;
    try {
      final raw = map['createdAt'];
      if (raw != null) {
        // Firestore Timestamp
        created = (raw as dynamic).toDate() as DateTime;
      }
    } catch (_) {
      try {
        // ISO string من SharedPreferences
        final s = map['createdAt']?.toString();
        if (s != null && s.isNotEmpty) { created = DateTime.tryParse(s); }
      } catch (_) {}
    }

    return UserModel(
      uid:              docId,
      name:             (map['name']             ?? '').toString(),
      email:            (map['email']            ?? '').toString(),
      phone:            (map['phone']            ?? '').toString(),
      role:             (map['role']             ?? 'customer').toString(),
      profileImage:     (map['profileImage']     ?? '').toString(),
      storeName:        (map['storeName']        ?? '').toString(),
      storeLogo:        (map['storeLogo']        ?? '').toString(),
      storeDescription: (map['storeDescription'] ?? '').toString(),
      storeLocation:    (map['storeLocation']    ?? '').toString(),
      isActive:         map['isActive'] != false,
      createdAt:        created,
    );
  }

  // ── toMap ────────────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'name':             name,
    'email':            email,
    'phone':            phone,
    'role':             role,
    'profileImage':     profileImage,
    'storeName':        storeName,
    'storeLogo':        storeLogo,
    'storeDescription': storeDescription,
    'storeLocation':    storeLocation,
    'isActive':         isActive,
    // createdAt يُحفظ كـ string في SharedPreferences
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  // ── copyWith ─────────────────────────────────────────────────────────────
  UserModel copyWith({
    String?   uid,
    String?   name,
    String?   email,
    String?   phone,
    String?   role,
    String?   profileImage,
    String?   storeName,
    String?   storeLogo,
    String?   storeDescription,
    String?   storeLocation,
    bool?     isActive,
    DateTime? createdAt,
  }) => UserModel(
    uid:              uid              ?? this.uid,
    name:             name             ?? this.name,
    email:            email            ?? this.email,
    phone:            phone            ?? this.phone,
    role:             role             ?? this.role,
    profileImage:     profileImage     ?? this.profileImage,
    storeName:        storeName        ?? this.storeName,
    storeLogo:        storeLogo        ?? this.storeLogo,
    storeDescription: storeDescription ?? this.storeDescription,
    storeLocation:    storeLocation    ?? this.storeLocation,
    isActive:         isActive         ?? this.isActive,
    createdAt:        createdAt        ?? this.createdAt,
  );
}
