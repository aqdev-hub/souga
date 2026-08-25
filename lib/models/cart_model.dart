// lib/models/cart_model.dart

class CartItem {
  final String productId;
  final String name;
  final double price;
  int quantity;
  final String image;
  final String sellerId;
  final String sellerName;
  final String currencySymbol;  // ✅ عملة المنتج الأصلية
  final String currencyCode;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.image,
    required this.sellerId,
    required this.sellerName,
    this.currencySymbol = 'RS',
    this.currencyCode   = 'SAR',
  });

  double get total => price * quantity;

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productId:      map['productId']      ?? '',
      name:           map['name']           ?? '',
      price:          (map['price']         ?? 0).toDouble(),
      quantity:       map['quantity']       ?? 1,
      image:          map['image']          ?? '',
      sellerId:       map['sellerId']       ?? '',
      sellerName:     map['sellerName']     ?? '',
      currencySymbol: map['currencySymbol'] ?? 'RS',
      currencyCode:   map['currencyCode']   ?? 'SAR',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId':      productId,
      'name':           name,
      'price':          price,
      'quantity':       quantity,
      'image':          image,
      'sellerId':       sellerId,
      'sellerName':     sellerName,
      'currencySymbol': currencySymbol,
      'currencyCode':   currencyCode,
    };
  }
}
