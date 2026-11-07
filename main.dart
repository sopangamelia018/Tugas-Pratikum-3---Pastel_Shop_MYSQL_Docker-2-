import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'models/product_model.dart';
import 'providers/product_provider.dart';
import 'screens/add_product_screen.dart';
import 'screens/detail_product_screen.dart';
import 'screens/edit_product_screen.dart';
import 'screens/list_product_screen.dart';
import 'theme/app_colors.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ProductProvider()..init(),
      child: const MyApp(),
    ),
  );
}

final GoRouter _router = GoRouter(routes: [
  // GET /products
  GoRoute(path: '/', builder: (c, s) => const ListProductScreen()),
  // GET /products/{id}
  GoRoute(
    path: '/detail/:id',
    builder: (c, s) => DetailProductScreen(id: int.parse(s.pathParameters['id']!)),
  ),
  // POST /products
  GoRoute(path: '/add', builder: (c, s) => const AddProductScreen()),
  // PUT /products/{id}  (Product dikirim lewat extra)
  GoRoute(
    path: '/edit/:id',
    redirect: (c, s) => s.extra is Product ? null : '/',
    builder: (c, s) => EditProductScreen(product: s.extra as Product),
  ),
]);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pastel Shop',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: AppColors.text,
              displayColor: AppColors.text,
            ),
      ),
    );
  }
}
