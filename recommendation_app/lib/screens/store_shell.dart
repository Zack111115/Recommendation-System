import 'package:flutter/material.dart';

import '../models/demo_account.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/auth_controller.dart';

import 'account_screen.dart';
import 'cart_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'product_detail_screen.dart';
import 'recommendations_screen.dart';
import 'search_screen.dart';

class StoreShell extends StatefulWidget {
  final AuthController auth;
  final DemoAccount account;

  const StoreShell({
    super.key,
    required this.auth,
    required this.account,
  });

  @override
  State<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends State<StoreShell> {
  int selectedTab = 0;
  bool loading = true;
  bool checkingOut = false;
  String? loadError;

  List<Product> products = [];
  List<Map<String, dynamic>> categories = [];
  final Map<String, int> cart = {};
  final Set<String> cartBusy = <String>{};

  int refreshToken = 0;

  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    loadStore();
  }

  Future<void> loadStore() async {
    // Chỉ dùng màn hình tải khi mở cửa hàng lần đầu.
    // Khi làm mới dữ liệu, giữ nguyên IndexedStack/tab đang mở.
    final firstLoad = products.isEmpty;
    if (mounted) {
      setState(() {
        if (firstLoad) loading = true;
        loadError = null;
      });
    }

    try {
      final productData = await ApiService.getProducts();

      List<Map<String, dynamic>> categoryData = [];
      try {
        categoryData = await ApiService.getCategories();
      } catch (_) {
        // Danh mục lỗi không làm toàn bộ cửa hàng thoát ra.
      }

      List<Map<String, dynamic>>? savedCart;
      try {
        savedCart = await ApiService.getCart(widget.account.id);
      } catch (e) {
        // Không để lỗi API giỏ hàng làm văng khỏi trang cửa hàng.
        if (mounted) {
          showMessage('Chưa tải được giỏ hàng đã lưu. Kiểm tra backend: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        products = productData;
        categories = categoryData;

        // Chỉ thay giỏ cục bộ khi đọc thành công từ backend.
        if (savedCart != null) {
          cart
            ..clear()
            ..addEntries(
              savedCart
                  .map((item) => MapEntry(
                        '${item['productId'] ?? ''}',
                        int.tryParse('${item['quantity'] ?? 1}') ?? 1,
                      ))
                  .where((entry) => entry.key.isNotEmpty && entry.value > 0),
            );
        }

        loading = false;
        loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final hadProducts = products.isNotEmpty;
      setState(() {
        loading = false;
        // Chỉ hiển thị màn hình lỗi nếu chưa có dữ liệu nào để dùng.
        loadError = hadProducts ? null : e.toString();
      });
      if (hadProducts) {
        showMessage('Không làm mới được dữ liệu. Dữ liệu đang hiển thị được giữ lại.');
      }
    }
  }

  void showMessage(String text) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Product? findProduct(String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }

    return null;
  }

  Future<void> addToCart(Product product) async {
    if (product.stock <= 0) {
      showMessage('Sản phẩm hiện đã hết hàng.');
      return;
    }
    if (cartBusy.contains(product.id)) return;

    final currentQuantity = cart[product.id] ?? 0;
    final newQuantity = currentQuantity + 1;
    if (newQuantity > product.stock) {
      showMessage('Số lượng đã đạt tồn kho hiện có.');
      return;
    }

    cartBusy.add(product.id);
    try {
      await ApiService.setCartItem(
        customerId: widget.account.id,
        productId: product.id,
        quantity: newQuantity,
      );
      if (!mounted) return;
      setState(() => cart[product.id] = newQuantity);
      showMessage('Đã lưu ${product.name} vào giỏ hàng.');
    } catch (e) {
      showMessage('Không lưu được giỏ hàng: $e');
    } finally {
      cartBusy.remove(product.id);
    }
  }

  Future<void> changeQuantity(String productId, int quantity) async {
    if (quantity <= 0) {
      await removeFromCart(productId);
      return;
    }
    if (cartBusy.contains(productId)) return;

    final product = findProduct(productId);
    if (product == null) {
      showMessage('Không tìm thấy sản phẩm trong cửa hàng.');
      return;
    }
    if (quantity > product.stock) {
      showMessage('Không vượt quá tồn kho (${product.stock}).');
      return;
    }

    cartBusy.add(productId);
    try {
      await ApiService.setCartItem(
        customerId: widget.account.id,
        productId: productId,
        quantity: quantity,
      );
      if (!mounted) return;
      setState(() => cart[productId] = quantity);
    } catch (e) {
      showMessage('Không cập nhật được số lượng: $e');
    } finally {
      cartBusy.remove(productId);
    }
  }

  Future<void> removeFromCart(String productId) async {
    if (cartBusy.contains(productId)) return;
    cartBusy.add(productId);
    try {
      await ApiService.removeCartItem(
        customerId: widget.account.id,
        productId: productId,
      );
      if (!mounted) return;
      setState(() => cart.remove(productId));
    } catch (e) {
      showMessage('Không xóa được sản phẩm khỏi giỏ: $e');
    } finally {
      cartBusy.remove(productId);
    }
  }

  void openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          customerId: widget.account.id,
          onAddToCart: () => addToCart(product),
          onOpenProduct: openProduct,
        ),
      ),
    );
  }

  Future<void> checkout() async {
    if (cart.isEmpty) {
      showMessage('Giỏ hàng đang trống.');
      return;
    }
    if (checkingOut) return;

    setState(() => checkingOut = true);
    try {
      // Backend tạo đơn và xử lý mọi mặt hàng trong một transaction Neo4j.
      // Nếu có lỗi tồn kho, toàn bộ giao dịch bị hủy và giỏ được giữ lại.
      final result = await ApiService.checkout(widget.account.id);
      if (!mounted) return;

      final orderId = '${result['orderId'] ?? ''}';
      final total = double.tryParse('${result['total'] ?? 0}') ?? 0;

      setState(() {
        cart.clear();
        refreshToken++;
        checkingOut = false;
      });

      showMessage(
        'Thanh toán demo thành công · Đơn $orderId · Tổng ${total.toStringAsFixed(0)} đ',
      );
      await loadStore();
    } catch (e) {
      if (!mounted) return;
      setState(() => checkingOut = false);
      showMessage('Chưa thể hoàn tất đơn hàng: $e. Giỏ hàng được giữ lại.');
    }
  }

  void logout() {
    // Dữ liệu giỏ hàng, lượt xem và hoạt động đã được lưu trên backend.
    // Không xóa dữ liệu trong Neo4j khi đăng xuất.
    setState(() => selectedTab = 0);
    widget.auth.signOut();
  }

  List<Widget> get pages => [
        HomeScreen(
          key: ValueKey('home-${widget.account.id}'),
          customerId: widget.account.id,
          products: products,
          categories: categories,
          onProductTap: openProduct,
          onAddToCart: addToCart,
          onSeeRecommendations: () {
            setState(() => selectedTab = 2);
          },
          refreshToken: refreshToken,
        ),
        SearchScreen(
          key: ValueKey('search-${widget.account.id}'),
          products: products,
          categories: categories,
          onProductTap: openProduct,
          onAddToCart: addToCart,
        ),
        RecommendationsScreen(
          key: ValueKey('recommendations-${widget.account.id}'),
          customerId: widget.account.id,
          products: products,
          onProductTap: openProduct,
          onAddToCart: addToCart,
          refreshToken: refreshToken,
        ),
        CartScreen(
          key: ValueKey('cart-${widget.account.id}'),
          products: products,
          cart: Map<String, int>.from(cart),
          onRemove: removeFromCart,
          onQuantityChanged: changeQuantity,
          onCheckout: checkout,
          checkingOut: checkingOut,
        ),
        AccountScreen(
          key: ValueKey('account-${widget.account.id}'),
          account: widget.account,
          onLogout: logout,
          onRefresh: () {
            setState(() => refreshToken++);
            loadStore();
          },
        ),
        HistoryScreen(
          key: ValueKey('history-${widget.account.id}'),
          customerId: widget.account.id,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final cartCount =
        cart.values.fold<int>(0, (sum, quantity) => sum + quantity);

    return ScaffoldMessenger(
      key: scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          toolbarHeight: 72,
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF6558E8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'RecommendationSystem',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Khám phá · Cá nhân hóa · Neo4j',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (MediaQuery.sizeOf(context).width > 560)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EDFF),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      widget.account.id,
                      style: const TextStyle(
                        color: Color(0xFF6558E8),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Giỏ hàng',
              onPressed: () => setState(() => selectedTab = 3),
              icon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: loading && products.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : loadError != null && products.isEmpty
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off_outlined,
                              size: 50,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Không tải được dữ liệu cửa hàng',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            SelectableText(loadError!),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: loadStore,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final desktop = constraints.maxWidth >= 900;

                      final content = IndexedStack(
                        index: selectedTab,
                        children: pages,
                      );

                      if (!desktop) return content;

                      return Row(
                        children: [
                          NavigationRail(
                            backgroundColor: Colors.white,
                            selectedIndex: selectedTab,
                            onDestinationSelected: (index) {
                              setState(() => selectedTab = index);
                            },
                            labelType: NavigationRailLabelType.all,
                            destinations: const [
                              NavigationRailDestination(
                                icon: Icon(Icons.home_outlined),
                                selectedIcon: Icon(Icons.home_rounded),
                                label: Text('Trang chủ'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.search_rounded),
                                label: Text('Tìm kiếm'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.auto_awesome_outlined),
                                selectedIcon: Icon(Icons.auto_awesome),
                                label: Text('Gợi ý'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.shopping_cart_outlined),
                                label: Text('Giỏ hàng'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.person_outline),
                                selectedIcon: Icon(Icons.person),
                                label: Text('Tài khoản'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.history_outlined),
                                selectedIcon: Icon(Icons.history),
                                label: Text('Lịch sử'),
                              ),
                            ],
                          ),
                          const VerticalDivider(
                            width: 1,
                            color: Color(0xFFE9EAF2),
                          ),
                          Expanded(child: content),
                        ],
                      );
                    },
                  ),
        bottomNavigationBar:
            MediaQuery.sizeOf(context).width < 900 && !loading
                ? NavigationBar(
                    selectedIndex: selectedTab,
                    onDestinationSelected: (index) {
                      setState(() => selectedTab = index);
                    },
                    destinations: [
                      const NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Trang chủ',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.search_rounded),
                        label: 'Tìm kiếm',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.auto_awesome_outlined),
                        selectedIcon: Icon(Icons.auto_awesome),
                        label: 'Gợi ý',
                      ),
                      NavigationDestination(
                        icon: Badge(
                          isLabelVisible: cartCount > 0,
                          label: Text('$cartCount'),
                          child: const Icon(Icons.shopping_cart_outlined),
                        ),
                        label: 'Giỏ hàng',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: 'Tài khoản',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.history_outlined),
                        selectedIcon: Icon(Icons.history),
                        label: 'Lịch sử',
                      ),
                    ],
                  )
                : null,
      ),
    );
  }
}