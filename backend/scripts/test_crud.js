'use strict';
/**
 * Pengujian CRUD end-to-end: memastikan perubahan BENAR-BENAR tersimpan di MySQL.
 *
 * Cara jalan (backend + db sudah `docker compose up`):
 *   docker compose exec backend node scripts/test_crud.js
 *
 * Atau dari laptop (butuh Node 18+ dan `npm install` di folder backend):
 *   API_URL=http://localhost:3000 DB_HOST=127.0.0.1 DB_PORT=3307 node scripts/test_crud.js
 *
 * Tiap langkah dicek lewat API (GET) dan, jika driver MySQL tersedia,
 * langsung ke tabel `products` (SELECT) sebagai bukti di database.
 */
const API = process.env.API_URL || 'http://localhost:3000';

let passed = 0;
let failed = 0;
function check(name, cond, extra = '') {
  if (cond) {
    passed++;
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name} ${extra}`);
  }
}

async function call(method, path, body) {
  const res = await fetch(API + path, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try {
    data = await res.json();
  } catch (_) {}
  return { status: res.status, data };
}

async function openDb() {
  try {
    const mysql = require('mysql2/promise');
    const conn = await mysql.createConnection({
      host: process.env.DB_HOST || '127.0.0.1',
      port: Number(process.env.DB_PORT || 3306),
      user: process.env.DB_USER || 'pastel',
      password: process.env.DB_PASSWORD || 'pastel123',
      database: process.env.DB_NAME || 'pastel_shop',
    });
    return conn;
  } catch (e) {
    console.log(`  (cek langsung ke MySQL dilewati: ${e.code || e.message})`);
    return null;
  }
}

async function main() {
  console.log(`API: ${API}\n`);
  const db = await openDb();
  const dbRow = async (id) => {
    if (!db) return undefined;
    const [rows] = await db.query('SELECT * FROM products WHERE id = ?', [id]);
    return rows[0] || null;
  };

  console.log('[0] Koneksi');
  const health = await call('GET', '/health');
  check('GET /health = 200 & database connected', health.status === 200 && health.data?.database === 'connected');

  console.log('\n[1] READ - daftar produk dari database');
  const before = await call('GET', '/products?limit=5');
  check('GET /products = 200', before.status === 200);
  check('respons punya products[] dan total', Array.isArray(before.data?.products) && typeof before.data?.total === 'number');
  const totalBefore = before.data.total;
  console.log(`      total produk sebelum tes: ${totalBefore}`);

  console.log('\n[2] CREATE - tambah produk');
  const marker = `Tes Produk ${Date.now()}`;
  const created = await call('POST', '/products', {
    title: marker,
    description: 'Dibuat oleh test_crud.js',
    category: 'beauty',
    brand: 'TesBrand',
    price: 12.5,
    discountPercentage: 10,
    stock: 7,
    thumbnail: '',
    dimensions: { width: 1.5, height: 2.5, depth: 3.5 },
    warrantyInformation: '1 year warranty',
    shippingInformation: 'Ships in 2 days',
    returnPolicy: '30 days return policy',
    minimumOrderQuantity: 5,
    reviews: [
      { rating: 5, comment: 'Bagus', date: '2026-01-01T00:00:00.000Z', reviewerName: 'Tes', reviewerEmail: 'tes@x.com' },
    ],
  });
  check('POST /products = 201', created.status === 201, JSON.stringify(created.data));
  const id = created.data?.id;
  check('mendapat id baru dari MySQL (AUTO_INCREMENT)', Number.isInteger(id) && id > 0);
  const afterCreate = await call('GET', `/products/${id}`);
  check('GET /products/:id menemukan data baru', afterCreate.status === 200 && afterCreate.data.title === marker);
  const dc = afterCreate.data || {};
  check(
    'dimensi, garansi, pengiriman, pengembalian, min. order & ulasan tersimpan',
    dc.dimensions?.width === 1.5 && dc.dimensions?.depth === 3.5 &&
      dc.warrantyInformation === '1 year warranty' && dc.shippingInformation === 'Ships in 2 days' &&
      dc.returnPolicy === '30 days return policy' && dc.minimumOrderQuantity === 5 &&
      dc.reviews?.length === 1 && dc.reviews[0].reviewerName === 'Tes'
  );
  const rowC = await dbRow(id);
  if (db) check('baris ada di tabel MySQL', !!rowC && rowC.title === marker && Number(rowC.price) === 12.5);
  const listAfterCreate = await call('GET', '/products?limit=1');
  check(`total bertambah ${totalBefore} -> ${totalBefore + 1}`, listAfterCreate.data.total === totalBefore + 1);

  console.log('\n[3] VALIDASI - data salah ditolak');
  const bad = await call('POST', '/products', { title: '', price: -5 });
  check('POST data tidak valid = 400', bad.status === 400);

  console.log('\n[4] UPDATE - ubah data');
  const newTitle = marker + ' (EDIT)';
  const updated = await call('PUT', `/products/${id}`, {
    title: newTitle,
    description: 'Sudah diedit',
    category: 'beauty',
    brand: 'TesBrand',
    price: 20,
    discountPercentage: 0,
    stock: 3,
    thumbnail: '',
  });
  check('PUT /products/:id = 200', updated.status === 200, JSON.stringify(updated.data));
  const afterUpdate = await call('GET', `/products/${id}`);
  check('GET menampilkan data hasil edit', afterUpdate.data?.title === newTitle && afterUpdate.data?.price === 20 && afterUpdate.data?.stock === 3);
  check('status stok ikut berubah (Low Stock)', afterUpdate.data?.availabilityStatus === 'Low Stock');
  check(
    'detail (garansi, ulasan, dimensi) tidak hilang setelah edit dari aplikasi',
    afterUpdate.data?.warrantyInformation === '1 year warranty' &&
      afterUpdate.data?.reviews?.length === 1 && afterUpdate.data?.dimensions?.height === 2.5
  );
  const rowU = await dbRow(id);
  if (db) check('baris di MySQL ikut berubah', !!rowU && rowU.title === newTitle && Number(rowU.price) === 20 && rowU.stock === 3);
  const search = await call('GET', `/products/search?q=${encodeURIComponent('(EDIT)')}`);
  check('search menemukan produk hasil edit', search.data?.products?.some((p) => p.id === id));

  console.log('\n[5] DELETE - hapus data');
  const del = await call('DELETE', `/products/${id}`);
  check('DELETE /products/:id = 200 & isDeleted', del.status === 200 && del.data?.isDeleted === true);
  const afterDelete = await call('GET', `/products/${id}`);
  check('GET setelah hapus = 404', afterDelete.status === 404);
  const rowD = await dbRow(id);
  if (db) check('baris sudah hilang dari tabel MySQL', rowD === null);
  const listAfterDelete = await call('GET', '/products?limit=1');
  check(`total kembali ke ${totalBefore}`, listAfterDelete.data.total === totalBefore);
  const del2 = await call('DELETE', `/products/${id}`);
  check('DELETE id yang sama lagi = 404', del2.status === 404);

  if (db) await db.end();
  console.log(`\nHASIL: ${passed} lulus, ${failed} gagal`);
  process.exit(failed ? 1 : 0);
}

main().catch((e) => {
  console.error('Tes berhenti karena error:', e.message);
  process.exit(1);
});
