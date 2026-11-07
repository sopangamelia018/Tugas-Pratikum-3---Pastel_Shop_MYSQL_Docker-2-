// Model mapping dari response API backend Pastel Shop (bentuk JSON mengikuti format DummyJSON)

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}') ?? 0;
}

int _i(dynamic v, [int def = 0]) {
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}') ?? def;
}

/// Status ketersediaan berdasarkan stok
String statusFromStock(int stock) {
  if (stock <= 0) return 'Out of Stock';
  if (stock <= 5) return 'Low Stock';
  return 'In Stock';
}

class Dimensions {
  final double width, height, depth;
  Dimensions({this.width = 0, this.height = 0, this.depth = 0});
  factory Dimensions.fromJson(Map<String, dynamic> j) => Dimensions(
        width: _d(j['width']),
        height: _d(j['height']),
        depth: _d(j['depth']),
      );
}

class Review {
  final int rating;
  final String comment, date, reviewerName, reviewerEmail;
  Review({
    this.rating = 0,
    this.comment = '',
    this.date = '',
    this.reviewerName = '',
    this.reviewerEmail = '',
  });
  factory Review.fromJson(Map<String, dynamic> j) => Review(
        rating: _i(j['rating']),
        comment: j['comment']?.toString() ?? '',
        date: j['date']?.toString() ?? '',
        reviewerName: j['reviewerName']?.toString() ?? '',
        reviewerEmail: j['reviewerEmail']?.toString() ?? '',
      );
}

class Meta {
  final String createdAt, updatedAt, barcode, qrCode;
  Meta({this.createdAt = '', this.updatedAt = '', this.barcode = '', this.qrCode = ''});
  factory Meta.fromJson(Map<String, dynamic> j) => Meta(
        createdAt: j['createdAt']?.toString() ?? '',
        updatedAt: j['updatedAt']?.toString() ?? '',
        barcode: j['barcode']?.toString() ?? '',
        qrCode: j['qrCode']?.toString() ?? '',
      );
}

class Category {
  final String slug, name, url;
  Category({required this.slug, required this.name, required this.url});
  factory Category.fromJson(Map<String, dynamic> j) => Category(
        slug: j['slug']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        url: j['url']?.toString() ?? '',
      );
}

class Product {
  final int id;
  final String title, description, category, brand, sku;
  final double price, discountPercentage, rating, weight;
  final int stock, minimumOrderQuantity;
  final List<String> tags, images;
  final Dimensions dimensions;
  final String warrantyInformation, shippingInformation, availabilityStatus, returnPolicy;
  final List<Review> reviews;
  final Meta meta;
  final String thumbnail;
  final bool isDeleted; // respons DELETE: isDeleted
  final String? deletedOn; // respons DELETE: deletedOn

  Product({
    required this.id,
    required this.title,
    this.description = '',
    this.category = '',
    this.price = 0,
    this.discountPercentage = 0,
    this.rating = 0,
    this.stock = 0,
    this.tags = const [],
    this.brand = '',
    this.sku = '',
    this.weight = 0,
    Dimensions? dimensions,
    this.warrantyInformation = '',
    this.shippingInformation = '',
    this.availabilityStatus = '',
    this.reviews = const [],
    this.returnPolicy = '',
    this.minimumOrderQuantity = 1,
    Meta? meta,
    this.thumbnail = '',
    this.images = const [],
    this.isDeleted = false,
    this.deletedOn,
  })  : dimensions = dimensions ?? Dimensions(),
        meta = meta ?? Meta();

  /// Harga setelah diskon
  double get finalPrice => price * (1 - discountPercentage / 100);

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: _i(j['id']),
        title: j['title']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        category: j['category']?.toString() ?? '',
        price: _d(j['price']),
        discountPercentage: _d(j['discountPercentage']),
        rating: _d(j['rating']),
        stock: _i(j['stock']),
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        brand: j['brand']?.toString() ?? '',
        sku: j['sku']?.toString() ?? '',
        weight: _d(j['weight']),
        dimensions: Dimensions.fromJson((j['dimensions'] as Map?)?.cast<String, dynamic>() ?? {}),
        warrantyInformation: j['warrantyInformation']?.toString() ?? '',
        shippingInformation: j['shippingInformation']?.toString() ?? '',
        availabilityStatus: j['availabilityStatus']?.toString() ?? '',
        reviews: (j['reviews'] as List?)
                ?.map((e) => Review.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            [],
        returnPolicy: j['returnPolicy']?.toString() ?? '',
        minimumOrderQuantity: _i(j['minimumOrderQuantity'], 1),
        meta: Meta.fromJson((j['meta'] as Map?)?.cast<String, dynamic>() ?? {}),
        thumbnail: j['thumbnail']?.toString() ?? '',
        images: (j['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
        isDeleted: j['isDeleted'] == true,
        deletedOn: j['deletedOn']?.toString(),
      );

  /// Body untuk POST /products/add dan PUT/PATCH /products/{id}
  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'category': category,
        'price': price,
        'discountPercentage': discountPercentage,
        'brand': brand,
        'stock': stock,
        'thumbnail': thumbnail,
      };

  Product copyWith({
    int? id,
    String? title,
    String? description,
    String? category,
    String? brand,
    double? price,
    double? discountPercentage,
    int? stock,
    String? availabilityStatus,
    String? thumbnail,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      rating: rating,
      stock: stock ?? this.stock,
      tags: tags,
      brand: brand ?? this.brand,
      sku: sku,
      weight: weight,
      dimensions: dimensions,
      warrantyInformation: warrantyInformation,
      shippingInformation: shippingInformation,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      reviews: reviews,
      returnPolicy: returnPolicy,
      minimumOrderQuantity: minimumOrderQuantity,
      meta: meta,
      thumbnail: thumbnail ?? this.thumbnail,
      images: images,
    );
  }
}

class ProductsResponse {
  final List<Product> products;
  final int total, skip, limit;
  ProductsResponse({
    required this.products,
    required this.total,
    required this.skip,
    required this.limit,
  });
  factory ProductsResponse.fromJson(Map<String, dynamic> j) {
    final list = (j['products'] as List?) ?? [];
    return ProductsResponse(
      products: list.map((e) => Product.fromJson((e as Map).cast<String, dynamic>())).toList(),
      total: _i(j['total'], list.length),
      skip: _i(j['skip']),
      limit: _i(j['limit'], 30),
    );
  }
}
