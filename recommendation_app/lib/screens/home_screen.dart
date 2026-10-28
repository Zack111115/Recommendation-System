
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  final String customerId;
  final List<Product> products;
  final List<Map<String, dynamic>> categories;
  final ValueChanged<Product> onProductTap;
  final ValueChanged<Product> onAddToCart;
  final VoidCallback onSeeRecommendations;
  final int refreshToken;

  const HomeScreen({
    super.key,
    required this.customerId,
    required this.products,
    required this.categories,
    required this.onProductTap,
    required this.onAddToCart,
    required this.onSeeRecommendations,
    required this.refreshToken,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> recommendations = [];
  bool loadingRecommendations = true;
  bool loadingMoreRecommendations = false;
  bool hasMoreRecommendations = true;
  String? recommendationError;

  int recommendationOffset = 0;
  int seed = 1;

  final Set<String> _seenRecommendationIds = <String>{};

  static const int pageSize = 24;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    loadRecommendations(reset: true);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.customerId != widget.customerId ||
        oldWidget.refreshToken != widget.refreshToken) {
      loadRecommendations(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.extentAfter < 900) {
      if (!loadingMoreRecommendations &&
          !loadingRecommendations &&
          hasMoreRecommendations) {
        loadRecommendations();
      }
    }
  }

  String _labelFor(Map<String, dynamic> item) {
    final label = '${item['sourceLabel'] ?? ''}'.trim();
    if (label.isNotEmpty) return label;

    switch ('${item['sourceType'] ?? ''}'.toUpperCase()) {
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
        return 'Gợi ý cho bạn';
    }
  }

  List<Map<String, dynamic>> _cleanFeed(
    List<Map<String, dynamic>> incoming,
  ) {
    final result = <Map<String, dynamic>>[];

    for (final raw in incoming) {
      final item = Map<String, dynamic>.from(raw);
      final id = '${item['productId'] ?? item['id'] ?? ''}'.trim();

      if (id.isEmpty || !_seenRecommendationIds.add(id.toUpperCase())) {
        continue;
      }

      final product = _findProduct(id, item);

      if (product == null || product.stock <= 0) {
        _seenRecommendationIds.remove(id.toUpperCase());
        continue;
      }

      result.add({
        ...item,
        'id': product.id,
        'productId': product.id,
        'name': product.name,
        'productName': product.name,
        'brand': product.brand,
        'categoryId': product.categoryId,
        'categoryName': product.categoryName,
        'description': product.description,
        'price': product.price,
        'stock': product.stock,
        'imageUrl': product.imageUrl,
        'sourceLabel': _labelFor(item),
      });
    }

    return result;
  }

  Product? _findProduct(
    String id,
    Map<String, dynamic> feedItem,
  ) {
    for (final product in widget.products) {
      if (product.id.toUpperCase() == id.toUpperCase()) {
        return product;
      }
    }

    try {
      final parsed = Product.fromJson(feedItem);
      if (parsed.id.isNotEmpty && parsed.stock > 0) {
        return parsed;
      }
    } catch (_) {
      // Bỏ qua dữ liệu feed không hợp lệ.
    }

    return null;
  }

  Future<void> loadRecommendations({bool reset = false}) async {
    if (!mounted) return;

    if (reset) {
      _seenRecommendationIds.clear();
      recommendationOffset = 0;
      hasMoreRecommendations = true;
      seed = DateTime.now().microsecondsSinceEpoch % 2147483647;

      setState(() {
        recommendations = [];
        loadingRecommendations = true;
        loadingMoreRecommendations = false;
        recommendationError = null;
      });
    } else {
      if (loadingRecommendations ||
          loadingMoreRecommendations ||
          !hasMoreRecommendations) {
        return;
      }

      setState(() {
        loadingMoreRecommendations = true;
        recommendationError = null;
      });
    }

    final requestedOffset = recommendationOffset;

    try {
      final data = await ApiService.getRecommendationFeed(
        customerId: widget.customerId,
        offset: requestedOffset,
        limit: pageSize,
        seed: seed,
      );

      if (!mounted) return;

      final cleaned = _cleanFeed(data);

      setState(() {
        recommendations.addAll(cleaned);
        recommendationOffset += data.length;

        // Nếu API không trả đủ một trang, đã tới cuối feed.
        hasMoreRecommendations = data.length >= pageSize;

        loadingRecommendations = false;
        loadingMoreRecommendations = false;
      });

      // Nếu trang API có dữ liệu nhưng tất cả đều trùng hoặc hết hàng,
      // tự thử trang tiếp theo để tránh kẹt ở cuối danh sách.
      if (data.isNotEmpty &&
          cleaned.isEmpty &&
          hasMoreRecommendations) {
        loadRecommendations();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        recommendationError = e.toString();
        loadingRecommendations = false;
        loadingMoreRecommendations = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableProducts = widget.products
        .where((product) => product.stock > 0)
        .toList();

    final recommendedIds = recommendations
        .map((item) =>
            '${item['productId'] ?? item['id'] ?? ''}'.toUpperCase())
        .toSet();

    final catalogProducts = availableProducts
        .where((product) =>
            !recommendedIds.contains(product.id.toUpperCase()))
        .toList();

    return RefreshIndicator(
      onRefresh: () => loadRecommendations(reset: true),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF292947),
                  Color(0xFF6558E8),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'SMART SHOPPING · NEO4J',
                    style: TextStyle(
                      color: Colors.white,
                      letterSpacing: 1.2,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Xin chào, ${widget.customerId}.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Khám phá điều\nphù hợp với bạn.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Gợi ý được cá nhân hóa theo lịch sử xem, '
                  'lịch sử mua và sản phẩm liên quan.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: widget.onSeeRecommendations,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Gợi ý của tôi'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => loadRecommendations(reset: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Làm mới gợi ý'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _sectionHeader(
            'Danh mục sản phẩm',
            'Khám phá theo nhu cầu',
          ),
          const SizedBox(height: 14),
          if (widget.categories.isEmpty)
            _emptyPanel('Chưa tải được danh mục.')
          else
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final category = widget.categories[index];
                  final id = '${category['id'] ?? ''}';
                  final name = '${category['name'] ?? id}';

                  final colorProduct = Product(
                    id: id,
                    name: name,
                    brand: '',
                    description: '',
                    price: 0,
                    stock: 0,
                    categoryId: id,
                    categoryName: name,
                    imageUrl: '',
                  );

                  final accent = categoryColor(colorProduct);
                  final light = Color.alphaBlend(
                    accent.withValues(alpha: 0.12),
                    Colors.white,
                  );

                  return Container(
                    width: 155,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: light,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.category_outlined,
                            size: 20,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 32),
          _sectionHeader(
            'Gợi ý dành riêng cho bạn',
            'Theo tài khoản ${widget.customerId} · Tự tải thêm khi cuộn',
            onSeeAll: widget.onSeeRecommendations,
          ),
          const SizedBox(height: 14),
          if (loadingRecommendations && recommendations.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (recommendations.isNotEmpty)
            _recommendedGrid(recommendations)
          else
            _emptyPanel(
              recommendationError == null
                  ? 'Chưa tìm được sản phẩm gợi ý khả dụng.'
                  : 'Không tải được gợi ý:\n$recommendationError',
            ),
          if (loadingMoreRecommendations)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (recommendationError != null && recommendations.isNotEmpty)
            TextButton.icon(
              onPressed: loadRecommendations,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử tải thêm'),
            ),
          if (!hasMoreRecommendations && recommendations.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Đã hiển thị hết gợi ý mà hệ thống tìm được.',
                  style: TextStyle(color: Colors.black45),
                ),
              ),
            ),
          const SizedBox(height: 32),
          _sectionHeader(
            'Khám phá sản phẩm',
            '${catalogProducts.length} sản phẩm còn lại trong danh mục cửa hàng',
          ),
          const SizedBox(height: 14),
          if (catalogProducts.isEmpty)
            _emptyPanel('Không còn sản phẩm khả dụng để hiển thị.')
          else
            _catalogGrid(catalogProducts),
        ],
      ),
    );
  }

  Widget _sectionHeader(
    String title,
    String subtitle, {
    VoidCallback? onSeeAll,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text('Xem tất cả →'),
          ),
      ],
    );
  }

  Widget _recommendedGrid(List<Map<String, dynamic>> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1050
            ? 4
            : width >= 700
                ? 3
                : width >= 430
                    ? 2
                    : 1;

        const spacing = 14.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            final product = Product.fromJson(item);

            return SizedBox(
              width: cardWidth,
              height: 365,
              child: ProductCard(
                product: product,
                recommendationLabel: _labelFor(item),
                onTap: () => widget.onProductTap(product),
                onAddToCart: () => widget.onAddToCart(product),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _catalogGrid(List<Product> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1050
            ? 4
            : width >= 700
                ? 3
                : width >= 430
                    ? 2
                    : 1;

        const spacing = 14.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((product) {
            return SizedBox(
              width: cardWidth,
              height: 365,
              child: ProductCard(
                product: product,
                onTap: () => widget.onProductTap(product),
                onAddToCart: () => widget.onAddToCart(product),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _emptyPanel(String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EAF2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          height: 1.6,
          color: Colors.black54,
        ),
      ),
    );
  }
}
