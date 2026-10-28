import 'package:flutter/material.dart';

import '../models/product.dart';
import '../widgets/product_card.dart';

class SearchScreen extends StatefulWidget {
  final List<Product> products;
  final List<Map<String, dynamic>> categories;
  final ValueChanged<Product> onProductTap;
  final ValueChanged<Product> onAddToCart;

  const SearchScreen({
    super.key,
    required this.products,
    required this.categories,
    required this.onProductTap,
    required this.onAddToCart,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController();
  String keyword = '';
  String categoryId = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Product> get filteredProducts {
    return widget.products.where((product) {
      final text =
          '${product.name} ${product.brand} ${product.description}'
              .toLowerCase();

      final matchKeyword =
          keyword.isEmpty || text.contains(keyword.toLowerCase());

      final matchCategory =
          categoryId.isEmpty || product.categoryId == categoryId;

      return matchKeyword && matchCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final products = filteredProducts;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Tìm kiếm',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tìm theo tên, thương hiệu hoặc lọc theo danh mục.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: searchController,
          onChanged: (value) => setState(() => keyword = value),
          decoration: InputDecoration(
            hintText: 'Ví dụ: laptop, Dell, tai nghe...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: () {
                searchController.clear();
                setState(() => keyword = '');
              },
              icon: const Icon(Icons.close),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE9EAF2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE9EAF2)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: categoryId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Danh mục sản phẩm',
            prefixIcon: const Icon(Icons.filter_list),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('Tất cả danh mục'),
            ),
            ...widget.categories.map((category) {
              final id = '${category['id'] ?? ''}';

              return DropdownMenuItem(
                value: id,
                child: Text('${category['name'] ?? id}'),
              );
            }),
          ],
          onChanged: (value) {
            setState(() => categoryId = value ?? '');
          },
        ),
        const SizedBox(height: 22),
        Text(
          '${products.length} sản phẩm',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 14),
        if (products.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Không tìm thấy sản phẩm phù hợp. '
              'Hãy đổi từ khóa hoặc bộ lọc.',
            ),
          )
        else
          LayoutBuilder(
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
              final cardWidth =
                  (width - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: products.map((product) {
                  return SizedBox(
                    width: cardWidth,
                    height: 320,
                    child: ProductCard(
                      product: product,
                      onTap: () => widget.onProductTap(product),
                      onAddToCart: () => widget.onAddToCart(product),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}