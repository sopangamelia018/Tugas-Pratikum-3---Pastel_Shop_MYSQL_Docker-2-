import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/product_form.dart';

/// Tambah produk -> POST {API}/products  (INSERT ke MySQL)
class AddProductScreen extends StatelessWidget {
  const AddProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProductFormPage(
      title: 'Tambah Produk',
      subtitle: 'Isi data produk baru',
      headerColors: const [AppColors.mint, AppColors.sky],
      child: ProductForm(
        submitLabel: 'Simpan Produk',
        onSubmit: (product) async {
          final messenger = ScaffoldMessenger.of(context);
          final provider = context.read<ProductProvider>();

          final saved = await provider.addProduct(product); // POST /products

          if (!context.mounted) return;
          context.pop();
          messenger.showSnackBar(SnackBar(
            backgroundColor: AppColors.accentDark,
            behavior: SnackBarBehavior.floating,
            content: Text('"${saved.title}" berhasil ditambahkan (id ${saved.id})'),
          ));
        },
      ),
    );
  }
}
