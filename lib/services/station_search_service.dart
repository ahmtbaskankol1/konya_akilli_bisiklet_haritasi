import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/kiralik_istasyon.dart';
import '../models/park_alani.dart';
import '../models/tamir_istasyonu.dart';

/// Arama sonucu modeli
class AramaSonucu {
  final dynamic istasyon; // KiralikIstasyon, ParkAlani veya TamirIstasyonu
  final String tip; // 'kiralik', 'park', 'tamir'
  final String baslik;
  final String? altBaslik;
  final double? mesafe; // metre cinsinden (kullanıcı konumu varsa)
  final int eslesmeSkoru; // String eşleşme skoru (yüksek = daha iyi eşleşme)

  AramaSonucu({
    required this.istasyon,
    required this.tip,
    required this.baslik,
    this.altBaslik,
    this.mesafe,
    required this.eslesmeSkoru,
  });
}

/// İstasyon arama servisi
class StationSearchService {
  /// Türkçe karakterleri normalize eder (İ->i, ı->i, vb.)
  /// Tüm Türkçe karakterleri ASCII karşılıklarına çevirir ve küçük harfe dönüştürür
  /// Bu fonksiyon hem sorgu hem de veri için kullanılmalıdır
  /// Örnek: "kiralık" -> "kiralik", "KİRALIK" -> "kiralik"
  static String _normalizeTurkish(String text) {
    if (text.isEmpty) return '';
    
    return text
        // Türkçe karakterleri ASCII karşılıklarına çevir
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c')
        // Küçük harfe çevir
        .toLowerCase()
        // Fazla boşlukları temizle
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// İki string arasında eşleşme skoru hesaplar
  /// Daha yüksek skor = daha iyi eşleşme
  static int _eslesmeSkoruHesapla(String query, String text) {
    final normalizedQuery = _normalizeTurkish(query);
    final normalizedText = _normalizeTurkish(text);

    // Tam eşleşme
    if (normalizedText == normalizedQuery) return 100;

    // Başlangıçta eşleşme
    if (normalizedText.startsWith(normalizedQuery)) return 80;

    // İçinde geçiyor
    if (normalizedText.contains(normalizedQuery)) return 60;

    // Kelime başlangıçlarında eşleşme
    final words = normalizedText.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.startsWith(normalizedQuery)) return 70;
      if (word.contains(normalizedQuery)) return 50;
    }

    return 0;
  }

  /// Sorgudan istasyon tipini tespit eder ve kategori sorgusu olup olmadığını belirler
  /// Dönen değer: (tipler, kategoriSorgusu, kalanSorgu)
  /// - tipler: Aranacak istasyon tipleri
  /// - kategoriSorgusu: Sadece kategori anahtar kelimesi mi (true) yoksa ek metin var mı (false)
  /// - kalanSorgu: Kategori kelimeleri çıkarıldıktan sonra kalan sorgu metni
  static Map<String, dynamic> _tipTespitEt(String query) {
    final normalizedQuery = _normalizeTurkish(query);
    final tipler = <String>[];
    final kategoriKelimeleri = <String>[];
    
    // Kategori anahtar kelimeleri (her kelime normalize edilerek karşılaştırılacak)
    // Hem Türkçe karakterli hem de normalize edilmiş versiyonlar çalışacak
    final kiralikKelimeleri = ['kiralik', 'kiralık', 'istasyon', 'istasyonlar', 'istasyonlari'];
    final tamirKelimeleri = ['tamir', 'onarim', 'bakim', 'bakım', 'onarım'];
    final parkKelimeleri = ['park', 'park alani', 'park alanlari', 'park alanı', 'park alanları'];

    // Kiralık kategori kontrolü - hem tam eşleşme hem de başlangıç eşleşmesi kontrol edilir
    // Örnek: "ki", "kir", "kira", "kiral", "kirali", "kiralik", "kiralık" hepsi çalışır
    bool kiralikVar = false;
    String? bulunanKiralikKelime;
    for (final kelime in kiralikKelimeleri) {
      final normalizedKelime = _normalizeTurkish(kelime);
      // Normalize edilmiş sorgu ile normalize edilmiş kelimenin başlangıcı veya tamamı eşleşiyorsa
      if (normalizedQuery.contains(normalizedKelime) || normalizedKelime.startsWith(normalizedQuery)) {
        kiralikVar = true;
        bulunanKiralikKelime = kelime;
        break;
      }
    }
    if (kiralikVar && bulunanKiralikKelime != null) {
      tipler.add('kiralik');
      kategoriKelimeleri.add(bulunanKiralikKelime);
    }

    // Tamir kategori kontrolü - hem tam eşleşme hem de başlangıç eşleşmesi
    // Örnek: "ta", "tam", "tami", "tamir" hepsi çalışır
    bool tamirVar = false;
    String? bulunanTamirKelime;
    for (final kelime in tamirKelimeleri) {
      final normalizedKelime = _normalizeTurkish(kelime);
      // Normalize edilmiş sorgu ile normalize edilmiş kelimenin başlangıcı veya tamamı eşleşiyorsa
      if (normalizedQuery.contains(normalizedKelime) || normalizedKelime.startsWith(normalizedQuery)) {
        tamirVar = true;
        bulunanTamirKelime = kelime;
        break;
      }
    }
    if (tamirVar && bulunanTamirKelime != null) {
      tipler.add('tamir');
      kategoriKelimeleri.add(bulunanTamirKelime);
    }

    // Park kategori kontrolü - hem tam eşleşme hem de başlangıç eşleşmesi
    // Örnek: "pa", "par", "park" hepsi çalışır
    bool parkVar = false;
    String? bulunanParkKelime;
    for (final kelime in parkKelimeleri) {
      final normalizedKelime = _normalizeTurkish(kelime);
      // Normalize edilmiş sorgu ile normalize edilmiş kelimenin başlangıcı veya tamamı eşleşiyorsa
      if (normalizedQuery.contains(normalizedKelime) || normalizedKelime.startsWith(normalizedQuery)) {
        parkVar = true;
        bulunanParkKelime = kelime;
        break;
      }
    }
    if (parkVar && bulunanParkKelime != null) {
      tipler.add('park');
      kategoriKelimeleri.add(bulunanParkKelime);
    }

    // Kalan sorguyu bul: kategori kelimelerini çıkar (normalize edilmiş versiyonlarıyla)
    String kalanSorgu = normalizedQuery;
    for (final kelime in kategoriKelimeleri) {
      // Kelimeyi normalize et ve normalize edilmiş sorgudan çıkar
      final normalizedKelime = _normalizeTurkish(kelime);
      kalanSorgu = kalanSorgu.replaceAll(normalizedKelime, ' ').trim();
    }
    // Fazla boşlukları temizle
    kalanSorgu = kalanSorgu.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Eğer hiç tip tespit edilemediyse, tüm tipleri ara
    if (tipler.isEmpty) {
      tipler.addAll(['kiralik', 'park', 'tamir']);
    }

    // Kategori sorgusu: sadece kategori kelimeleri var, başka metin yok
    final kategoriSorgusu = tipler.isNotEmpty && kalanSorgu.isEmpty;

    return {
      'tipler': tipler,
      'kategoriSorgusu': kategoriSorgusu,
      'kalanSorgu': kalanSorgu,
    };
  }

  /// Tüm istasyonlarda arama yapar
  static List<AramaSonucu> aramaYap({
    required String query,
    required List<KiralikIstasyon> kiralikIstasyonlar,
    required List<ParkAlani> parkAlanlari,
    required List<TamirIstasyonu> tamirIstasyonlari,
    LatLng? kullaniciKonumu,
  }) {
    if (query.trim().isEmpty) {
      return [];
    }

    final tipBilgisi = _tipTespitEt(query);
    final tipler = tipBilgisi['tipler'] as List<String>;
    final kategoriSorgusu = tipBilgisi['kategoriSorgusu'] as bool;
    final kalanSorgu = tipBilgisi['kalanSorgu'] as String;
    final sonuclar = <AramaSonucu>[];

    // Kiralık istasyonlarda ara
    if (tipler.contains('kiralik')) {
      for (final istasyon in kiralikIstasyonlar) {
        int skor = 0;
        
        // Eğer kategori sorgusu ise (sadece "kiralık" gibi), tüm istasyonları dahil et
        if (kategoriSorgusu && tipler.length == 1 && tipler.first == 'kiralik') {
          skor = 50; // Varsayılan skor, mesafeye göre sıralanacak
        } else if (kalanSorgu.isNotEmpty) {
          // Kalan sorgu varsa, adres/kod içinde ara
          final kodSkoru = _eslesmeSkoruHesapla(kalanSorgu, istasyon.istasyonKodu);
          final adresSkoru = _eslesmeSkoruHesapla(kalanSorgu, istasyon.adres);
          skor = kodSkoru > adresSkoru ? kodSkoru : adresSkoru;
        } else {
          // Sadece kategori kelimesi var ama başka tip de var, yine dahil et
          skor = 50;
        }

        if (skor > 0) {
          // Mesafe hesapla (varsa)
          double? mesafe;
          if (kullaniciKonumu != null) {
            mesafe = Geolocator.distanceBetween(
              kullaniciKonumu.latitude,
              kullaniciKonumu.longitude,
              istasyon.konum.latitude,
              istasyon.konum.longitude,
            );
          }

          sonuclar.add(AramaSonucu(
            istasyon: istasyon,
            tip: 'kiralik',
            baslik: istasyon.adres,
            altBaslik: 'Kod: ${istasyon.istasyonKodu}',
            mesafe: mesafe,
            eslesmeSkoru: skor,
          ));
        }
      }
    }

    // Park alanlarında ara
    if (tipler.contains('park')) {
      for (final parkAlani in parkAlanlari) {
        int skor = 0;
        
        // Eğer kategori sorgusu ise (sadece "park" gibi), tüm park alanlarını dahil et
        if (kategoriSorgusu && tipler.length == 1 && tipler.first == 'park') {
          skor = 50; // Varsayılan skor, mesafeye göre sıralanacak
        } else if (kalanSorgu.isNotEmpty) {
          // Kalan sorgu varsa, isim içinde ara
          skor = _eslesmeSkoruHesapla(kalanSorgu, parkAlani.isim);
        } else {
          // Sadece kategori kelimesi var ama başka tip de var, yine dahil et
          skor = 50;
        }

        if (skor > 0) {
          double? mesafe;
          if (kullaniciKonumu != null) {
            mesafe = Geolocator.distanceBetween(
              kullaniciKonumu.latitude,
              kullaniciKonumu.longitude,
              parkAlani.konum.latitude,
              parkAlani.konum.longitude,
            );
          }

          sonuclar.add(AramaSonucu(
            istasyon: parkAlani,
            tip: 'park',
            baslik: parkAlani.isim,
            altBaslik: 'Park Alanı',
            mesafe: mesafe,
            eslesmeSkoru: skor,
          ));
        }
      }
    }

    // Tamir istasyonlarında ara
    if (tipler.contains('tamir')) {
      for (final tamirIstasyonu in tamirIstasyonlari) {
        int skor = 0;
        
        // Eğer kategori sorgusu ise (sadece "tamir" gibi), tüm tamir istasyonlarını dahil et
        if (kategoriSorgusu && tipler.length == 1 && tipler.first == 'tamir') {
          skor = 50; // Varsayılan skor, mesafeye göre sıralanacak
        } else if (kalanSorgu.isNotEmpty) {
          // Kalan sorgu varsa, başlık içinde ara
          skor = _eslesmeSkoruHesapla(kalanSorgu, tamirIstasyonu.baslik);
        } else {
          // Sadece kategori kelimesi var ama başka tip de var, yine dahil et
          skor = 50;
        }

        if (skor > 0) {
          double? mesafe;
          if (kullaniciKonumu != null) {
            mesafe = Geolocator.distanceBetween(
              kullaniciKonumu.latitude,
              kullaniciKonumu.longitude,
              tamirIstasyonu.konum.latitude,
              tamirIstasyonu.konum.longitude,
            );
          }

          sonuclar.add(AramaSonucu(
            istasyon: tamirIstasyonu,
            tip: 'tamir',
            baslik: tamirIstasyonu.baslik,
            altBaslik: 'Tamir Noktası',
            mesafe: mesafe,
            eslesmeSkoru: skor,
          ));
        }
      }
    }

    // Sonuçları sırala:
    // Kullanıcı konumu varsa: Önce mesafeye göre (yakından uzağa), sonra eşleşme skoruna göre
    // Kullanıcı konumu yoksa: Sadece eşleşme skoruna göre
    sonuclar.sort((a, b) {
      // Eğer kullanıcı konumu varsa, mesafeyi önceliklendir
      if (kullaniciKonumu != null) {
        // Her iki sonuçta da mesafe varsa, mesafeye göre sırala (yakından uzağa)
        if (a.mesafe != null && b.mesafe != null) {
          final mesafeFarki = a.mesafe!.compareTo(b.mesafe!);
          // Mesafe farkı varsa, mesafeye göre sırala (en yakın önce)
          if (mesafeFarki != 0) {
            return mesafeFarki;
          }
          // Mesafe eşitse, eşleşme skoruna göre sırala (yüksek skor önce)
          return b.eslesmeSkoru.compareTo(a.eslesmeSkoru);
        }
        // Birinde mesafe varsa, onu önceliklendir
        if (a.mesafe != null && b.mesafe == null) return -1;
        if (a.mesafe == null && b.mesafe != null) return 1;
      }
      // Mesafe yoksa veya eşitse, eşleşme skoruna göre sırala
      return b.eslesmeSkoru.compareTo(a.eslesmeSkoru);
    });

    // En fazla 10 sonuç döndür
    return sonuclar.take(10).toList();
  }

  /// En yakın eşleşen istasyonu bulur
  static AramaSonucu? enYakinEslestir({
    required String query,
    required List<KiralikIstasyon> kiralikIstasyonlar,
    required List<ParkAlani> parkAlanlari,
    required List<TamirIstasyonu> tamirIstasyonlari,
    required LatLng kullaniciKonumu,
  }) {
    final sonuclar = aramaYap(
      query: query,
      kiralikIstasyonlar: kiralikIstasyonlar,
      parkAlanlari: parkAlanlari,
      tamirIstasyonlari: tamirIstasyonlari,
      kullaniciKonumu: kullaniciKonumu,
    );

    if (sonuclar.isEmpty) return null;

    // Mesafeye göre en yakın olanı seç
    sonuclar.sort((a, b) {
      if (a.mesafe == null && b.mesafe == null) return 0;
      if (a.mesafe == null) return 1;
      if (b.mesafe == null) return -1;
      return a.mesafe!.compareTo(b.mesafe!);
    });

    return sonuclar.first;
  }
}

