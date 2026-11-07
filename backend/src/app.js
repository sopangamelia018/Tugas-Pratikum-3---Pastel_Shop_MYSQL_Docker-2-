'use strict';
/**
 * REST API Pastel Shop (Express + MySQL).
 *
 * Bentuk JSON response dibuat sama dengan DummyJSON
 * ({ products, total, skip, limit }) supaya model Flutter tetap dipakai.
 *
 *   READ   GET    /products?limit=&skip=&sortBy=&order=
 *          GET    /products/search?q=
 *          GET    /products/category-list
 *          GET    /products/category/:slug
 *          GET    /products/:id
 *   CREATE POST   /products
 *   UPDATE PUT    /products/:id   (PATCH juga bisa, sama-sama partial merge)
 *   DELETE DELETE /products/:id
 */
const express = require('express');
const cors = require('cors');

// Kolom yang boleh dipakai untuk sorting (whitelist -> aman dari SQL injection)
const SORTABLE = {
  id: 'id',
  title: 'title',
  price: 'price',
  rating: 'rating',
  stock: 'stock',
  brand: 'brand',
};

class HttpError extends Error {
  constructor(status, message, details) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

// ------------------------------------------------------------------ helpers
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

function parseJsonArray(v) {
  if (Array.isArray(v)) return v.map(String);
  if (typeof v !== 'string' || v.trim() === '') return [];
  try {
    const parsed = JSON.parse(v);
    return Array.isArray(parsed) ? parsed.map(String) : [];
  } catch (_) {
    return [];
  }
}

/** reviews: array objek (atau string JSON) -> array objek bersih. */
function parseReviews(v) {
  let arr = v;
  if (typeof v === 'string') {
    try { arr = JSON.parse(v); } catch (_) { arr = []; }
  }
  if (!Array.isArray(arr)) return [];
  return arr
    .filter((r) => r && typeof r === 'object')
    .map((r) => ({
      rating: Math.min(5, Math.max(0, Math.round(Number(r.rating) || 0))),
      comment: String(r.comment || ''),
      date: String(r.date || ''),
      reviewerName: String(r.reviewerName || ''),
      reviewerEmail: String(r.reviewerEmail || ''),
    }));
}

function statusFromStock(stock) {
  if (stock <= 0) return 'Out of Stock';
  if (stock <= 5) return 'Low Stock';
  return 'In Stock';
}

function iso(v) {
  if (!v) return '';
  const d = v instanceof Date ? v : new Date(v);
  return Number.isNaN(d.getTime()) ? '' : d.toISOString();
}

function slugify(s) {
  return String(s || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '-');
}

function intParam(v, def, min, max) {
  const n = parseInt(v, 10);
  if (Number.isNaN(n)) return def;
  return Math.min(Math.max(n, min), max);
}

/** Baris tabel MySQL -> JSON yang dipahami aplikasi Flutter. */
function rowToProduct(r) {
  const stock = Number(r.stock);
  const thumbnail = r.thumbnail || '';
  const images = parseJsonArray(r.images);
  return {
    id: Number(r.id),
    title: r.title,
    description: r.description || '',
    category: r.category || '',
    price: Number(r.price),
    discountPercentage: Number(r.discount_percentage),
    rating: Number(r.rating),
    stock,
    tags: parseJsonArray(r.tags),
    brand: r.brand || '',
    sku: r.sku || '',
    weight: Number(r.weight),
    dimensions: { width: Number(r.width), height: Number(r.height), depth: Number(r.depth) },
    warrantyInformation: r.warranty_information || '',
    shippingInformation: r.shipping_information || '',
    availabilityStatus: statusFromStock(stock),
    reviews: parseReviews(r.reviews),
    returnPolicy: r.return_policy || '',
    minimumOrderQuantity: Number(r.minimum_order_quantity) || 1,
    meta: {
      createdAt: iso(r.created_at),
      updatedAt: iso(r.updated_at),
      barcode: r.barcode || '',
      qrCode: r.qr_code || '',
    },
    thumbnail,
    images: images.length ? images : thumbnail ? [thumbnail] : [],
  };
}

/**
 * Validasi + gabungkan body request dengan data lama (untuk update parsial).
 * Mengembalikan objek siap simpan (nama kolom snake_case).
 */
function buildRecord(body, existing) {
  const b = body && typeof body === 'object' ? body : {};
  const base = existing || {};
  const pick = (key, fallback) => (b[key] !== undefined ? b[key] : base[key] !== undefined ? base[key] : fallback);
  const errors = [];

  const title = String(pick('title', '')).trim();
  if (!title) errors.push('title wajib diisi');
  if (title.length > 255) errors.push('title maksimal 255 karakter');

  const price = Number(pick('price', 0));
  if (!Number.isFinite(price) || price < 0) errors.push('price harus angka >= 0');

  const discount = Number(pick('discountPercentage', 0));
  if (!Number.isFinite(discount) || discount < 0 || discount > 100) {
    errors.push('discountPercentage harus 0 - 100');
  }

  const stockRaw = Number(pick('stock', 0));
  if (!Number.isInteger(stockRaw) || stockRaw < 0) errors.push('stock harus bilangan bulat >= 0');

  const rating = Number(pick('rating', 0));
  if (!Number.isFinite(rating) || rating < 0 || rating > 5) errors.push('rating harus 0 - 5');

  const weight = Number(pick('weight', 0));
  if (!Number.isFinite(weight) || weight < 0) errors.push('weight harus angka >= 0');

  const category = slugify(pick('category', ''));
  const brand = String(pick('brand', '')).trim();
  const sku = String(pick('sku', '')).trim();
  const thumbnail = String(pick('thumbnail', '')).trim();
  const description = String(pick('description', '')).trim();
  if (category.length > 100) errors.push('category maksimal 100 karakter');
  if (brand.length > 100) errors.push('brand maksimal 100 karakter');
  if (sku.length > 64) errors.push('sku maksimal 64 karakter');
  if (thumbnail.length > 1000) errors.push('thumbnail maksimal 1000 karakter');

  const dim = pick('dimensions', {}) || {};
  const dimNum = (k) => {
    const n = Number(dim[k] ?? 0);
    if (!Number.isFinite(n) || n < 0) errors.push(`dimensions.${k} harus angka >= 0`);
    return n;
  };
  const width = dimNum('width');
  const height = dimNum('height');
  const depth = dimNum('depth');
  const warranty = String(pick('warrantyInformation', '')).trim();
  const shipping = String(pick('shippingInformation', '')).trim();
  const returnPolicy = String(pick('returnPolicy', '')).trim();
  if (warranty.length > 255) errors.push('warrantyInformation maksimal 255 karakter');
  if (shipping.length > 255) errors.push('shippingInformation maksimal 255 karakter');
  if (returnPolicy.length > 255) errors.push('returnPolicy maksimal 255 karakter');
  const minOrder = Number(pick('minimumOrderQuantity', 1));
  if (!Number.isInteger(minOrder) || minOrder < 1) errors.push('minimumOrderQuantity harus bilangan bulat >= 1');
  const reviews = parseReviews(pick('reviews', []));
  const meta = pick('meta', {}) || {};
  const barcode = String(meta.barcode || '').slice(0, 64);
  const qrCode = String(meta.qrCode || '').slice(0, 500);

  const tags = parseJsonArray(pick('tags', []));
  const images = parseJsonArray(pick('images', []));

  if (errors.length) throw new HttpError(400, errors.join('; '), errors);

  return {
    title,
    description,
    category,
    brand,
    price,
    discount_percentage: discount,
    rating,
    stock: stockRaw,
    sku,
    weight,
    tags: JSON.stringify(tags),
    images: JSON.stringify(images),
    thumbnail,
    width,
    height,
    depth,
    warranty_information: warranty,
    shipping_information: shipping,
    return_policy: returnPolicy,
    minimum_order_quantity: minOrder,
    reviews: JSON.stringify(reviews),
    barcode,
    qr_code: qrCode,
  };
}

/**
 * Data lama (camelCase) untuk merge saat update.
 * Jika thumbnail diganti dan images lama hanya berisi thumbnail lama,
 * images dikosongkan agar ikut thumbnail baru (tidak menampilkan gambar lama).
 */
function existingForMerge(row, body) {
  const product = rowToProduct(row);
  const rawImages = parseJsonArray(row.images);
  const b = body && typeof body === 'object' ? body : {};
  const onlyOldThumb =
    rawImages.length === 0 || (rawImages.length === 1 && rawImages[0] === (row.thumbnail || ''));
  const thumbChanged = b.thumbnail !== undefined && String(b.thumbnail).trim() !== (row.thumbnail || '');
  product.images = thumbChanged && b.images === undefined && onlyOldThumb ? [] : rawImages;
  return product;
}

// ---------------------------------------------------------------- app
function createApp(pool) {
  const app = express();
  app.use(cors());
  app.use(express.json({ limit: '1mb' }));

  // Log sederhana: terlihat di `docker compose logs -f backend`
  app.use((req, _res, next) => {
    console.log(`${new Date().toISOString()}  ${req.method} ${req.originalUrl}`);
    next();
  });

  async function findRow(id) {
    const [rows] = await pool.query('SELECT * FROM products WHERE id = ?', [id]);
    return rows[0] || null;
  }

  function parseId(req) {
    if (!/^\d+$/.test(req.params.id)) throw new HttpError(400, 'id harus berupa angka');
    return Number(req.params.id);
  }

  /** Query daftar dengan paging + sorting. */
  async function listProducts(req, whereSql, params) {
    const limit = intParam(req.query.limit, 30, 1, 200);
    const skip = intParam(req.query.skip, 0, 0, 1000000);
    const sortCol = SORTABLE[req.query.sortBy];
    const dir = String(req.query.order).toLowerCase() === 'desc' ? 'DESC' : 'ASC';
    // Default: produk terbaru (id terbesar) tampil paling atas.
    const orderSql = sortCol ? `ORDER BY ${sortCol} ${dir}, id DESC` : 'ORDER BY id DESC';

    const [countRows] = await pool.query(
      `SELECT COUNT(*) AS total FROM products ${whereSql}`,
      params
    );
    const [rows] = await pool.query(
      `SELECT * FROM products ${whereSql} ${orderSql} LIMIT ? OFFSET ?`,
      [...params, limit, skip]
    );
    return {
      products: rows.map(rowToProduct),
      total: Number(countRows[0].total),
      skip,
      limit,
    };
  }

  // ---- health check
  app.get(
    '/health',
    asyncHandler(async (_req, res) => {
      await pool.query('SELECT 1');
      res.json({ status: 'ok', database: 'connected' });
    })
  );

  app.get('/', (_req, res) => {
    res.json({ name: 'Pastel Shop API', endpoints: ['/health', '/products'] });
  });

  // ---- READ (urutan penting: route spesifik harus sebelum /products/:id)
  app.get(
    '/products/search',
    asyncHandler(async (req, res) => {
      const q = String(req.query.q || '').trim();
      if (!q) return res.json(await listProducts(req, '', []));
      const like = `%${q.replace(/[\\%_]/g, '\\$&')}%`;
      res.json(
        await listProducts(
          req,
          'WHERE (title LIKE ? OR brand LIKE ? OR description LIKE ? OR category LIKE ?)',
          [like, like, like, like]
        )
      );
    })
  );

  app.get(
    '/products/category-list',
    asyncHandler(async (_req, res) => {
      const [rows] = await pool.query(
        "SELECT DISTINCT category FROM products WHERE category <> '' ORDER BY category"
      );
      res.json(rows.map((r) => r.category));
    })
  );

  app.get(
    '/products/categories',
    asyncHandler(async (_req, res) => {
      const [rows] = await pool.query(
        "SELECT DISTINCT category FROM products WHERE category <> '' ORDER BY category"
      );
      res.json(
        rows.map((r) => ({
          slug: r.category,
          name: r.category,
          url: `/products/category/${r.category}`,
        }))
      );
    })
  );

  app.get(
    '/products/category/:slug',
    asyncHandler(async (req, res) => {
      res.json(await listProducts(req, 'WHERE category = ?', [req.params.slug]));
    })
  );

  app.get(
    '/products',
    asyncHandler(async (req, res) => {
      res.json(await listProducts(req, '', []));
    })
  );

  app.get(
    '/products/:id',
    asyncHandler(async (req, res) => {
      const row = await findRow(parseId(req));
      if (!row) throw new HttpError(404, 'Produk tidak ditemukan');
      res.json(rowToProduct(row));
    })
  );

  // ---- CREATE  (/products/add dipertahankan sebagai alias gaya DummyJSON)
  const createHandler = asyncHandler(async (req, res) => {
    const rec = buildRecord(req.body, null);
    const [result] = await pool.query(
      `INSERT INTO products
        (title, description, category, brand, price, discount_percentage, rating,
         stock, sku, weight, tags, images, thumbnail,
         width, height, depth, warranty_information, shipping_information,
         return_policy, minimum_order_quantity, reviews, barcode, qr_code)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        rec.title, rec.description, rec.category, rec.brand, rec.price,
        rec.discount_percentage, rec.rating, rec.stock, rec.sku, rec.weight,
        rec.tags, rec.images, rec.thumbnail,
        rec.width, rec.height, rec.depth, rec.warranty_information,
        rec.shipping_information, rec.return_policy, rec.minimum_order_quantity,
        rec.reviews, rec.barcode, rec.qr_code,
      ]
    );
    const row = await findRow(result.insertId);
    res.status(201).json(rowToProduct(row));
  });
  app.post('/products', createHandler);
  app.post('/products/add', createHandler);

  // ---- UPDATE
  const updateHandler = asyncHandler(async (req, res) => {
    const id = parseId(req);
    const current = await findRow(id);
    if (!current) throw new HttpError(404, 'Produk tidak ditemukan');
    const rec = buildRecord(req.body, existingForMerge(current, req.body));
    await pool.query(
      `UPDATE products SET
         title = ?, description = ?, category = ?, brand = ?, price = ?,
         discount_percentage = ?, rating = ?, stock = ?, sku = ?, weight = ?,
         tags = ?, images = ?, thumbnail = ?,
         width = ?, height = ?, depth = ?, warranty_information = ?,
         shipping_information = ?, return_policy = ?, minimum_order_quantity = ?,
         reviews = ?, barcode = ?, qr_code = ?
       WHERE id = ?`,
      [
        rec.title, rec.description, rec.category, rec.brand, rec.price,
        rec.discount_percentage, rec.rating, rec.stock, rec.sku, rec.weight,
        rec.tags, rec.images, rec.thumbnail,
        rec.width, rec.height, rec.depth, rec.warranty_information,
        rec.shipping_information, rec.return_policy, rec.minimum_order_quantity,
        rec.reviews, rec.barcode, rec.qr_code, id,
      ]
    );
    res.json(rowToProduct(await findRow(id)));
  });
  app.put('/products/:id', updateHandler);
  app.patch('/products/:id', updateHandler);

  // ---- DELETE
  app.delete(
    '/products/:id',
    asyncHandler(async (req, res) => {
      const id = parseId(req);
      const current = await findRow(id);
      if (!current) throw new HttpError(404, 'Produk tidak ditemukan');
      await pool.query('DELETE FROM products WHERE id = ?', [id]);
      res.json({
        ...rowToProduct(current),
        isDeleted: true,
        deletedOn: new Date().toISOString(),
      });
    })
  );

  // ---- 404 & error handler
  app.use((req, res) => {
    res.status(404).json({ message: `Route ${req.method} ${req.originalUrl} tidak ada` });
  });

  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    if (err instanceof HttpError) {
      return res.status(err.status).json({ message: err.message });
    }
    if (err && err.type === 'entity.parse.failed') {
      return res.status(400).json({ message: 'Body JSON tidak valid' });
    }
    console.error(err);
    res.status(500).json({ message: 'Kesalahan server / database' });
  });

  return app;
}

module.exports = { createApp, rowToProduct, buildRecord };
