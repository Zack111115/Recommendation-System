class Recommendation {
  final String productId;
  final String productName;
  final String brand;
  final double price;
  final int stock;

  final String categoryId;
  final String categoryName;
  final String imageUrl;

  final String sourceType;
  final String sourceLabel;
  final String reason;
  final int score;

  final int supportCount;
  final int sharedProductCount;

  final List<String> supportingCustomers;
  final List<String> sharedPurchaseEvidence;
  final List<String> evidence;

  const Recommendation({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.price,
    this.stock = 0,
    this.categoryId = '',
    this.categoryName = '',
    this.imageUrl = '',
    this.sourceType = 'COLLABORATIVE_FILTERING',
    this.sourceLabel = 'Dựa trên lịch sử mua',
    this.reason = 'Chưa có giải thích',
    this.score = 0,
    this.supportCount = 0,
    this.sharedProductCount = 0,
    this.supportingCustomers = const [],
    this.sharedPurchaseEvidence = const [],
    this.evidence = const [],
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    int readInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    double readDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0;
    }

    List<String> readStrings(dynamic value) {
      if (value is! List) return [];

      return value
          .map((item) => '$item')
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }

    final sourceType =
        '${json['sourceType'] ?? 'COLLABORATIVE_FILTERING'}';

    final sourceLabel = '${json['sourceLabel'] ??
        _defaultSourceLabel(sourceType)}';

    final evidence = readStrings(json['evidence']);

    return Recommendation(
      productId: '${json['productId'] ?? json['id'] ?? ''}',
      productName:
          '${json['productName'] ?? json['name'] ?? 'Sản phẩm'}',
      brand: '${json['brand'] ?? ''}',
      price: readDouble(json['price']),
      stock: readInt(json['stock']),
      categoryId: '${json['categoryId'] ?? ''}',
      categoryName: '${json['categoryName'] ?? ''}',
      imageUrl: '${json['imageUrl'] ?? ''}',
      sourceType: sourceType,
      sourceLabel: sourceLabel,
      reason: '${json['reason'] ?? 'Chưa có giải thích'}',
      score: readInt(json['score']),
      supportCount: readInt(json['supportCount']),
      sharedProductCount: readInt(json['sharedProductCount']),
      supportingCustomers:
          readStrings(json['supportingCustomers']),
      sharedPurchaseEvidence: readStrings(
        json['sharedPurchaseEvidence'] ?? evidence,
      ),
      evidence: evidence,
    );
  }

  static String _defaultSourceLabel(String type) {
    switch (type) {
      case 'COLLABORATIVE_FILTERING':
        return 'Dựa trên lịch sử mua';
      case 'VIEWED_SIMILAR':
        return 'Dựa trên lượt xem';
      case 'CO_PURCHASE':
        return 'Thường được mua cùng';
      case 'COMPLEMENTARY_TO':
        return 'Sản phẩm bổ trợ';
      case 'SIMILAR_FUNCTION':
        return 'Cùng công dụng';
      case 'ALTERNATIVE_TO':
        return 'Sản phẩm thay thế';
      case 'SAME_CATEGORY':
        return 'Cùng danh mục';
      case 'SAME_BRAND':
        return 'Cùng thương hiệu';
      case 'HISTORY_CATEGORY':
        return 'Theo lịch sử của bạn';
      case 'POPULAR':
        return 'Phổ biến';
      default:
        return 'Gợi ý từ Neo4j';
    }
  }
}