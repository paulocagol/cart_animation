import 'package:flutter/material.dart';

class Product {
  final String id;
  final String image;
  final GlobalKey key;

  Product({required this.id, required this.image, required this.key});

  @override
  String toString() {
    return 'Product{id: $id, image: $image, key: $key}';
  }
}
