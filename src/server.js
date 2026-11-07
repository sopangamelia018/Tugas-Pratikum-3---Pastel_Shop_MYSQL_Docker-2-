'use strict';
const mysql = require('mysql2/promise');
const { createApp } = require('./app');

// Konfigurasi dibaca dari environment (diisi oleh docker-compose.yml / file .env)
const config = {
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'pastel',
  password: process.env.DB_PASSWORD || 'pastel123',
  database: process.env.DB_NAME || 'pastel_shop',
};
const PORT = Number(process.env.PORT || 3000);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitForDatabase(pool, tries = 30) {
  for (let i = 1; i <= tries; i++) {
    try {
      await pool.query('SELECT 1');
      console.log(`[db] terhubung ke MySQL ${config.host}:${config.port}/${config.database}`);
      return;
    } catch (e) {
      console.log(`[db] menunggu MySQL (${i}/${tries}): ${e.code || e.message}`);
      await sleep(2000);
    }
  }
  throw new Error('Tidak bisa terhubung ke MySQL. Cek konfigurasi DB_* dan container db.');
}

async function main() {
  const pool = mysql.createPool({
    ...config,
    waitForConnections: true,
    connectionLimit: 10,
    charset: 'utf8mb4',
    timezone: '+00:00',
    decimalNumbers: true,
  });
  await waitForDatabase(pool);

  const app = createApp(pool);
  // 0.0.0.0 = bisa diakses dari HP lewat IP laptop (bukan hanya localhost)
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`[api] Pastel Shop API berjalan di http://0.0.0.0:${PORT}`);
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
