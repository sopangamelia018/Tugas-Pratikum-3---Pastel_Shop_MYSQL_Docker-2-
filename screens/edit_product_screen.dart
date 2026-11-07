import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/product_form.dart';

/// Edit produk -> PUT {API}/products/{id}  (UPDATE di MySQL)
/// Hasil update dikembalikan ke halaman sebelumnya lewat context.pop(updated).
class EditProductScreen extends StatelessWidget {
  final Product product;
  const EditProductScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return ProductFormPage(
      title: 'Edit Produk',
      subtitle: 'ID #${product.id}',
      headerColors: const [AppColors.peach, AppColors.pink],
      child: ProductForm(
        initial: product,
        submitLabel: 'Simpan Perubahan',
        onSubmit: (updated) async {
          final messenger = ScaffoldMessenger.of(context);
          final provider = context.read<ProductProvider>();

          final result =
              await provider.updateProduct(product.id, updated); // PUT /products/{id}

          if (!context.mounted) return;
          context.pop(result);
          messenger.showSnackBar(const SnackBar(
            backgroundColor: AppColors.accentDark,
            behavior: SnackBarBehavior.floating,
            content: Text('Produk berhasil diperbarui'),
          ));
        },
      ),
    );
  }
}
