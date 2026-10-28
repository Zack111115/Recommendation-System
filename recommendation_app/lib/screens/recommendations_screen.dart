import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';

class RecommendationsScreen extends StatefulWidget {
  final String customerId;
  final List<Product> products;
  final ValueChanged<Product> onProductTap;
  final ValueChanged<Product> onAddToCart;
  final int refreshToken;

  const RecommendationsScreen({
    super.key,
    required this.customerId,
    required this.products,
    required this.onProductTap,
    required this.onAddToCart,
    required this.refreshToken,
  });

  @override
  State<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  int _newSeed() => 1;

  @override
  void initState() {
    super.initState();
    loadRecommendations();
  }

  @override
  void didUpdateWidget(
    covariant RecommendationsScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.customerId != widget.customerId ||
        oldWidget.refreshToken != widget.refreshToken) {
      loadRecommendations();
    }
  }

  String _labelFor(Map<String, dynamic> item) {
    final label = '${item['sourceLabel'] ?? ''}'.trim();
    if (label.isNotEmpty) return label;

    switch ('${item['sourceType'] ?? ''}') {
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
        return 'Có thể bạn quan tâm';
    }
  }

  List<Map<String, dynamic>> _cleanFeed(
    List<Map<String, dynamic>> incoming,
  ) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final raw in incoming) {
      final item = Map<String, dynamic>.from(raw);
      final id =
          '${item['productId'] ?? item['id'] ?? ''}'.trim();
      final product = Product.fromJson(item);

      if (id.isEmpty || product.stock <= 0 || !seen.add(id)) {
        continue;
      }

      item['productId'] = id;
      item['sourceLabel'] = _labelFor(item);
      result.add(item);
    }

    return result;
  }

  Future<void> loadRecommendations() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await ApiService.getRecommendationFeed(
        customerId: widget.customerId,
        limit: 24,
        seed: _newSeed(),
      );

      if (!mounted) return;

      setState(() {
        items = _cleanFeed(data);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadRecommendations,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gợi ý dành riêng cho bạn',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Nhiều nguồn gợi ý · Theo tài khoản và sản phẩm',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Đổi gợi ý',
                onPressed: loading ? null : loadRecommendations,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _SourceChip(label: 'Lịch sử mua'),
              _SourceChip(label: 'Lượt xem'),
              _SourceChip(label: 'Mua cùng'),
              _SourceChip(label: 'Sản phẩm bổ trợ'),
              _SourceChip(label: 'Cùng danh mục'),
              _SourceChip(label: 'Phổ biến'),
            ],
          ),
          const SizedBox(height: 20),
          if (loading && items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (items.isNotEmpty)
            _productGrid(items)
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                error == null
                    ? 'Chưa có sản phẩm gợi ý khả dụng cho '
                        '${widget.customerId}.'
                    : 'Không tải được feed gợi ý:\n$error',
                style: const TextStyle(height: 1.6),
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            'Các nhãn trên thẻ cho biết nguồn gợi ý mà backend trả về. '
            'Sản phẩm hết hàng và sản phẩm đang xem sẽ không được '
            'hiển thị trong danh sách này.',
            style: TextStyle(
              color: Colors.black54,
              height: 1.6,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productGrid(List<Map<String, dynamic>> feedItems) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 4
            : width >= 760
                ? 3
                : width >= 480
                    ? 2
                    : 1;

        const spacing = 14.0;
        final cardWidth =
            (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: feedItems.map((item) {
            final product = Product.fromJson(item);
            final reason = '${item['reason'] ?? ''}'.trim();

            return SizedBox(
              width: cardWidth,
              height: 405,
              child: Column(
                children: [
                  Expanded(
                    child: ProductCard(
                      product: product,
                      recommendationLabel: _labelFor(item),
                      onTap: () => widget.onProductTap(product),
                      onAddToCart: () =>
                          widget.onAddToCart(product),
                    ),
                  ),
                  if (reason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          reason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;

  const _SourceChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDFF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6558E8),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}