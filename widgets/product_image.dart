import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Gambar produk dari CDN. Aman jika URL kosong (produk baru tanpa gambar).
class ProductImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const ProductImage({super.key, required this.url, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    const fallback = Center(
      child: Icon(Icons.image_not_supported_outlined,
          color: AppColors.textSoft, size: 40),
    );
    if (url.trim().isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, __) =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
