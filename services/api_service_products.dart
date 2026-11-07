import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/product_model.dart';

/// Semua endpoint backend Pastel Shop (Express + MySQL di Docker).
/// Alamat server diatur di lib/config/api_config.dart.
class ApiServiceProducts {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  /// GET /products, /products/search?q=, /products/category/{slug}
  /// dengan limit, skip, sortBy, order.
  Future<ProductsResponse> getProducts({
    String query = '',
    String category = '',
    String? sortBy,
    String order = 'asc',
    int limit = 30,
    int skip = 0,
  }) async {
    String path = '/products';
    final params = <String, dynamic>{'limit': limit, 'skip': skip};
    if (query.trim().isNotEmpty) {
      path = '/products/search';
      params['q'] = query.trim();
    } else if (category.isNotEmpty) {
      path = '/products/category/$category';
    }
    if (sortBy != null) {
      params['sortBy'] = sortBy;
      params['order'] = order;
    }
    final res = await _dio.get(path, queryParameters: params);
    return ProductsResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /products?limit=10&skip=10&select=title,price
  Future<ProductsResponse> getProductsPaginated({int limit = 10, int skip = 0, String? select}) async {
    final params = <String, dynamic>{'limit': limit, 'skip': skip};
    if (select != null) params['select'] = select;
    final res = await _dio.get('/products', queryParameters: params);
    return ProductsResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /products/{id}
  Future<Product> getProduct(int id) async {
    final res = await _dio.get('/products/$id');
    return Product.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /products/search?q=
  Future<ProductsResponse> searchProducts(String query) async {
    final res = await _dio.get('/products/search', queryParameters: {'q': query});
    return ProductsResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /products?sortBy=&order=
  Future<ProductsResponse> sortProducts(String sortBy, String order) async {
    final res = await _dio.get('/products', queryParameters: {'sortBy': sortBy, 'order': order});
    return ProductsResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /products/categories
  Future<List<Category>> getCategories() async {
    final res = await _dio.get('/products/categories');
    return (res.data as List).map((e) => Category.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  /// GET /products/category-list
  Future<List<String>> getCategoryList() async {
    final res = await _dio.get('/products/category-list');
    return (res.data as List).map((e) => e.toString()).toList();
  }

  /// GET /products/category/{slug}
  Future<ProductsResponse> getProductsByCategory(String category) async {
    final res = await _dio.get('/products/category/$category');
    return ProductsResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /products  (CREATE -> INSERT ke MySQL, mengembalikan data + id baru)
  Future<Product> addProduct(Map<String, dynamic> data) async {
    final res = await _dio.post('/products', data: data);
    return Product.fromJson(res.data as Map<String, dynamic>);
  }

  /// PUT /products/{id}  (UPDATE baris di MySQL)
  Future<Product> updateProduct(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/products/$id', data: data);
    return Product.fromJson(res.data as Map<String, dynamic>);
  }

  /// PATCH /products/{id}  (update sebagian)
  Future<Product> patchProduct(int id, Map<String, dynamic> partialData) async {
    final res = await _dio.patch('/products/$id', data: partialData);
    return Product.fromJson(res.data as Map<String, dynamic>);
  }

  /// DELETE /products/{id}  (hapus baris di MySQL, respons isDeleted = true)
  Future<Product> deleteProduct(int id) async {
    final res = await _dio.delete('/products/$id');
    return Product.fromJson(res.data as Map<String, dynamic>);
  }
}
