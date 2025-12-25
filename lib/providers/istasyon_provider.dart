import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/istasyon_turu.dart';
import '../models/kiralik_istasyon.dart';
import '../models/park_alani.dart';
import '../models/tamir_istasyonu.dart';
import '../services/veri_servisi.dart';

/// Seçili istasyon türü provider'ı
final seciliIstasyonTuruProvider = StateProvider<IstasyonTuru>(
  (ref) => IstasyonTuru.hepsi,
);

/// Kiralık istasyonlar provider'ı
final kiralikIstasyonlarProvider = FutureProvider<List<KiralikIstasyon>>(
  (ref) async {
    return await VeriServisi.kiralikIstasyonlariYukle();
  },
);

/// Park alanları provider'ı
final parkAlanlariProvider = FutureProvider<List<ParkAlani>>(
  (ref) async {
    return await VeriServisi.parkAlanlariYukle();
  },
);

/// Tamir istasyonları provider'ı
final tamirIstasyonlariProvider = FutureProvider<List<TamirIstasyonu>>(
  (ref) async {
    return await VeriServisi.tamirIstasyonlariYukle();
  },
);

/// Filtrelenmiş istasyonlar provider'ı
/// Seçili türe göre ilgili istasyonları döndürür
final filtrelenmisIstasyonlarProvider = Provider<AsyncValue<FiltrelenmisIstasyonlar>>(
  (ref) {
    final seciliTur = ref.watch(seciliIstasyonTuruProvider);
    final kiralikAsync = ref.watch(kiralikIstasyonlarProvider);
    final parkAsync = ref.watch(parkAlanlariProvider);
    final tamirAsync = ref.watch(tamirIstasyonlariProvider);

    // Tüm veriler yüklenene kadar bekle
    if (kiralikAsync.isLoading || parkAsync.isLoading || tamirAsync.isLoading) {
      return const AsyncValue.loading();
    }

    if (kiralikAsync.hasError || parkAsync.hasError || tamirAsync.hasError) {
      return AsyncValue.error(
        'Veriler yüklenirken hata oluştu',
        StackTrace.current,
      );
    }

    final kiralik = kiralikAsync.value ?? [];
    final park = parkAsync.value ?? [];
    final tamir = tamirAsync.value ?? [];

    // Debug: Yüklenen verileri göster
    print('=== FİLTRELENMİŞ İSTASYONLAR ===');
    print('Kiralık: ${kiralik.length} adet');
    print('Park: ${park.length} adet');
    print('Tamir: ${tamir.length} adet');
    print('Seçili tür: $seciliTur');
    
    if (park.isNotEmpty) {
      print('İlk park alanı: ${park.first.isim} - Konum: ${park.first.konum}');
    }

    return AsyncValue.data(
      FiltrelenmisIstasyonlar(
        kiralik: seciliTur == IstasyonTuru.kiralik || seciliTur == IstasyonTuru.hepsi
            ? kiralik
            : [],
        park: seciliTur == IstasyonTuru.park || seciliTur == IstasyonTuru.hepsi
            ? park
            : [],
        tamir: seciliTur == IstasyonTuru.tamir || seciliTur == IstasyonTuru.hepsi
            ? tamir
            : [],
      ),
    );
  },
);

/// Filtrelenmiş istasyonlar modeli
class FiltrelenmisIstasyonlar {
  final List<KiralikIstasyon> kiralik;
  final List<ParkAlani> park;
  final List<TamirIstasyonu> tamir;

  FiltrelenmisIstasyonlar({
    required this.kiralik,
    required this.park,
    required this.tamir,
  });

  /// Toplam istasyon sayısı
  int get toplamSayi => kiralik.length + park.length + tamir.length;
}

