import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../screens/list_product_screen.dart' show prettify;
import '../theme/app_colors.dart';
import 'product_image.dart';

/// Kerangka halaman form (header pastel + tombol kembali + isi form).
class ProductFormPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Color> headerColors;
  final Widget child;

  const ProductFormPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.headerColors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: headerColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Row(
                children: [
                  Material(
                    color: Colors.white.withAlpha(170),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800)),
                        Text(subtitle,
                            style: const TextStyle(color: AppColors.textSoft)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Form yang dipakai bersama oleh AddProductScreen dan EditProductScreen.
/// [initial] == null  -> mode tambah, selain itu mode edit.
class ProductForm extends StatefulWidget {
  final Product? initial;
  final String submitLabel;
  final Future<void> Function(Product product) onSubmit;

  const ProductForm({
    super.key,
    this.initial,
    required this.submitLabel,
    required this.onSubmit,
  });

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _category;
  late final TextEditingController _brand;
  late final TextEditingController _price;
  late final TextEditingController _discount;
  late final TextEditingController _stock;
  late final TextEditingController _thumbnail;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _title = TextEditingController(text: p?.title ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _brand = TextEditingController(text: p?.brand ?? '');
    _price = TextEditingController(text: p == null ? '' : '${p.price}');
    _discount =
        TextEditingController(text: p == null ? '0' : '${p.discountPercentage}');
    _stock = TextEditingController(text: p == null ? '' : '${p.stock}');
    _thumbnail = TextEditingController(text: p?.thumbnail ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _title, _description, _category, _brand,
      _price, _discount, _stock, _thumbnail,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final stock = int.parse(_stock.text.trim());
    final base = widget.initial ?? Product(id: 0, title: '');
    final product = base.copyWith(
      title: _title.text.trim(),
      description: _description.text.trim(),
      category: _category.text.trim(),
      brand: _brand.text.trim(),
      price: _num(_price.text),
      discountPercentage: _num(_discount.text) ?? 0,
      stock: stock,
      availabilityStatus: statusFromStock(stock),
      thumbnail: _thumbnail.text.trim(),
    );

    setState(() => _saving = true);
    try {
      await widget.onSubmit(product);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.accentDark,
        behavior: SnackBarBehavior.floating,
        content: Text(e.toString()),
      ));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickCategory() async {
    final cats = context.read<ProductProvider>().categoryList;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih kategori',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < cats.length; i++)
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx, cats[i]),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: cats[i] == _category.text
                                ? AppColors.accent
                                : AppColors.cardColor(i),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            prettify(cats[i]),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: cats[i] == _category.text
                                  ? Colors.white
                                  : AppColors.text,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _category.text = picked);
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSoft),
      prefixIcon: Icon(icon, color: AppColors.accentDark),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: border(AppColors.lavender),
      focusedBorder: border(AppColors.accent, 2),
      errorBorder: border(Colors.redAccent.shade100),
      focusedErrorBorder: border(Colors.redAccent.shade100, 2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _gap() => const SizedBox(height: 14);

  @override
  Widget build(BuildContext context) {
    final hasCategories = context.watch<ProductProvider>().categoryList.isNotEmpty;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          // Preview thumbnail (ikut berubah saat URL diketik)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _thumbnail,
            builder: (_, v, __) {
              final url = v.text.trim();
              return Container(
                height: 150,
                decoration: BoxDecoration(
                  color: AppColors.cardColor(widget.initial?.id ?? 4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: url.startsWith('http')
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: ProductImage(url: url),
                      )
                    : const Center(
                        child: Icon(Icons.image_outlined,
                            color: AppColors.textSoft, size: 44),
                      ),
              );
            },
          ),
          _gap(),
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('Nama produk', Icons.shopping_bag_outlined),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nama produk wajib diisi' : null,
          ),
          _gap(),
          TextFormField(
            controller: _description,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('Deskripsi', Icons.notes_rounded),
          ),
          _gap(),
          TextFormField(
            controller: _category,
            readOnly: hasCategories, // ada daftar kategori -> pilih lewat sheet
            onTap: hasCategories ? _pickCategory : null,
            decoration: _decoration(
              'Kategori',
              Icons.category_outlined,
              suffix: hasCategories
                  ? const Icon(Icons.keyboard_arrow_down_rounded)
                  : null,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Kategori wajib dipilih' : null,
          ),
          _gap(),
          TextFormField(
            controller: _brand,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration('Brand (opsional)', Icons.sell_outlined),
          ),
          _gap(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: _decoration('Harga (\$)', Icons.attach_money_rounded),
                  validator: (v) {
                    final n = _num(v ?? '');
                    return (n == null || n < 0) ? 'Harga tidak valid' : null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _discount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: _decoration('Diskon (%)', Icons.percent_rounded),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = _num(v);
                    return (n == null || n < 0 || n > 100) ? '0 - 100' : null;
                  },
                ),
              ),
            ],
          ),
          _gap(),
          TextFormField(
            controller: _stock,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _decoration('Stok', Icons.inventory_2_outlined),
            validator: (v) =>
                (v == null || int.tryParse(v.trim()) == null) ? 'Stok tidak valid' : null,
          ),
          _gap(),
          TextFormField(
            controller: _thumbnail,
            keyboardType: TextInputType.url,
            decoration:
                _decoration('URL gambar (opsional)', Icons.image_outlined),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return null;
              return s.startsWith('http') ? null : 'URL harus diawali http/https';
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Menyimpan...' : widget.submitLabel,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
