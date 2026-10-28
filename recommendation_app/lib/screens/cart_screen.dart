import 'package:flutter/material.dart';

import '../models/product.dart';
import '../widgets/product_card.dart';

class CartScreen extends StatelessWidget {
  final List<Product> products;
  final Map<String, int> cart;
  final ValueChanged<String> onRemove;
  final void Function(String productId, int quantity) onQuantityChanged;
  final Future<void> Function() onCheckout;
  final bool checkingOut;

  const CartScreen({
    super.key,
    required this.products,
    required this.cart,
    required this.onRemove,
    required this.onQuantityChanged,
    required this.onCheckout,
    required this.checkingOut,
  });

  Product? findProduct(String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  double get total {
    double value = 0;

    for (final entry in cart.entries) {
      final product = findProduct(entry.key);
      if (product != null) {
        value += product.price * entry.value;
      }
    }

    return value;
  }

  @override
  Widget build(BuildContext context) {
    final entries = cart.entries.toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Giỏ hàng',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '${cart.values.fold<int>(0, (sum, n) => sum + n)} sản phẩm',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 22),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 54,
                  color: Color(0xFF6558E8),
                ),
                SizedBox(height: 16),
                Text(
                  'Giỏ hàng đang trống',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                SizedBox(height: 8),
                Text('Thêm sản phẩm từ trang chủ để tiếp tục.'),
              ],
            ),
          )
        else ...[
          ...entries.map((entry) {
            final product = findProduct(entry.key);
            if (product == null) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFE9EAF2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EDFF),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      iconForProduct(product),
                      size: 30,
                      color: const Color(0xFF6558E8),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatVnd(product.price),
                          style: const TextStyle(
                            color: Color(0xFF6558E8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => onQuantityChanged(
                                product.id,
                                entry.value - 1,
                              ),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                              ),
                            ),
                            Text('${entry.value}'),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => onQuantityChanged(
                                product.id,
                                entry.value + 1,
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xóa sản phẩm',
                    onPressed: () => onRemove(product.id),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE9EAF2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tổng tiền tạm tính',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Text(
                  formatVnd(total),
                  style: const TextStyle(
                    color: Color(0xFF6558E8),
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: checkingOut ? null : onCheckout,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: const Color(0xFF6558E8),
                  ),
                  icon: checkingOut
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    checkingOut ? 'Đang tạo đơn...' : 'Xác nhận mua hàng demo',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Đây là giao dịch mô phỏng cho đồ án. '
                  'Không có thanh toán tiền thật.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}