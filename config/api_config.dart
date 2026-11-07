/// Konfigurasi alamat backend (API Pastel Shop yang jalan di Docker).
///
/// Cara mengatur (pilih salah satu):
///  1. Ubah [serverIp] di bawah menjadi IP komputer/laptop kamu, ATAU
///  2. Kirim saat menjalankan aplikasi tanpa mengubah kode:
///       flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
///
/// Cara mencari IP laptop:
///   Windows : buka CMD -> ketik `ipconfig` -> lihat "IPv4 Address"
///   macOS   : `ipconfig getifaddr en0`
///   Linux   : `hostname -I`
///
/// Aturan alamat:
///   HP fisik (satu WiFi dengan laptop) -> IP laptop, mis. 192.168.1.10
///   Emulator Android                    -> 10.0.2.2
///   Flutter Web / Windows desktop       -> localhost
class ApiConfig {
  static const String serverIp = '192.168.1.18'; // <-- GANTI dengan IP laptop kamu
  static const String port = '3000';

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://$serverIp:$port',
  );
}
