import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final String customerId;
  final VoidCallback onAddToCart;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<Product>? onAddProductToCart;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.customerId,
    required this.onAddToCart,
    required this.onOpenProduct,
    this.onAddProductToCart,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> boughtTogether = [];
  List<Map<String, dynamic>> recommendations = [];
  List<Product> allProducts = [];
  List<Product> fallbackBoughtTogether = [];

  bool loadingRelated = true;
  bool loadingMore = false;
  bool hasMore = false;
  String? relatedError;
  int offset = 0;
  int seed = DateTime.now().microsecondsSinceEpoch % 2147483647;
  int _loadGeneration = 0;

  static const int pageSize = 24;
  static const int maxInitialRecommendations = 8;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
    _recordView();
  }

  @override
  void didUpdateWidget(covariant ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id ||
        oldWidget.customerId != widget.customerId) {
      _resetForCurrentProduct();
      _loadInitialData();
      _recordView();
    }
  }

  void _resetForCurrentProduct() {
    _loadGeneration++;
    setState(() {
      boughtTogether = [];
      recommendations = [];
      allProducts = [];
      fallbackBoughtTogether = [];
      loadingRelated = true;
      loadingMore = false;
      hasMore = false;
      relatedError = null;
      offset = 0;
      seed = DateTime.now().microsecondsSinceEpoch % 2147483647;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _recordView() async {
    try {
      await ApiService.recordView(
        customerId: widget.customerId,
        productId: widget.product.id,
        sessionId: 'SESSION-${DateTime.now().millisecondsSinceEpoch}',
      );
      debugPrint(
        '[VIEW SAVED] customer=${widget.customerId}, '
        'product=${widget.product.id}',
      );
    } catch (e) {
      debugPrint('[VIEW ERROR] ${widget.product.id}: $e');
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    final currentProduct = widget.product;
    final currentCustomerId = widget.customerId;
    final currentSeed = seed;

    setState(() {
      loadingRelated = true;
      loadingMore = false;
      relatedError = null;
      offset = 0;
      hasMore = false;
    });

    List<Product> catalog = [];
    List<Map<String, dynamic>> boughtRaw = [];
    List<Map<String, dynamic>> feedRaw = [];
    String? feedError;

    // Doc tung API rieng de loi API mua kem khong lam mat feed goi y.
    try {
      catalog = await ApiService.getProducts();
    } catch (e) {
      debugPrint('[DETAIL PRODUCTS ERROR] $e');
    }
    if (!mounted || generation != _loadGeneration) return;

    try {
      boughtRaw = await ApiService.getBoughtTogether(currentProduct.id);
    } catch (e) {
      debugPrint('[BOUGHT TOGETHER ERROR] $e');
    }
    if (!mounted || generation != _loadGeneration) return;

    try {
      feedRaw = await ApiService.getRecommendationFeed(
        customerId: currentCustomerId,
        contextProductId: currentProduct.id,
        offset: 0,
        limit: pageSize,
        seed: currentSeed,
      );
    } catch (e) {
      feedError = e.toString();
    }
    if (!mounted || generation != _loadGeneration) return;

    final hydratedBought = _hydrateBoughtTogether(boughtRaw, catalog)
        .where((item) => item['id'] != currentProduct.id)
        .take(4)
        .toList();

    final bundleFallback = hydratedBought.isEmpty
        ? _buildFallbackBundle(currentProduct, catalog)
        : <Product>[];

    final excluded = <String>{
      currentProduct.id.toUpperCase(),
      ...hydratedBought.map((item) => '${item['id']}'.toUpperCase()),
      ...bundleFallback.map((p) => p.id.toUpperCase()),
    };

    var cleanedFeed = _cleanFeed(
      feedRaw,
      excludedIds: excluded,
      catalogOverride: catalog,
    );
    if (cleanedFeed.length < maxInitialRecommendations) {
      final known = <String>{
        ...excluded,
        ...cleanedFeed.map((item) => '${item['productId']}'.toUpperCase()),
      };
      cleanedFeed.addAll(
        _buildFallbackRecommendations(currentProduct, catalog,
          excludedIds: known)
          .take(maxInitialRecommendations - cleanedFeed.length),
      );
    }

    setState(() {
      allProducts = catalog;
      boughtTogether = hydratedBought;
      fallbackBoughtTogether = bundleFallback;
      recommendations = cleanedFeed.take(maxInitialRecommendations).toList();
      offset = feedRaw.length;
      hasMore = feedRaw.length >= pageSize;
      loadingRelated = false;
      relatedError = feedError;
    });
  }

  Map<String, dynamic> _productAsMap(Product p) => <String, dynamic>{
        'id': p.id,
        'productId': p.id,
        'name': p.name,
        'productName': p.name,
        'brand': p.brand,
        'categoryId': p.categoryId,
        'categoryName': p.categoryName,
        'description': p.description,
        'price': p.price,
        'stock': p.stock,
        'imageUrl': p.imageUrl,
      };

  List<Map<String, dynamic>> _hydrateBoughtTogether(
    List<Map<String, dynamic>> incoming,
    List<Product> catalog,
  ) {
    final byId = <String, Product>{
      for (final p in catalog) p.id.toUpperCase(): p,
    };
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final raw in incoming) {
      final id = '${raw['productId'] ?? raw['id'] ?? ''}'.trim();
      if (id.isEmpty || !seen.add(id.toUpperCase())) continue;

      // Endpoint mua kem hien tra productId/productName/price/orderCount,
      // khong tra stock/category. Ghép lai voi catalog truoc khi dung ProductCard.
      final product = byId[id.toUpperCase()];
      if (product == null || product.stock <= 0 ||
          product.id == widget.product.id) {
        continue;
      }

      final hydrated = _productAsMap(product)
        ..['orderCount'] = raw['orderCount'] ?? raw['coOrderCount'] ?? 0
        ..['reason'] = raw['reason'] ?? 'Xuất hiện trong cùng đơn hàng';
      result.add(hydrated);
    }

    result.sort((a, b) {
      final aCount = int.tryParse('${a['orderCount']}') ?? 0;
      final bCount = int.tryParse('${b['orderCount']}') ?? 0;
      return bCount.compareTo(aCount);
    });
    return result;
  }

  Set<String> _complementaryCategoryIds(Product product) {
    switch (product.categoryId.toUpperCase()) {
      case 'CAT01': // Laptop may tinh -> phu kien may tinh
        return {'CAT02'};
      case 'CAT02': // Phu kien may tinh -> thiet bi may tinh
        return {'CAT01'};
      case 'CAT03': // Dien thoai -> phu kien dien thoai
        return {'CAT04'};
      case 'CAT04': // Phu kien dien thoai -> dien thoai
        return {'CAT03'};
      case 'CAT08': // Do uong -> do an nhe
        return {'CAT12'};
      case 'CAT12': // Do an nhe -> do uong
        return {'CAT08'};
      default:
        return <String>{};
    }
  }

  int _bundleRelevanceScore(Product base, Product candidate) {
    if (candidate.id == base.id || candidate.stock <= 0) return -1;
    final complementIds = _complementaryCategoryIds(base);
    if (complementIds.contains(candidate.categoryId.toUpperCase())) return 100;
    if (base.categoryId.isNotEmpty &&
        candidate.categoryId.isNotEmpty &&
        candidate.categoryId == base.categoryId) {
      return 35; // Chi la phuong an lien quan, khong khang dinh mua cung.
    }
    if (base.brand.isNotEmpty &&
        base.brand.toLowerCase() == candidate.brand.toLowerCase()) {
      return 20;
    }
    return -1;
  }

  List<Product> _buildFallbackBundle(Product base, List<Product> catalog) {
    final scored = <({Product product, int score})>[];
    for (final candidate in catalog) {
      final score = _bundleRelevanceScore(base, candidate);
      if (score > 0) scored.add((product: candidate, score: score));
    }
    scored.sort((a, b) {
      final compareScore = b.score.compareTo(a.score);
      if (compareScore != 0) return compareScore;
      return a.product.id.compareTo(b.product.id);
    });
    return scored.map((entry) => entry.product).take(4).toList();
  }

  int _contextRelevanceScore(
    Product base,
    Product candidate,
    String sourceType,
  ) {
    if (candidate.id == base.id || candidate.stock <= 0) return -1;
    final type = sourceType.toUpperCase();

    // Neu co canh quan he trong graph, uu tien cac nguon truc tiep theo context.
    if (type == 'CO_PURCHASE') return 130;
    if (type == 'COMPLEMENTARY_TO') return 120;
    if (type == 'SIMILAR_FUNCTION') return 110;
    if (type == 'ALTERNATIVE_TO') return 100;

    final complementIds = _complementaryCategoryIds(base);
    if (complementIds.contains(candidate.categoryId.toUpperCase())) return 90;

    if (base.categoryId.isNotEmpty &&
        candidate.categoryId.isNotEmpty &&
        candidate.categoryId == base.categoryId) {
      return 80;
    }

    if (base.brand.trim().isNotEmpty &&
        candidate.brand.trim().isNotEmpty &&
        base.brand.toLowerCase() == candidate.brand.toLowerCase()) {
      return 65;
    }

    // Khong hien san pham pho bien/lich su khong lien quan den mon dang xem.
    return -1;
  }

  List<Map<String, dynamic>> _cleanFeed(
    List<Map<String, dynamic>> incoming, {
    Set<String> excludedIds = const <String>{},
    List<Product>? catalogOverride,
  }) {
    final seen = <String>{
      ...excludedIds.map((id) => id.toUpperCase()),
      ...recommendations.map((item) =>
          '${item['productId'] ?? item['id'] ?? ''}'.toUpperCase()),
    };
    final catalog = catalogOverride ?? allProducts;
    final byId = <String, Product>{
      for (final p in catalog) p.id.toUpperCase(): p,
    };
    final scored = <({Map<String, dynamic> item, int relevance})>[];

    for (final raw in incoming) {
      final item = Map<String, dynamic>.from(raw);
      final id = '${item['productId'] ?? item['id'] ?? ''}'.trim();
      if (id.isEmpty || !seen.add(id.toUpperCase())) continue;

      final product = byId[id.toUpperCase()] ?? Product.fromJson(item);
      if (product.stock <= 0 || product.id == widget.product.id) continue;

      final sourceType = '${item['sourceType'] ?? ''}';
      final relevance = _contextRelevanceScore(
        widget.product,
        product,
        sourceType,
      );
      if (relevance < 0) continue;

      final enriched = <String, dynamic>{
        ...item,
        ..._productAsMap(product),
        'productId': product.id,
        'sourceType': sourceType.isEmpty ? 'SAME_CATEGORY' : sourceType,
        'sourceLabel': '${item['sourceLabel'] ?? ''}'.trim().isNotEmpty
            ? item['sourceLabel']
            : _labelFor(item),
        '_contextRelevance': relevance,
      };
      scored.add((item: enriched, relevance: relevance));
    }

    scored.sort((a, b) {
      final relevanceCompare = b.relevance.compareTo(a.relevance);
      if (relevanceCompare != 0) return relevanceCompare;
      final aScore = int.tryParse('${a.item['score'] ?? 0}') ?? 0;
      final bScore = int.tryParse('${b.item['score'] ?? 0}') ?? 0;
      final scoreCompare = bScore.compareTo(aScore);
      if (scoreCompare != 0) return scoreCompare;
      return '${a.item['productId']}'.compareTo('${b.item['productId']}');
    });

    return scored.map((entry) {
      final item = entry.item;
      item.remove('_contextRelevance');
      item['sourceLabel'] = _labelFor(item);
      return item;
    }).toList();
  }

  List<Map<String, dynamic>> _buildFallbackRecommendations(
    Product base,
    List<Product> catalog, {
    Set<String> excludedIds = const <String>{},
  }) {
    final excluded = excludedIds.map((id) => id.toUpperCase()).toSet();
    final scored = <({Product product, int score})>[];

    for (final candidate in catalog) {
      if (excluded.contains(candidate.id.toUpperCase()) ||
          candidate.stock <= 0 || candidate.id == base.id) {
        continue;
      }

      var score = -1;
      if (base.categoryId.isNotEmpty &&
          candidate.categoryId.isNotEmpty &&
          candidate.categoryId == base.categoryId) {
        score = 80;
      } else if (base.brand.trim().isNotEmpty &&
          candidate.brand.trim().isNotEmpty &&
          base.brand.toLowerCase() == candidate.brand.toLowerCase()) {
        score = 60;
      }
      if (score > 0) scored.add((product: candidate, score: score));
    }

    scored.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.product.id.compareTo(b.product.id);
    });

    return scored.take(maxInitialRecommendations).map((entry) {
      final p = entry.product;
      final sameCategory = p.categoryId == base.categoryId;
      return <String, dynamic>{
        ..._productAsMap(p),
        'productId': p.id,
        'sourceType': sameCategory ? 'SAME_CATEGORY' : 'SAME_BRAND',
        'sourceLabel': sameCategory ? 'Cùng danh mục' : 'Cùng thương hiệu',
        'reason': sameCategory
            ? 'Sản phẩm cùng danh mục với ${base.name}'
            : 'Sản phẩm cùng thương hiệu với ${base.name}',
        'score': entry.score,
      };
    }).toList();
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
        return 'Sản phẩm liên quan';
    }
  }

  Set<String> _bundleProductIds() {
    return <String>{
      widget.product.id.toUpperCase(),
      ...boughtTogether.map((item) => '${item['id'] ?? item['productId'] ?? ''}'.toUpperCase()),
      ...fallbackBoughtTogether.map((item) => item.id.toUpperCase()),
    };
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        loadingRelated || loadingMore || !hasMore) {
      return;
    }
    if (_scrollController.position.extentAfter < 700) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (loadingMore || !hasMore) return;
    final generation = _loadGeneration;
    setState(() => loadingMore = true);

    try {
      final data = await ApiService.getRecommendationFeed(
        customerId: widget.customerId,
        contextProductId: widget.product.id,
        offset: offset,
        limit: pageSize,
        seed: seed,
      );
      if (!mounted || generation != _loadGeneration) return;

      final newItems = _cleanFeed(data, excludedIds: _bundleProductIds());
      setState(() {
        recommendations.addAll(newItems);
        offset += data.length;
        hasMore = data.length >= pageSize;
        loadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        loadingMore = false;
        relatedError = e.toString();
        hasMore = false;
      });
    }
  }

  String _imageUrl(Product product) {
    final saved = product.imageUrl.trim();
    if (saved.startsWith('https://') || saved.startsWith('http://')) {
      return saved;
    }

    final text =
        '${product.name} ${product.categoryName} ${product.brand}'.toLowerCase();
    String keywords;

    if (text.contains('lót chuột') || text.contains('chuột')) {
      keywords = 'computer-mouse,wireless-mouse';
    } else if (text.contains('màn hình')) {
      keywords = 'computer-monitor';
    } else if (text.contains('iphone') || text.contains('điện thoại')) {
      keywords = 'smartphone,mobile-phone';
    } else if (text.contains('laptop') || text.contains('máy tính')) {
      keywords = 'laptop,notebook-computer';
    } else if (text.contains('ssd') || text.contains('ổ cứng')) {
      keywords = 'ssd-drive,external-hard-drive';
    } else if (text.contains('usb') || text.contains('hub')) {
      keywords = 'usb-c,computer-accessories';
    } else if (text.contains('tai nghe')) {
      keywords = 'headphones,audio';
    } else if (text.contains('bánh')) {
      keywords = 'cookies,biscuits';
    } else if (text.contains('ngũ cốc')) {
      keywords = 'breakfast-cereal,granola';
    } else if (text.contains('hạt')) {
      keywords = 'nuts,mixed-nuts';
    } else if (text.contains('cà phê')) {
      keywords = 'coffee,coffee-beans';
    } else {
      keywords = 'electronics,product';
    }

    final lock = product.id.codeUnits.fold<int>(
      17,
      (value, unit) => (value * 31 + unit) % 100000,
    );
    return 'https://loremflickr.com/900/700/$keywords?lock=$lock';
  }

  Widget _productImage(Product product, {double height = 310}) {
    final accent = categoryColor(product);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Image.network(
          _imageUrl(product),
          fit: BoxFit.contain,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (_, _, _) => Container(
            color: accent.withValues(alpha: 0.10),
            alignment: Alignment.center,
            child: Icon(
              iconForProduct(product),
              color: accent,
              size: 90,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.5,
              )),
        ],
      ),
    );
  }

  Widget _notice(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE9EAF2)),
      ),
      child: Text(
        text,
        style: const TextStyle(height: 1.6, color: Colors.black54),
      ),
    );
  }

  Widget _boughtTogetherSection() {
    if (loadingRelated) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (boughtTogether.isNotEmpty) {
      return _buildBundleGrid(
        boughtTogether.map(Product.fromJson).toList(),
        label: 'Thường được mua cùng',
      );
    }

    if (fallbackBoughtTogether.isNotEmpty) {
      final hasComplementRule =
          _complementaryCategoryIds(widget.product).isNotEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: Color(0xFFB7791F)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasComplementRule
                        ? 'Chưa có đủ đơn hàng để xác nhận mua chung. Đây là gợi ý bổ trợ dựa trên loại sản phẩm đang xem.'
                        : 'Chưa có dữ liệu mua chung. Các thẻ dưới đây là sản phẩm cùng danh mục để tham khảo, không phải lịch sử mua kèm đã xác nhận.',
                    style: const TextStyle(
                      color: Color(0xFF805A16),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildBundleGrid(
            fallbackBoughtTogether,
            label: hasComplementRule ? 'Gợi ý bổ trợ' : 'Cùng danh mục',
          ),
        ],
      );
    }

    return _notice(
      'Chưa có dữ liệu mua kèm hoặc sản phẩm bổ trợ phù hợp cho sản phẩm này.',
    );
  }

  Widget _buildBundleGrid(List<Product> products, {required String label}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 950 ? 4 : width >= 560 ? 2 : 1;
        const spacing = 12.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: products.take(4).map((product) {
            return SizedBox(
              width: cardWidth,
              height: 350,
              child: ProductCard(
                product: product,
                recommendationLabel: label,
                onTap: () => widget.onOpenProduct(product),
                onAddToCart: () {
                  if (widget.onAddProductToCart != null) {
                    widget.onAddProductToCart!(product);
                  } else {
                    widget.onOpenProduct(product);
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _recommendationGrid() {
    if (loadingRelated && recommendations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (recommendations.isEmpty) {
      return _notice(
        relatedError == null
            ? 'Chưa tìm được sản phẩm liên quan phù hợp. Hãy kiểm tra dữ liệu danh mục hoặc quan hệ sản phẩm trong Neo4j.'
            : 'Không tải được gợi ý: $relatedError',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1200 ? 4 : width >= 800 ? 3 : width >= 500 ? 2 : 1;
        const spacing = 14.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: recommendations.map((item) {
            final product = Product.fromJson(item);
            return SizedBox(
              width: cardWidth,
              height: 390,
              child: ProductCard(
                product: product,
                recommendationLabel: _labelFor(item),
                onTap: () => widget.onOpenProduct(product),
                onAddToCart: () {
                  if (widget.onAddProductToCart != null) {
                    widget.onAddProductToCart!(product);
                  } else {
                    widget.onOpenProduct(product);
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final available = product.stock > 0;
    final hasRealBoughtTogether = boughtTogether.isNotEmpty;
    final hasBundleFallback = fallbackBoughtTogether.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                widget.customerId,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6558E8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 850;
              final image = _productImage(
                product,
                height: wide ? 440 : 300,
              );

              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.categoryName.isEmpty
                        ? product.categoryId
                        : product.categoryName,
                    style: TextStyle(
                      color: categoryColor(product),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Mã sản phẩm: ${product.id}',
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 5),
                  Text('Thương hiệu: ${product.brand}',
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        available ? Icons.check_circle_outline : Icons.error_outline,
                        size: 18,
                        color: available ? const Color(0xFF18815A) : Colors.red,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        available ? 'Còn ${product.stock} sản phẩm' : 'Tạm hết hàng',
                        style: TextStyle(
                          color: available ? const Color(0xFF18815A) : Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    formatVnd(product.price),
                    style: TextStyle(
                      color: categoryColor(product),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Mô tả sản phẩm',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description.isEmpty
                        ? 'Thông tin chi tiết sản phẩm đang được cập nhật.'
                        : product.description,
                    style: const TextStyle(height: 1.7, color: Colors.black54),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: available ? widget.onAddToCart : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        backgroundColor: categoryColor(product),
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: Text(
                        available ? 'Thêm vào giỏ hàng' : 'Sản phẩm hết hàng',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Gợi ý thay đổi theo sản phẩm đang xem; sản phẩm phổ biến không liên quan sẽ không được đưa vào danh sách này.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              );

              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [image, const SizedBox(height: 24), details],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: image),
                  const SizedBox(width: 28),
                  Expanded(flex: 5, child: details),
                ],
              );
            },
          ),
          const SizedBox(height: 36),
          const Divider(),
          const SizedBox(height: 24),
          _sectionTitle(
            hasRealBoughtTogether ? 'Thường được mua cùng' : 'Gợi ý sản phẩm đi kèm',
            hasRealBoughtTogether
                ? 'Các sản phẩm thực sự xuất hiện chung trong đơn hàng theo dữ liệu Neo4j.'
                : hasBundleFallback
                    ? 'Chưa có đủ đơn hàng mua chung; các gợi ý bên dưới dựa trên loại sản phẩm và được ghi nhãn riêng.'
                    : 'Dựa trên dữ liệu đơn hàng nếu có; nếu chưa đủ dữ liệu, hệ thống sẽ không tự nhận các sản phẩm khác là đã mua cùng.',
          ),
          _boughtTogetherSection(),
          const SizedBox(height: 36),
          const Divider(),
          const SizedBox(height: 24),
          _sectionTitle(
            'Sản phẩm liên quan đến ${product.name}',
            'Ưu tiên quan hệ bổ trợ, sản phẩm cùng danh mục hoặc cùng thương hiệu với sản phẩm đang xem.',
          ),
          _recommendationGrid(),
          if (loadingMore)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!hasMore && recommendations.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Đã hiển thị các sản phẩm liên quan tìm được.',
                  style: TextStyle(color: Colors.black45),
                ),
              ),
            ),
          if (relatedError != null && recommendations.isNotEmpty)
            TextButton.icon(
              onPressed: _loadMore,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải thêm lần nữa'),
            ),
        ],
      ),
    );
  }
}
