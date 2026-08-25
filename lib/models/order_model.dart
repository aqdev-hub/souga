// lib/models/order_model.dart

class OrderItem {
  final String productId;
  final String name;
  final int quantity;
  final double price;
  final String image;

  OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.image,
  });

  double get total => price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 1,
      price: (map['price'] ?? 0).toDouble(),
      image: map['image'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'quantity': quantity,
      'price': price,
      'image': image,
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
  // ✅ جديد — عملة هذا الطلب تحديداً (كل طلب الآن يخص بائعاً واحداً
  // وعملة واحدة فقط، بدل افتراض عملة أول عنصر في السلة كما كان سابقاً).
  final String currencyCode;
  final String currencySymbol;

  // الحالات المتاحة
  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String shipped = 'shipped';
  static const String delivered = 'delivered';
  static const String cancelled = 'cancelled';

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
  });

  String get statusArabic {
    switch (status) {
      case pending:
        return 'قيد الانتظار';
      case confirmed:
        return 'تم التأكيد';
      case shipped:
        return 'تم الشحن';
      case delivered:
        return 'تم التوصيل';
      case cancelled:
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      products: (map['products'] as List<dynamic>? ?? [])
          .map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? 'cash_on_delivery',
      status: map['status'] ?? pending,
      shippingAddress: ShippingAddress.fromMap(
          map['shippingAddress'] as Map<String, dynamic>? ?? {}),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      currencyCode:   (map['currencyCode']   ?? 'SAR').toString(),
      currencySymbol: (map['currencySymbol'] ?? 'ر.س').toString(),
    );
  }

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
