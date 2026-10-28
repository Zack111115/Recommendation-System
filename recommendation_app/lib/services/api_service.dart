
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/product.dart';
import '../models/recommendation.dart';

class ApiService {
  // Backend ASP.NET Core.
  static const String baseUrl = 'http://localhost:5056';

  static Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    final request = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json';

    if (method == 'POST' || method == 'PUT' || method == 'PATCH') {
      request.body = jsonEncode(body ?? <String, dynamic>{});
    }

    final streamedResponse = await request
        .send()
        .timeout(const Duration(seconds: 20));

    final response = await http.Response.fromStream(streamedResponse)
        .timeout(const Duration(seconds: 20));

    dynamic data;

    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      data = response.body;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map
          ? data['detail'] ??
              data['message'] ??
              data['title'] ??
              data.toString()
          : data?.toString() ?? 'Không có nội dung phản hồi.';

      throw Exception('HTTP ${response.statusCode}: $message');
    }

    return data;
  }

  static List<dynamic> _asList(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      for (final key in ['items', 'data', 'results']) {
        if (data[key] is List) return data[key] as List;
      }
    }

    return [];
  }

  static Future<void> checkHealth() async {
    await _request('/api/health');
  }

  static Future<List<Product>> getProducts() async {
    final data = await _request('/api/products?limit=100');

    return _asList(data)
        .whereType<Map>()
        .map((item) => Product.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final data = await _request('/api/categories');

    return _asList(data)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // Goi y Collaborative Filtering cu.
  static Future<List<Recommendation>> getRecommendations(
    String customerId,
  ) async {
    final data = await _request(
      '/api/customers/${Uri.encodeComponent(customerId)}/recommendations',
    );

    return _asList(data)
        .whereType<Map>()
        .map((item) => Recommendation.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();
  }

  // FEED GOI Y DA NGUON.
  // Tra ve Map de giu sourceType, sourceLabel, reason, score, evidence.
  static Future<List<Map<String, dynamic>>> getRecommendationFeed({
    required String customerId,
    String? contextProductId,
    int offset = 0,
    int limit = 12,
    int seed = 0,
  }) async {
    final queryParameters = <String, String>{
      'offset': '$offset',
      'limit': '${limit.clamp(1, 24)}',
      'seed': '$seed',
    };

    if (contextProductId != null &&
        contextProductId.trim().isNotEmpty) {
      queryParameters['contextProductId'] = contextProductId.trim();
    }

    final query = Uri(queryParameters: queryParameters).query;

    final data = await _request(
      '/api/customers/${Uri.encodeComponent(customerId)}/feed?$query',
    );

    return _asList(data)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getBoughtTogether(
    String productId,
  ) async {
    final data = await _request(
      '/api/products/${Uri.encodeComponent(productId)}'
      '/frequently-bought-together',
    );

    return _asList(data)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<dynamic> explainRecommendation(
    String customerId,
    String productId,
  ) {
    return _request(
      '/api/customers/${Uri.encodeComponent(customerId)}'
      '/recommendations/${Uri.encodeComponent(productId)}/explain',
    );
  }

  static Future<void> recordView({
    required String customerId,
    required String productId,
    required String sessionId,
  }) async {
    await _request(
      '/api/customers/${Uri.encodeComponent(customerId)}'
      '/views/${Uri.encodeComponent(productId)}',
      method: 'POST',
      body: {'sessionId': sessionId},
    );
  }

  static Future<void> recordPurchase({
    required String customerId,
    required String productId,
    required String orderId,
    required int quantity,
  }) async {
    await _request(
      '/api/customers/${Uri.encodeComponent(customerId)}'
      '/purchases/${Uri.encodeComponent(productId)}',
      method: 'POST',
      body: {
        'orderId': orderId,
        'quantity': quantity,
      },
    );
  }

  // Lay gio hang da luu tren Neo4j cua dung tai khoan.
  static Future<List<Map<String, dynamic>>> getCart(
    String customerId,
  ) async {
    final data = await _request(
      '/api/customers/${Uri.encodeComponent(customerId)}/cart',
    );

    return _asList(data)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // Luu/cap nhat so luong gio hang.
  static Future<void> setCartItem({
    required String customerId,
    required String productId,
    required int quantity,
  }) async {
    await _request(
      '/api/customers/${Uri.encodeComponent(customerId)}'
      '/cart/${Uri.encodeComponent(productId)}',
      method: 'PUT',
      body: {'quantity': quantity},
    );
  }

  static Future<void> removeCartItem({
    required String customerId,
    required String productId,
  }) async {
    await _request(
      '/api/customers/${Uri.encodeComponent(customerId)}'
      '/cart/${Uri.encodeComponent(productId)}',
      method: 'DELETE',
    );
  }

  static Future<List<Map<String, dynamic>>> getCustomerHistory(
    String customerId, {
    int limit = 100,
  }) async {
    final data = await _request(
      '/api/customers/${Uri.encodeComponent(customerId)}'
      '/history?limit=$limit',
    );

    return _asList(data)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<Map<String, dynamic>> checkout(
    String customerId,
  ) async {
    final data = await _request(
      '/api/customers/${Uri.encodeComponent(customerId)}/checkout',
      method: 'POST',
      body: <String, dynamic>{},
    );

    if (data is! Map) {
      throw Exception('API thanh toán trả về dữ liệu không hợp lệ.');
    }

    return Map<String, dynamic>.from(data);
  }
}
