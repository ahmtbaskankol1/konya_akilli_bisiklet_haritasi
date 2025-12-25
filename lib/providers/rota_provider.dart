import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/rota_verisi.dart';
import '../services/rota_servisi.dart';

/// Aktif rota provider'ı
/// Seçili rota verisini tutar
final aktifRotaProvider = StateProvider<RotaVerisi?>((ref) => null);

/// Rota versiyonu provider'ı
/// Her rota güncellemesinde artar, polyline layer'ın rebuild edilmesini sağlar
final rotaVersiyonuProvider = StateProvider<int>((ref) => 0);

/// Manuel rota oluşturma devam ediyor mu?
/// Bu flag, otomatik reroute'un manuel rota oluşturma sırasında çalışmasını önler
final manuelRotaOlusturmaDevamEdiyorProvider = StateProvider<bool>((ref) => false);

/// Rota hesaplama provider'ı
/// İki nokta arasında rota hesaplar
final rotaHesaplamaProvider = FutureProvider.family<RotaVerisi?, RotaParametreleri>(
  (ref, parametreler) async {
    try {
      // Rota koordinatlarını hesapla
      final koordinatlar = await RotaServisi.rotaHesapla(
        baslangic: parametreler.baslangic,
        bitis: parametreler.bitis,
        profil: parametreler.profil,
      );

      if (koordinatlar == null || koordinatlar.isEmpty) {
        return null;
      }

      // Rota bilgilerini al (mesafe ve süre)
      final bilgiler = await RotaServisi.rotaBilgileriAl(
        baslangic: parametreler.baslangic,
        bitis: parametreler.bitis,
        profil: parametreler.profil,
      );

      final rotaVerisi = RotaVerisi(
        koordinatlar: koordinatlar,
        mesafe: bilgiler?['mesafe'],
        sure: bilgiler?['sure'],
        baslangic: parametreler.baslangic,
        bitis: parametreler.bitis,
      );

      // NOT: Rota versiyonunu ve aktifRota'yı burada SET ETMEYİN
      // Çünkü reroute işlemi kendi state yönetimini yapıyor
      // Sadece rota verisini döndür, state yönetimi çağıran kodda yapılsın
      // ref.read(rotaVersiyonuProvider.notifier).state++;  // REMOVED - handled by caller
      // ref.read(aktifRotaProvider.notifier).state = rotaVerisi;  // REMOVED - handled by caller

      return rotaVerisi;
    } catch (e) {
      print('Rota hesaplama hatası: $e');
      return null;
    }
  },
);

/// Rota parametreleri modeli
class RotaParametreleri {
  final LatLng baslangic;
  final LatLng bitis;
  final String profil; // 'driving', 'walking', 'cycling'

  const RotaParametreleri({
    required this.baslangic,
    required this.bitis,
    this.profil = 'driving',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RotaParametreleri &&
          runtimeType == other.runtimeType &&
          baslangic == other.baslangic &&
          bitis == other.bitis &&
          profil == other.profil;

  @override
  int get hashCode => baslangic.hashCode ^ bitis.hashCode ^ profil.hashCode;
}

