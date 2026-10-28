class Product {
  final String id;
  final String name;
  final String brand;
  final String categoryId;
  final String categoryName;
  final String description;
  final double price;
  final int stock;
  final String imageUrl;

  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.price,
    required this.stock,
    this.imageUrl = '',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    double readPrice(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0;
    }

    int readInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    return Product(
      id: '${json['id'] ?? json['productId'] ?? ''}',
      name: '${json['name'] ?? json['productName'] ?? 'Sản phẩm'}',
      brand: '${json['brand'] ?? ''}',
      categoryId: '${json['categoryId'] ?? ''}',
      categoryName: '${json['categoryName'] ?? ''}',
      description: '${json['description'] ?? ''}',
      price: readPrice(json['price']),
      stock: readInt(json['stock']),
      imageUrl: '${json['imageUrl'] ?? ''}',
    );
  }
}