import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/product_model.dart';

void main() {
  test('Product.fromJson memetakan respons API backend (MySQL)', () {
    final p = Product.fromJson({
      'id': 1,
      'title': 'Essence Mascara Lash Princess',
      'category': 'beauty',
      'price': 9.99,
      'discountPercentage': 7.17,
      'rating': 4.94,
      'stock': 5,
      'brand': 'Essence',
    });
    expect(p.id, 1);
    expect(p.title, 'Essence Mascara Lash Princess');
    expect(p.price, 9.99);
    expect(p.stock, 5);
  });

  test('Product.toJson mengirim field yang disimpan ke tabel products', () {
    final p = Product(
      id: 0,
      title: 'Tes',
      description: 'desc',
      category: 'beauty',
      brand: 'B',
      price: 10,
      discountPercentage: 5,
      stock: 3,
      thumbnail: '',
    );
    final j = p.toJson();
    expect(j['title'], 'Tes');
    expect(j['price'], 10);
    expect(j['discountPercentage'], 5);
    expect(j['stock'], 3);
  });

  test('statusFromStock', () {
    expect(statusFromStock(0), 'Out of Stock');
    expect(statusFromStock(3), 'Low Stock');
    expect(statusFromStock(50), 'In Stock');
  });
}
