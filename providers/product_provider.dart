import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/product_model.dart';
import '../services/api_service_products.dart';

/// Error yang pesannya sudah ramah dibaca pengguna.
class AppException implements Exception {
  final String message;
  AppException(this.message);
  @override
  String toString() => message;
}

/// State produk. Sumber data satu-satunya adalah database MySQL lewat API:
/// setiap Create / Update / Delete langsung dikirim ke server, lalu daftar
/// dimuat ulang dari server sehingga tampilan SELALU sama dengan isi database.
class ProductProvider extends ChangeNotifier {
  static const int pageSize = 30;
  final ApiServiceProducts _api = ApiServiceProducts();

  List<Product> _products = [];
  List<String> _categoryList = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _total = 0; // total baris di database (sesuai filter/pencarian)
  int _serverLoaded = 0; // jumlah data yang sudah diambil (untuk parameter skip)

  String _query = '';
  String _category = '';
  String? _sortBy;
  String _order = 'asc';
  int _requestId = 0; // mencegah hasil request lama menimpa yang baru

  List<Product> get products => _products;
  List<String> get categoryList => _categoryList;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  int get total => _total;
  String get query => _query;
  String get selectedCategory => _category;
  String? get sortBy => _sortBy;
  String get order => _order;
  bool get hasMore => _serverLoaded < _total;

  /// Total produk yang ditampilkan di UI (langsung dari database).
  int get displayTotal => _total;

  // ---------------------------------------------------------------- READ
  Future<void> init() async {
    await Future.wait([fetchCategories(), fetchProducts()]);
  }

  Future<void> fetchCategories() async {
    try {
      _categoryList = await _api.getCategoryList(); // GET /products/category-list
      notifyListeners();
    } catch (_) {}
  }

  /// GET /products (dengan spinner layar penuh).
  Future<void> fetchProducts() => _load(showSpinner: true);

  /// Muat ulang tanpa spinner (dipakai setelah tambah/edit/hapus).
  Future<void> refresh() => _load(showSpinner: false);

  Future<void> _load({required bool showSpinner}) async {
    final id = ++_requestId;
    if (showSpinner) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final res = await _api.getProducts(
        query: _query,
        category: _category,
        sortBy: _sortBy,
        order: _order,
        limit: pageSize,
        skip: 0,
      );
      if (id != _requestId) return;
      _error = null;
      _serverLoaded = res.products.length;
      _products = res.products;
      _total = res.total;
    } catch (e) {
      if (id != _requestId) return;
      _error = _msg(e);
      _products = [];
      _total = 0;
      _serverLoaded = 0;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !hasMore) return;
    final id = _requestId;
    _loadingMore = true;
    notifyListeners();
    try {
      final res = await _api.getProducts(
        query: _query,
        category: _category,
        sortBy: _sortBy,
        order: _order,
        limit: pageSize,
        skip: _serverLoaded,
      );
      if (id == _requestId) {
        _serverLoaded += res.products.length;
        _products = [..._products, ...res.products];
        _total = res.total;
      }
    } catch (_) {}
    _loadingMore = false;
    notifyListeners();
  }

  Future<void> search(String q) {
    _query = q;
    return fetchProducts();
  }

  Future<void> setQueryAndCategory(String q, String category) {
    _query = q;
    _category = category;
    return fetchProducts();
  }

  Future<void> filterByCategory(String category) {
    _category = category;
    return fetchProducts();
  }

  Future<void> setSort(String? sortBy, String order) {
    _sortBy = sortBy;
    _order = order;
    return fetchProducts();
  }

  // -------------------------------------------------------------- CREATE
  /// POST /products -> INSERT ke MySQL, lalu daftar dimuat ulang dari server.
  Future<Product> addProduct(Product draft) async {
    try {
      final saved = await _api.addProduct(draft.toJson());
      await Future.wait([refresh(), fetchCategories()]);
      return saved;
    } catch (e) {
      throw AppException(_msg(e));
    }
  }

  // -------------------------------------------------------------- UPDATE
  /// PUT /products/{id} -> UPDATE di MySQL, lalu daftar dimuat ulang.
  Future<Product> updateProduct(int id, Product updated) async {
    try {
      final saved = await _api.updateProduct(id, updated.toJson());
      await Future.wait([refresh(), fetchCategories()]);
      return saved;
    } catch (e) {
      throw AppException(_msg(e));
    }
  }

  // -------------------------------------------------------------- DELETE
  /// DELETE /products/{id} -> hapus baris di MySQL, lalu daftar dimuat ulang.
  Future<void> deleteProduct(int id) async {
    try {
      await _api.deleteProduct(id);
      await Future.wait([refresh(), fetchCategories()]);
    } catch (e) {
      throw AppException(_msg(e));
    }
  }

  // ------------------------------------------------------------- helpers
  String _msg(Object e) {
    if (e is AppException) return e.message;
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Tidak bisa terhubung ke server\n${ApiConfig.baseUrl}\n\n'
              'Pastikan Docker berjalan, IP di api_config.dart benar,\n'
              'dan HP satu WiFi dengan laptop.';
        default:
          break;
      }
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return 'Terjadi kesalahan server (${e.response?.statusCode ?? '-'}).';
    }
    return 'Terjadi kesalahan: $e';
  }
}
