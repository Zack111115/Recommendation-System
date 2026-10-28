import 'package:flutter/material.dart';

import '../models/product.dart';

const productPurple = Color(0xFF6558E8);

Color categoryColor(Product product) {
  final text =
      '${product.categoryId} ${product.categoryName} '
      '${product.name} ${product.brand}'.toLowerCase();

  if (text.contains('điện thoại') ||
      text.contains('iphone') ||
      text.contains('smartphone') ||
      text.contains('tablet')) {
    return const Color(0xFF2878D0); // Xanh dương
  }

  if (text.contains('laptop') ||
      text.contains('máy tính') ||
      text.contains('màn hình') ||
      text.contains('ssd') ||
      text.contains('usb')) {
    return const Color(0xFF16877A); // Xanh ngọc
  }

  if (text.contains('phụ kiện') ||
      text.contains('chuột') ||
      text.contains('mouse') ||
      text.contains('bàn phím') ||
      text.contains('tai nghe') ||
      text.contains('loa')) {
    return const Color(0xFFE58A24); // Cam
  }

  if (text.contains('gia dụng') ||
      text.contains('nồi') ||
      text.contains('ấm')) {
    return const Color(0xFF39965B); // Xanh lá
  }

  if (text.contains('đồ ăn nhẹ') ||
      text.contains('bánh') ||
      text.contains('ngũ cốc') ||
      text.contains('hạt') ||
      text.contains('thực phẩm')) {
    return const Color(0xFFD65B64); // Đỏ san hô
  }

  if (text.contains('đồ uống') ||
      text.contains('cà phê') ||
      text.contains('trà xanh')) {
    return const Color(0xFF9A6A35); // Nâu
  }

  if (text.contains('thể thao') ||
      text.contains('yoga')) {
    return const Color(0xFF287FA8); // Xanh biển
  }

  if (text.contains('chăm sóc') ||
      text.contains('skincare') ||
      text.contains('làm đẹp')) {
    return const Color(0xFFBA659A); // Hồng
  }

  if (text.contains('văn phòng phẩm') ||
      text.contains('bút') ||
      text.contains('sổ')) {
    return const Color(0xFF7B61A8); // Tím trầm
  }

  return const Color(0xFF64748B); // Xám xanh
}

String formatVnd(num value) {
  final digits = value.toStringAsFixed(0);
  final buffer = StringBuffer();

  for (int i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);

    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write('.');
    }
  }

  return '${buffer.toString()} đ';
}

IconData iconForProduct(Product product) {
  final text =
      '${product.name} ${product.categoryName} ${product.brand}'
          .toLowerCase();

  if (text.contains('lót chuột') ||
      text.contains('mouse pad') ||
      text.contains('chuột')) {
    return Icons.mouse_rounded;
  }

  if (text.contains('màn hình')) {
    return Icons.desktop_windows_rounded;
  }

  if (text.contains('laptop') ||
      text.contains('máy tính') ||
      text.contains('ssd') ||
      text.contains('hub usb')) {
    return Icons.laptop_mac_rounded;
  }

  if (text.contains('điện thoại') ||
      text.contains('tablet') ||
      text.contains('iphone')) {
    return Icons.phone_iphone_rounded;
  }

  if (text.contains('tai nghe') ||
      text.contains('loa') ||
      text.contains('âm thanh')) {
    return Icons.headphones_rounded;
  }

  if (text.contains('bàn phím')) {
    return Icons.keyboard_rounded;
  }

  if (text.contains('bánh') ||
      text.contains('ngũ cốc') ||
      text.contains('hạt') ||
      text.contains('cà phê')) {
    return Icons.fastfood_rounded;
  }

  if (text.contains('nồi') || text.contains('ấm')) {
    return Icons.kitchen_rounded;
  }

  return Icons.inventory_2_outlined;
}

// Neu Neo4j chua co imageUrl, dung anh tham khao tu Internet.
// Khi co URL anh that trong Neo4j, URL do luon duoc uu tien.
String productDisplayImageUrl(Product product) {
  final savedUrl = product.imageUrl.trim();

  if (savedUrl.startsWith('https://') ||
      savedUrl.startsWith('http://')) {
    return savedUrl;
  }

  final text =
      '${product.name} ${product.categoryName} ${product.brand}'
          .toLowerCase();

  String keywords;

  if (text.contains('lót chuột') ||
      text.contains('mouse pad')) {
    keywords = 'computer-mouse,mouse-pad';
  } else if (text.contains('chuột')) {
    keywords = 'computer-mouse,wireless-mouse';
  } else if (text.contains('màn hình')) {
    keywords = 'computer-monitor,desktop-monitor';
  } else if (text.contains('iphone')) {
    keywords = 'iphone,smartphone';
  } else if (text.contains('điện thoại') ||
      text.contains('samsung galaxy') ||
      text.contains('redmi')) {
    keywords = 'smartphone,mobile-phone';
  } else if (text.contains('laptop')) {
    keywords = 'laptop,notebook-computer';
  } else if (text.contains('máy tính') ||
      text.contains('desktop')) {
    keywords = 'desktop-computer,computer';
  } else if (text.contains('ssd') ||
      text.contains('ổ cứng')) {
    keywords = 'ssd-drive,external-hard-drive';
  } else if (text.contains('usb') ||
      text.contains('hub')) {
    keywords = 'usb-c,computer-accessories';
  } else if (text.contains('tai nghe') ||
      text.contains('headphone')) {
    keywords = 'headphones,audio';
  } else if (text.contains('loa')) {
    keywords = 'speaker,audio';
  } else if (text.contains('bàn phím')) {
    keywords = 'computer-keyboard';
  } else if (text.contains('bánh')) {
    keywords = 'cookies,biscuits';
  } else if (text.contains('ngũ cốc')) {
    keywords = 'breakfast-cereal,granola';
  } else if (text.contains('hạt')) {
    keywords = 'nuts,mixed-nuts';
  } else if (text.contains('cà phê')) {
    keywords = 'coffee,coffee-beans';
  } else if (text.contains('thể thao')) {
    keywords = 'sports-equipment';
  } else if (text.contains('chăm sóc')) {
    keywords = 'skincare,personal-care';
  } else {
    keywords = 'electronics,product';
  }

  // Tao lock on dinh cho tung san pham de anh khong thay doi lien tuc.
  final lock = product.id.codeUnits.fold<int>(
        17,
        (value, unit) => (value * 31 + unit) % 100000,
      ) +
      1;

  return 'https://loremflickr.com/640/480/$keywords?lock=$lock';
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  final bool compact;
  final String? recommendationLabel;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAddToCart,
    this.compact = false,
    this.recommendationLabel,
  });

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF0EDFF),
      alignment: Alignment.center,
      child: Icon(
        iconForProduct(product),
        size: compact ? 38 : 54,
        color: productPurple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = productDisplayImageUrl(product);
    final accentColor = categoryColor(product);
    Color.alphaBlend(
      accentColor.withValues(alpha: 0.10),
      Colors.white,
);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE9EAF2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      webHtmlElementStrategy:
                          WebHtmlElementStrategy.prefer,
                      errorBuilder: (context, error, stackTrace) {
                        return _placeholder();
                      },
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;

                        return Container(
                          color: const Color(0xFFF0EDFF),
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: productPurple,
                            ),
                          ),
                        );
                      },
                    ),
                    if (recommendationLabel != null &&
                        recommendationLabel!.trim().isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: productPurple.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              recommendationLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.categoryName.isNotEmpty
                          ? product.categoryName
                          : product.categoryId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      product.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      formatVnd(product.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: productPurple,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            product.stock > 0 ? onAddToCart : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF0EDFF),
                          foregroundColor: productPurple,
                          disabledBackgroundColor:
                              const Color(0xFFE4E4E7),
                          disabledForegroundColor:
                              Colors.black38,
                          padding: const EdgeInsets.symmetric(
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: Text(
                          product.stock > 0
                              ? 'Thêm vào giỏ'
                              : 'Hết hàng',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}