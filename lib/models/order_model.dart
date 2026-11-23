// lib/models/order_model.dart

class OrderItem {
  final String productId;
  final String name;
  final int quantity;
  final double price;
  final String image;

  // ═══════════════════════════════════════════════════════════════════
  //  ✅ Variant-aware Order — Universal Product Engine
  //  نسخة مستقلة تماماً (Snapshot) من بيانات التركيبة وقت الشراء —
  //  تُكتَب مرة واحدة إلى مستند الطلب في checkout_screen.dart، ولا تُقرأ
  //  أو تُشتق حياً من المنتج/التركيبة بعد تلك اللحظة إطلاقاً. حتى لو
  //  عُدِّل سعر المنتج، أو حُذفت التركيبة، أو أُعيدت تسمية الخاصية لاحقاً
  //  — سجل هذا الطلب يبقى صحيحاً تاريخياً كما كان وقت الشراء بالضبط.
  //  كلاهما null لمنتج تقليدي بلا متغيرات (توافق خلفي كامل).
  // ═══════════════════════════════════════════════════════════════════
  final String? variantId;
  final Map<String, String>? variantOptions; // {'اللون': 'أحمر', 'المقاس': 'XL'}

  OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.image,
    this.variantId,
    this.variantOptions,
  });

  double get total => price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 1,
      price: (map['price'] ?? 0).toDouble(),
      image: map['image'] ?? '',
      variantId: (map['variantId'] as String?)?.trim().isNotEmpty == true
          ? map['variantId'] as String
          : null,
      variantOptions: map['variantOptions'] != null
          ? Map<String, String>.from(map['variantOptions'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'quantity': quantity,
      'price': price,
      'image': image,
      if (variantId != null) 'variantId': variantId,
      if (variantOptions != null) 'variantOptions': variantOptions,
    };
  }
}

class ShippingAddress {
  final String fullName;
  final String phone;
  final String address;
  final String notes;
  final String locationLatLng; // ✅ "lat,lng" من الخريطة

  ShippingAddress({
    required this.fullName,
    required this.phone,
    required this.address,
    this.notes          = '',
    this.locationLatLng = '',
  });

  bool get hasLocation => locationLatLng.isNotEmpty;

  factory ShippingAddress.fromMap(Map<String, dynamic> map) {
    return ShippingAddress(
      fullName:       map['fullName']       ?? '',
      phone:          map['phone']          ?? '',
      address:        map['address']        ?? '',
      notes:          map['notes']          ?? '',
      locationLatLng: map['locationLatLng'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName':       fullName,
      'phone':          phone,
      'address':        address,
      'notes':          notes,
      'locationLatLng': locationLatLng,
    };
  }
}

class OrderModel {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String sellerId;
  final String sellerName;
  final List<OrderItem> products;
  final double totalAmount;
  final String paymentMethod;
  final String status;
  final ShippingAddress shippingAddress;
  final DateTime createdAt;
  // ✅ عملة هذا الطلب تحديداً (كل طلب يخص بائعاً واحداً وعملة واحدة فقط).
  final String currencyCode;
  final String currencySymbol;

  // ═══════════════════════════════════════════════════════════════════
  //  ✅ دورة الشراء الكاملة — حقول يكتبها السيرفر فقط (orders.js).
  //  كلها لها قيم افتراضية، فالطلبات القديمة تُقرأ بلا أي مشكلة.
  // ═══════════════════════════════════════════════════════════════════
  final double subtotal;
  final double shippingFee;
  /// unpaid | awaiting_verification | paid_held | cod_pending | cod_collected |
  /// released | refund_pending | refunded | partially_refunded | expired | void
  final String paymentStatus;
  final String paymentId;
  final String paymentReference;
  final String groupId;
  final String cancelReason;
  final String cancelledBy;
  final String deliveryMethod;
  final String trackingNumber;
  final String carrierName;
  final String disputeId;
  final double refundAmount;
  // إزالة أصناف قبل الشحن (إلغاء جزئي بالسطر)
  final double partialRefundDue;      // استرداد جزئي معلّق
  final bool partialRefundPending;
  final List<Map<String, dynamic>> removedItems; // [{name, quantity, price, reason}]
  final int deliveryAttempts;
  final DateTime? payDueAt;
  final DateTime? acceptDueAt;
  final DateTime? shipDueAt;
  final DateTime? deliveredAt;
  final DateTime? protectionUntil;
  final List<Map<String, dynamic>> timeline;

  // الحالات المتاحة
  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String shipped = 'shipped';
  static const String delivered = 'delivered';
  static const String cancelled = 'cancelled';
  static const String completed = 'completed';
  static const String deliveryFailed = 'delivery_failed';
  static const String disputed = 'disputed';

  static const String payCod = 'cash_on_delivery';
  static const String payHasab = 'hasab';

  OrderModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.sellerId,
    required this.sellerName,
    required this.products,
    required this.totalAmount,
    this.paymentMethod = 'cash_on_delivery',
    required this.status,
    required this.shippingAddress,
    required this.createdAt,
    this.currencyCode   = 'SAR',
    this.currencySymbol = 'ر.س',
    this.subtotal = 0,
    this.shippingFee = 0,
    this.paymentStatus = '',
    this.paymentId = '',
    this.paymentReference = '',
    this.groupId = '',
    this.cancelReason = '',
    this.cancelledBy = '',
    this.deliveryMethod = '',
    this.trackingNumber = '',
    this.carrierName = '',
    this.disputeId = '',
    this.refundAmount = 0,
    this.partialRefundDue = 0,
    this.partialRefundPending = false,
    this.removedItems = const [],
    this.deliveryAttempts = 0,
    this.payDueAt,
    this.acceptDueAt,
    this.shipDueAt,
    this.deliveredAt,
    this.protectionUntil,
    this.timeline = const [],
  });

  bool get isHasab => paymentMethod == payHasab;
  bool get isCod => paymentMethod == payCod;

  /// هل ينتظر الطلب دفع المشتري (لا يستطيع البائع قبوله بعد)؟
  bool get awaitingBuyerPayment =>
      status == pending &&
      (paymentStatus == 'unpaid' || paymentStatus == 'awaiting_verification');

  /// هل الطلب مغلق نهائياً؟
  bool get isFinal =>
      status == cancelled || status == completed || status == deliveryFailed;

  /// المشتري يستطيع الإلغاء: قبل القبول، أو بعد انتهاء مهلة الشحن.
  bool get customerCanCancel {
    if (status == pending) return true;
    if (status == confirmed && shipDueAt != null) {
      return DateTime.now().isAfter(shipDueAt!);
    }
    return false;
  }

  /// داخل مهلة الحماية بعد التسليم؟
  bool get inProtectionWindow =>
      status == delivered &&
      (protectionUntil == null || DateTime.now().isBefore(protectionUntil!));

  String get statusArabic {
    switch (status) {
      case pending:
        return awaitingBuyerPayment ? 'بانتظار الدفع' : 'طلب جديد';
      case confirmed:
        return 'قيد التجهيز';
      case shipped:
        return 'في الطريق';
      case delivered:
        return 'تم التسليم';
      case completed:
        return 'مكتمل';
      case cancelled:
        return 'ملغي';
      case deliveryFailed:
        return 'فشل التسليم';
      case disputed:
        return 'مشكلة قيد المراجعة';
      default:
        return 'غير معروف';
    }
  }

  String get paymentMethodArabic =>
      isHasab ? 'محفظة حاسب' : 'الدفع عند الاستلام';

  String get paymentStatusArabic {
    switch (paymentStatus) {
      case 'unpaid':
        return 'لم يُدفع';
      case 'awaiting_verification':
        return 'الإثبات قيد المراجعة';
      case 'paid_held':
        return 'مدفوع (محجوز لدى المنصة)';
      case 'cod_pending':
        return 'يُدفع عند الاستلام';
      case 'cod_collected':
        return 'تم التحصيل عند الاستلام';
      case 'released':
        return 'حُرّرت المستحقات للبائع';
      case 'refund_pending':
        return 'استرداد قيد التنفيذ';
      case 'refunded':
        return 'تم الاسترداد';
      case 'partially_refunded':
        return 'استرداد جزئي';
      case 'expired':
        return 'انتهت مهلة الدفع';
      default:
        return '';
    }
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    double d(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    final total = d(map['totalAmount']);
    return OrderModel(
      id: id,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      products: (map['products'] as List<dynamic>? ?? [])
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      totalAmount: total,
      paymentMethod: map['paymentMethod'] ?? 'cash_on_delivery',
      status: map['status'] ?? pending,
      shippingAddress: ShippingAddress.fromMap(
          Map<String, dynamic>.from(map['shippingAddress'] as Map? ?? {})),
      createdAt: _dt(map['createdAt']) ?? DateTime.now(),
      currencyCode:   (map['currencyCode']   ?? 'SAR').toString(),
      currencySymbol: (map['currencySymbol'] ?? 'ر.س').toString(),
      subtotal: map['subtotal'] != null ? d(map['subtotal']) : total,
      shippingFee: d(map['shippingFee']),
      paymentStatus: (map['paymentStatus'] ?? '').toString(),
      paymentId: (map['paymentId'] ?? '').toString(),
      paymentReference: (map['paymentReference'] ?? '').toString(),
      groupId: (map['groupId'] ?? '').toString(),
      cancelReason: (map['cancelReason'] ?? '').toString(),
      cancelledBy: (map['cancelledBy'] ?? '').toString(),
      deliveryMethod: (map['deliveryMethod'] ?? '').toString(),
      trackingNumber: (map['trackingNumber'] ?? '').toString(),
      carrierName: (map['carrierName'] ?? '').toString(),
      disputeId: (map['disputeId'] ?? '').toString(),
      refundAmount: d(map['refundAmount']),
      partialRefundDue: d(map['partialRefundDue']),
      partialRefundPending: map['partialRefundPending'] == true,
      removedItems: (map['removedItems'] is List)
          ? (map['removedItems'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [],
      deliveryAttempts: (map['deliveryAttempts'] as num?)?.toInt() ?? 0,
      payDueAt: _dt(map['payDueAt']),
      acceptDueAt: _dt(map['acceptDueAt']),
      shipDueAt: _dt(map['shipDueAt']),
      deliveredAt: _dt(map['deliveredAt']),
      protectionUntil: _dt(map['protectionUntil']),
      timeline: (map['timeline'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  /// ⚠️ للقراءة/العرض فقط — إنشاء الطلبات يتم من السيرفر (POST /orders/create)
  /// والقواعد تمنع أي كتابة مباشرة من العميل على مجموعة orders.
  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'products': products.map((e) => e.toMap()).toList(),
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'status': status,
      'shippingAddress': shippingAddress.toMap(),
      'createdAt': createdAt,
      'currencyCode': currencyCode,
      'currencySymbol': currencySymbol,
    };
  }
}
