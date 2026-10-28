import 'package:flutter/material.dart';

import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  final String customerId;

  const HistoryScreen({super.key, required this.customerId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = ApiService.getCustomerHistory(widget.customerId);
  }

  Future<void> _reload() async {
    final future = ApiService.getCustomerHistory(widget.customerId);
    setState(() => _historyFuture = future);
    try {
      await future;
    } catch (_) {
      // FutureBuilder sẽ hiển thị lỗi và nút thử lại.
    }
  }

  String _label(String type) {
    switch (type) {
      case 'VIEWED':
        return 'Đã xem sản phẩm';
      case 'ADDED_TO_CART':
        return 'Đã thêm/cập nhật giỏ';
      case 'REMOVED_FROM_CART':
        return 'Đã xóa khỏi giỏ';
      case 'PURCHASED':
        return 'Đã mua hàng';
      default:
        return type.isEmpty ? 'Hoạt động' : type;
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'VIEWED':
        return Icons.visibility_outlined;
      case 'ADDED_TO_CART':
        return Icons.add_shopping_cart_outlined;
      case 'REMOVED_FROM_CART':
        return Icons.remove_shopping_cart_outlined;
      case 'PURCHASED':
        return Icons.receipt_long_outlined;
      default:
        return Icons.history;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'PURCHASED':
        return const Color(0xFF16845B);
      case 'ADDED_TO_CART':
        return const Color(0xFF6558E8);
      case 'REMOVED_FROM_CART':
        return const Color(0xFFB45309);
      default:
        return Colors.blueGrey;
    }
  }

  String _date(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value.isEmpty ? 'Không có thời gian' : value;
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch sử hoạt động',
                      style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Lưu lại lượt xem, thao tác giỏ hàng và các đơn đã mua.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Làm mới lịch sử',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return _stateCard(
                  icon: Icons.cloud_off_outlined,
                  title: 'Không tải được lịch sử',
                  message: '${snapshot.error}',
                  action: TextButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                );
              }

              final events = snapshot.data ?? const <Map<String, dynamic>>[];
              if (events.isEmpty) {
                return _stateCard(
                  icon: Icons.history,
                  title: 'Chưa có hoạt động nào',
                  message:
                      'Khi bạn xem, thêm/xóa sản phẩm khỏi giỏ hoặc mua hàng, '
                      'hoạt động sẽ được lưu tại đây theo tài khoản ${widget.customerId}.',
                );
              }

              return Column(
                children: events.map((event) {
                  final type = '${event['type'] ?? ''}';
                  final name = '${event['productName'] ?? 'Sản phẩm'}';
                  final productId = '${event['productId'] ?? ''}';
                  final orderId = '${event['orderId'] ?? ''}';
                  final quantity = int.tryParse('${event['quantity'] ?? 1}') ?? 1;
                  final color = _color(type);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE9EAF2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(_icon(type), color: color),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _label(type),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 5),
                              Text(name, style: const TextStyle(height: 1.4)),
                              const SizedBox(height: 5),
                              Text(
                                'Mã sản phẩm: $productId · Số lượng: $quantity',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              if (orderId.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                SelectableText(
                                  'Mã đơn: $orderId',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                _date('${event['eventAt'] ?? ''}'),
                                style: const TextStyle(
                                  color: Colors.black45,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _stateCard({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EAF2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: const Color(0xFF6558E8)),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 8), action],
        ],
      ),
    );
  }
}
