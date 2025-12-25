import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/station_search_service.dart';
import '../providers/istasyon_provider.dart';
import '../providers/konum_provider.dart';

/// Arama sorgusu provider'ı
final aramaSorgusuProvider = StateProvider<String>((ref) => '');

/// Arama sonuçları provider'ı
final aramaSonuclariProvider = Provider<List<AramaSonucu>>((ref) {
  final sorgu = ref.watch(aramaSorgusuProvider);
  
  // Sorgu boşsa boş liste döndür
  if (sorgu.trim().isEmpty) {
    return [];
  }

  // İstasyon verilerini al
  final kiralikAsync = ref.watch(kiralikIstasyonlarProvider);
  final parkAsync = ref.watch(parkAlanlariProvider);
  final tamirAsync = ref.watch(tamirIstasyonlariProvider);

  // Veriler yüklenene kadar boş liste döndür
  if (kiralikAsync.isLoading || parkAsync.isLoading || tamirAsync.isLoading) {
    return [];
  }

  if (kiralikAsync.hasError || parkAsync.hasError || tamirAsync.hasError) {
    return [];
  }

  final kiralik = kiralikAsync.value ?? [];
  final park = parkAsync.value ?? [];
  final tamir = tamirAsync.value ?? [];

  // Kullanıcı konumunu al (stream'den son değeri)
  final konumAsync = ref.watch(konumGuncellemeleriProvider);
  LatLng? kullaniciKonumu;
  
  konumAsync.whenData((konum) {
    kullaniciKonumu = konum;
  });

  // Arama yap
  return StationSearchService.aramaYap(
    query: sorgu,
    kiralikIstasyonlar: kiralik,
    parkAlanlari: park,
    tamirIstasyonlari: tamir,
    kullaniciKonumu: kullaniciKonumu,
  );
});

/// En yakın eşleşen istasyon provider'ı
/// Arama sorgusu ve kullanıcı konumuna göre en yakın istasyonu bulur
final enYakinAramaSonucuProvider = Provider<AramaSonucu?>((ref) {
  final sorgu = ref.watch(aramaSorgusuProvider);
  
  if (sorgu.trim().isEmpty) {
    return null;
  }

  // İstasyon verilerini al
  final kiralikAsync = ref.watch(kiralikIstasyonlarProvider);
  final parkAsync = ref.watch(parkAlanlariProvider);
  final tamirAsync = ref.watch(tamirIstasyonlariProvider);

  if (kiralikAsync.isLoading || parkAsync.isLoading || tamirAsync.isLoading) {
    return null;
  }

  if (kiralikAsync.hasError || parkAsync.hasError || tamirAsync.hasError) {
    return null;
  }

  final kiralik = kiralikAsync.value ?? [];
  final park = parkAsync.value ?? [];
  final tamir = tamirAsync.value ?? [];

  // Kullanıcı konumunu al
  final konumAsync = ref.watch(konumGuncellemeleriProvider);
  
  return konumAsync.when(
    data: (konum) {
      if (konum == null) {
        return null; // Konum yoksa en yakın hesaplanamaz
      }
      
      return StationSearchService.enYakinEslestir(
        query: sorgu,
        kiralikIstasyonlar: kiralik,
        parkAlanlari: park,
        tamirIstasyonlari: tamir,
        kullaniciKonumu: konum,
      );
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

