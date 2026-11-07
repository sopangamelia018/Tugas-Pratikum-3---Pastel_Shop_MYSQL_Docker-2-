import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/product_image.dart';

String prettify(String slug) => slug
    .split('-')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

class ListProductScreen extends StatefulWidget {
  const ListProductScreen({super.key});
  @override
  State<ListProductScreen> createState() => _ListProductScreenState();
}

class _ListProductScreenState extends State<ListProductScreen> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        context.read<ProductProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<ProductProvider>().search(v);
    });
  }

  void _submitSearch(String v) {
    _debounce?.cancel();
    context.read<ProductProvider>().search(v);
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _debounce?.cancel();
    setState(() {});
    context.read<ProductProvider>().search('');
  }

  void _showSort() {
    final p = context.read<ProductProvider>();
    final options = <(String, String?, String)>[
      ('Default', null, 'asc'),
      ('Harga termurah', 'price', 'asc'),
      ('Harga termahal', 'price', 'desc'),
      ('Nama A - Z', 'title', 'asc'),
      ('Nama Z - A', 'title', 'desc'),
      ('Rating tertinggi', 'rating', 'desc'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Urutkan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...options.map((o) {
                final selected = p.sortBy == o.$2 && (o.$2 == null || p.order == o.$3);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(o.$1),
                  trailing: selected
                      ? const Icon(Icons.check_circle, color: AppColors.accentDark)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    p.setSort(o.$2, o.$3);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProductProvider>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(p),
            _buildCategories(p),
            Expanded(child: _buildBody(p)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ProductProvider p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.pink, AppColors.lavender],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pastel Shop',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Temukan produk favoritmu',
                        style: TextStyle(color: AppColors.textSoft)),
                  ],
                ),
              ),
              Material(
                color: Colors.white.withAlpha(170),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.sort_rounded),
                  tooltip: 'Urutkan',
                  onPressed: _showSort,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              onSubmitted: _submitSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari produk (mis. phone, mascara)...',
                hintStyle: const TextStyle(color: AppColors.textSoft, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.accentDark),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded), onPressed: _clearSearch),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories(ProductProvider p) {
    final cats = ['', ...p.categoryList];
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = cats[i];
          final selected = p.selectedCategory == c;
          return GestureDetector(
            onTap: () {
              _searchCtrl.clear();
              setState(() {});
              p.setQueryAndCategory('', c);
              if (_scroll.hasClients) _scroll.jumpTo(0);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : AppColors.cardColor(i),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                c.isEmpty ? 'Semua' : prettify(c),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.text,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(ProductProvider p) {
    if (p.loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (p.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.accent),
              const SizedBox(height: 12),
              Text(p.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: () => p.fetchProducts(),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }
    if (p.products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: AppColors.accent),
            SizedBox(height: 8),
            Text('Produk tidak ditemukan'),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.accentDark,
      onRefresh: p.fetchProducts,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('${p.products.length} dari ${p.displayTotal} produk',
                  style: const TextStyle(color: AppColors.textSoft, fontSize: 12)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.66,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ProductCard(product: p.products[i]),
                childCount: p.products.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: p.loadingMore
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : const SizedBox(height: 56),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.cardColor(product.id);
    return GestureDetector(
      onTap: () => context.push('/detail/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: color.withAlpha(140), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration:
                    BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: ProductImage(url: product.thumbnail),
                      ),
                    ),
                    if (product.discountPercentage >= 1)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.white.withAlpha(220),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text('-${product.discountPercentage.round()}%',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentDark)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFC857)),
                      const SizedBox(width: 2),
                      Text(product.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.accentDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
