// lib/providers/product_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<ProductModel> _products = [];
  List<ProductModel> _searchResults = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<ProductModel> get products => _products;
  List<ProductModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  Stream<List<ProductModel>> getLatestProducts() {
    return _firestore.collection('products')
        .orderBy('createdAt', descending: true).limit(10).snapshots()
        .map((s) => s.docs.map((d) => ProductModel.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<ProductModel>> getSellerProducts(String sellerId) {
    return _firestore.collection('products')
        .where('sellerId', isEqualTo: sellerId).snapshots()
        .map((s) => s.docs.map((d) => ProductModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> searchProducts(String query) async {
    _searchQuery = query;
    if (query.isEmpty) { _searchResults = []; notifyListeners(); return; }
    _isLoading = true;
    notifyListeners();
    try {
      final snap = await _firestore.collection('products').get();
      _searchResults = snap.docs.map((d) => ProductModel.fromMap(d.data(), d.id))
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()) ||
              p.description.toLowerCase().contains(query.toLowerCase())).toList();
    } catch (e) { _searchResults = []; }
    _isLoading = false;
    notifyListeners();
  }
}
