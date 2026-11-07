import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../services/api_service_products.dart';
import '../theme/app_colors.dart';
import '../widgets/product_image.dart';
import 'list_product_screen.dart' show prettify;

class DetailProductScreen extends StatefulWidget {
  final int id;
  const DetailProductScreen({super.key, required this.id});
  @override
  State<DetailProductScreen> createState() => _DetailProductScreenState();
}

class _DetailProductScreenState extends State<DetailProductScreen> {
  late Future<Product> _future;
  Product? _edited; // hasil edit pada sesi halaman ini
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// GET /products/{id} -> baca satu baris dari MySQL.
  Future<Product> _load() => ApiServiceProducts().getProduct(widget.id);

  void _reload() => setState(() => _future = _load());

  Future<void> _edit(Product p) async {
    final updated = await context.push<Product>('/edit/${p.id}', extra: p);
    if (updated != null && mounted) setState(() => _edited = updated);
  }

  Future<void> _confirmDelete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Hapus produk?'),
        content: Text('"${p.title}" akan dihapus permanen dari database.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentDark),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ProductProvider>().deleteProduct(p.id); // DELETE /products/{id} -> hapus di MySQL
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;
    context.pop();
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppColors.accentDark,
      behavior: SnackBarBehavior.floating,
      content: Text('"${p.title}" dihapus'),
    ));
  }

  Widget _circleButton(IconData icon, VoidCallback onTap, String tip) => Material(
        color: Colors.white.withAlpha(200),
        shape: const CircleBorder(),
        child: IconButton(icon: Icon(icon, size: 20), tooltip: tip, onPressed: onTap),
      );

  @override
  Widget build(BuildContext context) {
    final color = AppColors.cardColor(widget.id);
    return Scaffold(
      body: _edited != null
          ? _buildContent(_edited!, color)
          : FutureBuilder<Product>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          if (snap.hasError || !snap.hasData) {
            return SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.accent),
                    const SizedBox(height: 8),
                    const Text('Gagal memuat detail produk'),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                      onPressed: _reload,
                      child: const Text('Coba lagi'),
                    ),
                    TextButton(onPressed: () => context.pop(), child: const Text('Kembali')),
                  ],
                ),
              ),
            );
          }
          return _buildContent(snap.data!, color);
        },
      ),
    );
  }

  Widget _buildContent(Product p, Color color) {
    final imgs = p.images.isNotEmpty ? p.images : [p.thumbnail];
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                height: 360,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
                ),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    PageView.builder(
                      itemCount: imgs.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(40, 70, 40, 40),
                        child: ProductImage(url: imgs[i]),
                      ),
                    ),
                    if (imgs.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            imgs.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _page == i ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _page == i ? Colors.white : Colors.white54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 8, children: [
                      _chip(prettify(p.category), AppColors.lavender),
                      if (p.brand.isNotEmpty) _chip(p.brand, AppColors.mint),
                    ]),
                    const SizedBox(height: 12),
                    Text(p.title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFFC857)),
                      const SizedBox(width: 4),
                      Text(p.rating.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('  (${p.reviews.length} ulasan)',
                          style: const TextStyle(color: AppColors.textSoft)),
                    ]),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('\$${p.finalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accentDark)),
                        const SizedBox(width: 10),
                        if (p.discountPercentage >= 1) ...[
                          Text('\$${p.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.textSoft)),
                          const SizedBox(width: 8),
                          _chip('-${p.discountPercentage.round()}%', AppColors.pink),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: _info(Icons.inventory_2_outlined, 'Stok', '${p.stock}', AppColors.yellow)),
                      const SizedBox(width: 10),
                      Expanded(child: _info(Icons.verified_outlined, 'Status', p.availabilityStatus, AppColors.mint)),
                    ]),
                    const SizedBox(height: 22),
                    const Text('Deskripsi',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(p.description,
                        style: const TextStyle(height: 1.5, color: AppColors.textSoft)),
                    if (p.tags.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < p.tags.length; i++)
                            _chip('#${p.tags[i]}', AppColors.cardColor(i + 2)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.sky.withAlpha(120),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(children: [
                        _row('SKU', p.sku),
                        _row('Berat', '${p.weight} g'),
                        _row('Dimensi',
                            '${p.dimensions.width} x ${p.dimensions.height} x ${p.dimensions.depth}'),
                        _row('Garansi', p.warrantyInformation),
                        _row('Pengiriman', p.shippingInformation),
                        _row('Pengembalian', p.returnPolicy),
                        _row('Min. order', '${p.minimumOrderQuantity}'),
                      ]),
                    ),
                    if (p.reviews.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text('Ulasan',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      for (var i = 0; i < p.reviews.length; i++)
                        _reviewCard(p.reviews[i], AppColors.cardColor(i)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _circleButton(Icons.arrow_back_ios_new_rounded, () => context.pop(), 'Kembali'),
                const Spacer(),
                _circleButton(Icons.edit_rounded, () => _edit(p), 'Edit'),
                const SizedBox(width: 8),
                _circleButton(Icons.delete_outline_rounded, () => _confirmDelete(p), 'Hapus'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(14)),
        child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      );

  Widget _info(IconData icon, String label, String value, Color c) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Icon(icon, color: AppColors.text),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSoft)),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      );

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 100,
                child: Text(k, style: const TextStyle(color: AppColors.textSoft))),
            Expanded(
                child: Text(v.isEmpty ? '-' : v,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Widget _reviewCard(Review r, Color c) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.withAlpha(150), borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: Text(r.reviewerName.isEmpty ? '?' : r.reviewerName[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(r.reviewerName,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFC857)),
            Text('${r.rating}'),
          ]),
          const SizedBox(height: 8),
          Text(r.comment),
        ]),
      );
}
