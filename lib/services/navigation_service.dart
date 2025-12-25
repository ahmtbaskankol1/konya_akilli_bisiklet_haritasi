import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/rota_verisi.dart';
import '../models/kiralik_istasyon.dart';
import '../models/park_alani.dart';
import '../models/tamir_istasyonu.dart';

/// Navigasyon metrikleri modeli
class NavigasyonMetrikleri {
  final double kalanMesafe; // metre
  final double kalanSure; // saniye
  final DateTime? varisZamani;
  final String? sonrakiDonus;
  final double? sonrakiDonusMesafesi; // metre
  final int? sonrakiDonusIndeksi;

  const NavigasyonMetrikleri({
    required this.kalanMesafe,
    required this.kalanSure,
    this.varisZamani,
    this.sonrakiDonus,
    this.sonrakiDonusMesafesi,
    this.sonrakiDonusIndeksi,
  });
}

/// Navigasyon servisi
/// Rota üzerinde navigasyon metriklerini hesaplar
/// Google Maps benzeri ileri projeksiyon ve dönüş takibi mantığı kullanır
class NavigationServisi {
  // Bisiklet için varsayılan hız (km/h)
  static const double varsayilanBisikletHizi = 15.0; // km/h
  
  // Metre/saniye'ye çevir
  static const double varsayilanBisikletHiziMs = varsayilanBisikletHizi / 3.6; // m/s

  // Navigasyon parametreleri
  static const double gpsSapmaToleransi = 50.0; // metre - GPS sapmalarını kabul et
  static const double minimumDonusMesafesi = 15.0; // metre - Dönüş mesafesi eşiği
  static const double donusAciEsigi = 35.0; // derece - Minimum dönüş açısı
  static const double donusGecisMesafesi = 20.0; // metre - Dönüşü geçme eşiği
  static const double ileriProjeksiyonMesafesi = 30.0; // metre - İleri bakma mesafesi

  /// Kullanıcının rotadaki gerçek ilerleme noktasını bulur (forward projection)
  /// Google Maps benzeri mantık: Kullanıcının geçtiği noktaları atlar, sadece ileri bakır
  /// [kullaniciKonumu] Kullanıcının mevcut konumu
  /// [rotaKoordinatlari] Rota koordinatları listesi
  /// [oncekiIlerlemeIndeks] Önceki hesaplamada bulunan ilerleme indeksi (opsiyonel)
  /// 
  /// Dönen değer: (ilerlemeIndeks, ilerlemeNokta, rotadanUzaklik)
  static Map<String, dynamic> rotaUzerindekiIlerlemeNoktasiBul(
    LatLng kullaniciKonumu,
    List<LatLng> rotaKoordinatlari, {
    int? oncekiIlerlemeIndeks,
  }) {
    if (rotaKoordinatlari.isEmpty) {
      return {
        'indeks': 0,
        'nokta': kullaniciKonumu,
        'mesafe': 0.0,
      };
    }

    // Önceki ilerleme noktasından başla (forward projection için)
    int baslangicIndeks = math.max(0, (oncekiIlerlemeIndeks ?? 0) - 5);
    int enIyiIndeks = baslangicIndeks;
    double enKisaMesafe = double.infinity;
    LatLng enIyiNokta = rotaKoordinatlari[baslangicIndeks];

    // Segment bazlı arama (daha hassas)
    for (int i = baslangicIndeks; i < rotaKoordinatlari.length - 1; i++) {
      final p1 = rotaKoordinatlari[i];
      final p2 = rotaKoordinatlari[i + 1];
      
      final segmentSonuc = _segmentUzerindeIlerlemeBul(kullaniciKonumu, p1, p2, i);
      final mesafe = segmentSonuc['mesafe'] as double;
      final nokta = segmentSonuc['nokta'] as LatLng;
      final t = segmentSonuc['t'] as double;

      // Sadece ileriye bakan segmentler (t > 0.5 veya yeni segment)
      // Bu, kullanıcının geçtiği noktaları atlar
      if (mesafe < enKisaMesafe) {
        // Eğer önceki indeksten geriye gidiyorsak, sadece çok yakınsa kabul et
        if (i < (oncekiIlerlemeIndeks ?? 0) && mesafe > 10.0) {
          continue;
        }
        
        enKisaMesafe = mesafe;
        enIyiIndeks = i;
        enIyiNokta = nokta;
      }

      // Eğer segment üzerindeki nokta segment sonuna yakınsa, bir sonraki segmenti de kontrol et
      if (t > 0.7 && i < rotaKoordinatlari.length - 2) {
        final p3 = rotaKoordinatlari[i + 2];
        final segmentSonuc2 = _segmentUzerindeIlerlemeBul(kullaniciKonumu, p2, p3, i + 1);
        final mesafe2 = segmentSonuc2['mesafe'] as double;
        if (mesafe2 < enKisaMesafe) {
          enKisaMesafe = mesafe2;
          enIyiIndeks = i + 1;
          enIyiNokta = segmentSonuc2['nokta'] as LatLng;
        }
      }
    }

    // GPS sapması toleransı: Eğer rotadan çok uzaksak, en yakın noktayı kullan
    if (enKisaMesafe > gpsSapmaToleransi && oncekiIlerlemeIndeks != null) {
      // Önceki noktaya yakın bir segment bul
      final oncekiNokta = rotaKoordinatlari[math.min(oncekiIlerlemeIndeks, rotaKoordinatlari.length - 1)];
      final mesafeOnceki = Geolocator.distanceBetween(
        kullaniciKonumu.latitude,
        kullaniciKonumu.longitude,
        oncekiNokta.latitude,
        oncekiNokta.longitude,
      );
      
      if (mesafeOnceki < gpsSapmaToleransi * 2) {
        // Önceki noktaya yakınsak, o noktadan devam et
        return {
          'indeks': oncekiIlerlemeIndeks,
          'nokta': oncekiNokta,
          'mesafe': mesafeOnceki,
        };
      }
    }

    return {
      'indeks': enIyiIndeks,
      'nokta': enIyiNokta,
      'mesafe': enKisaMesafe,
    };
  }

  /// Segment üzerinde ilerleme noktası bulur
  static Map<String, dynamic> _segmentUzerindeIlerlemeBul(
    LatLng nokta,
    LatLng p1,
    LatLng p2,
    int segmentIndeks,
  ) {
    final dx = p2.longitude - p1.longitude;
    final dy = p2.latitude - p1.latitude;
    
    if (dx == 0 && dy == 0) {
      final mesafe = Geolocator.distanceBetween(
        nokta.latitude, nokta.longitude,
        p1.latitude, p1.longitude,
      );
      return {
        'mesafe': mesafe,
        'nokta': p1,
        't': 0.0,
      };
    }
    
    // Parametrik t değeri (0-1 arası)
    final t = ((nokta.longitude - p1.longitude) * dx + (nokta.latitude - p1.latitude) * dy) /
              (dx * dx + dy * dy);
    
    // t'yi 0-1 arasına sınırla
    final clampedT = t.clamp(0.0, 1.0);
    
    // Segment üzerindeki en yakın nokta
    final enYakinNokta = LatLng(
      p1.latitude + clampedT * dy,
      p1.longitude + clampedT * dx,
    );
    
    // Mesafeyi hesapla
    final mesafe = Geolocator.distanceBetween(
      nokta.latitude, nokta.longitude,
      enYakinNokta.latitude, enYakinNokta.longitude,
    );

    return {
      'mesafe': mesafe,
      'nokta': enYakinNokta,
      't': clampedT,
    };
  }

  /// Eski fonksiyon - geriye dönük uyumluluk için
  /// Kullanıcının rotadaki en yakın noktasını bulur
  static Map<String, dynamic> enYakinRotaNoktasiBul(
    LatLng kullaniciKonumu,
    List<LatLng> rotaKoordinatlari,
  ) {
    return rotaUzerindekiIlerlemeNoktasiBul(kullaniciKonumu, rotaKoordinatlari);
  }

  /// Kullanıcının rotadan ne kadar uzakta olduğunu hesaplar
  static double rotadanUzaklikHesapla(
    LatLng kullaniciKonumu,
    List<LatLng> rotaKoordinatlari,
  ) {
    if (rotaKoordinatlari.isEmpty) {
      return double.infinity;
    }
    
    final sonuc = rotaUzerindekiIlerlemeNoktasiBul(kullaniciKonumu, rotaKoordinatlari);
    return sonuc['mesafe'] as double;
  }

  /// Kalan mesafeyi hesaplar (kullanıcıdan hedefe kadar)
  /// Rota üzerindeki gerçek ilerleme noktasından hedefe kadar
  static double kalanMesafeHesapla(
    LatLng kullaniciKonumu,
    RotaVerisi rota, {
    int? oncekiIlerlemeIndeks,
  }) {
    if (rota.koordinatlar.isEmpty) return 0.0;

    // Gerçek ilerleme noktasını bul
    final ilerleme = rotaUzerindekiIlerlemeNoktasiBul(
      kullaniciKonumu,
      rota.koordinatlar,
      oncekiIlerlemeIndeks: oncekiIlerlemeIndeks,
    );
    final ilerlemeIndeks = ilerleme['indeks'] as int;
    final ilerlemeNokta = ilerleme['nokta'] as LatLng;

    // İlerleme noktasından hedefe kadar rota üzerindeki mesafe
    double kalanMesafe = 0.0;

    // İlerleme noktasından segment sonuna mesafe
    if (ilerlemeIndeks < rota.koordinatlar.length - 1) {
      kalanMesafe += Geolocator.distanceBetween(
        ilerlemeNokta.latitude,
        ilerlemeNokta.longitude,
        rota.koordinatlar[ilerlemeIndeks + 1].latitude,
        rota.koordinatlar[ilerlemeIndeks + 1].longitude,
      );
    }

    // Kalan segmentlerin mesafesi
    for (int i = ilerlemeIndeks + 1; i < rota.koordinatlar.length - 1; i++) {
      kalanMesafe += Geolocator.distanceBetween(
        rota.koordinatlar[i].latitude,
        rota.koordinatlar[i].longitude,
        rota.koordinatlar[i + 1].latitude,
        rota.koordinatlar[i + 1].longitude,
      );
    }

    return kalanMesafe;
  }

  /// Kalan süreyi hesaplar (ETA)
  static double kalanSureHesapla(
    double kalanMesafe, {
    double? hiz,
  }) {
    final kullanilacakHiz = hiz ?? varsayilanBisikletHiziMs;
    if (kullanilacakHiz <= 0) return 0.0;
    
    return kalanMesafe / kullanilacakHiz;
  }

  /// Varis zamanını hesaplar (ETA)
  static DateTime varisZamaniHesapla(double kalanSure) {
    return DateTime.now().add(Duration(seconds: kalanSure.round()));
  }

  /// Sonraki dönüş talimatını bulur (Google Maps benzeri mantık)
  /// - Geçilen dönüşleri atlar
  /// - Minimum mesafe eşiği kullanır
  /// - GPS sapmalarını filtreler
  static Map<String, dynamic>? sonrakiDonusBul(
    LatLng kullaniciKonumu,
    RotaVerisi rota, {
    int? oncekiIlerlemeIndeks,
    int? oncekiDonusIndeks,
  }) {
    if (rota.koordinatlar.length < 3) return null;

    // Gerçek ilerleme noktasını bul
    final ilerleme = rotaUzerindekiIlerlemeNoktasiBul(
      kullaniciKonumu,
      rota.koordinatlar,
      oncekiIlerlemeIndeks: oncekiIlerlemeIndeks,
    );
    final ilerlemeIndeks = ilerleme['indeks'] as int;
    final ilerlemeNokta = ilerleme['nokta'] as LatLng;

    // Geçilen dönüşleri atla: Önceki dönüş indeksinden önceki dönüşleri görmezden gel
    final minimumDonusIndeks = math.max(
      ilerlemeIndeks + 1,
      (oncekiDonusIndeks ?? -1) + 1,
    );

    // Hedefe çok yakınsak, düz devam et
    if (minimumDonusIndeks >= rota.koordinatlar.length - 2) {
      final kalanMesafe = _rotaUzerindeMesafeHesapla(
        ilerlemeNokta,
        rota.koordinatlar,
        ilerlemeIndeks,
        rota.koordinatlar.length - 1,
      );
      return {
        'talimat': 'Go straight',
        'mesafe': kalanMesafe,
        'indeks': rota.koordinatlar.length - 1,
      };
    }

    // Rota üzerinde önemli bir dönüş noktası ara
    for (int i = minimumDonusIndeks; i < rota.koordinatlar.length - 2; i++) {
      final p1 = rota.koordinatlar[i];
      final p2 = rota.koordinatlar[i + 1];
      final p3 = rota.koordinatlar[i + 2];

      // İki vektör arasındaki açıyı hesapla
      final aci = _vektorAcisiHesapla(p1, p2, p3);

      // Önemli bir dönüş mü?
      if (aci.abs() > donusAciEsigi) {
        // Dönüş mesafesini hesapla
        final donusMesafesi = _rotaUzerindeMesafeHesapla(
          ilerlemeNokta,
          rota.koordinatlar,
          ilerlemeIndeks,
          i + 1,
        );

        // Minimum mesafe eşiği kontrolü
        if (donusMesafesi < minimumDonusMesafesi) {
          // Çok yakın, bir sonraki dönüşe geç
          continue;
        }

        // Eğer dönüş çok yakındaysa (geçiş eşiği), "dönüşü geçtik" olarak işaretle
        if (donusMesafesi <= donusGecisMesafesi) {
          continue; // Bir sonraki dönüşe geç
        }

        String talimat;
        if (aci > 0) {
          talimat = 'Turn right';
        } else {
          talimat = 'Turn left';
        }

        return {
          'talimat': talimat,
          'mesafe': donusMesafesi,
          'indeks': i + 1,
        };
      }
    }

    // Dönüş bulunamadı, düz devam et
    final kalanMesafe = _rotaUzerindeMesafeHesapla(
      ilerlemeNokta,
      rota.koordinatlar,
      ilerlemeIndeks,
      rota.koordinatlar.length - 1,
    );
    return {
      'talimat': 'Go straight',
      'mesafe': kalanMesafe,
      'indeks': rota.koordinatlar.length - 1,
    };
  }

  /// İki vektör arasındaki açıyı hesaplar (derece)
  /// Pozitif = sağa dönüş, Negatif = sola dönüş
  static double _vektorAcisiHesapla(LatLng p1, LatLng p2, LatLng p3) {
    // Vektör 1: p1 -> p2 (bearing)
    final bearing1 = _bearingHesapla(p1, p2);
    
    // Vektör 2: p2 -> p3 (bearing)
    final bearing2 = _bearingHesapla(p2, p3);

    // Açı farkını hesapla
    double aciFarki = bearing2 - bearing1;

    // Açıyı -180 ile 180 arasına normalize et
    while (aciFarki > 180) aciFarki -= 360;
    while (aciFarki < -180) aciFarki += 360;

    return aciFarki;
  }

  /// İki nokta arasındaki bearing (yön) açısını hesaplar (derece)
  /// 0 = Kuzey, 90 = Doğu, 180 = Güney, 270 = Batı
  static double _bearingHesapla(LatLng p1, LatLng p2) {
    final lat1 = p1.latitude * math.pi / 180;
    final lat2 = p2.latitude * math.pi / 180;
    final dLon = (p2.longitude - p1.longitude) * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(y, x) * 180 / math.pi;

    return (bearing + 360) % 360;
  }

  /// Rota üzerinde iki nokta arasındaki mesafeyi hesaplar
  static double _rotaUzerindeMesafeHesapla(
    LatLng baslangic,
    List<LatLng> rotaKoordinatlari,
    int baslangicIndeks,
    int bitisIndeks,
  ) {
    double mesafe = 0.0;

    // Başlangıç noktasından ilk rota noktasına
    if (baslangicIndeks < rotaKoordinatlari.length - 1) {
      mesafe += Geolocator.distanceBetween(
        baslangic.latitude,
        baslangic.longitude,
        rotaKoordinatlari[baslangicIndeks + 1].latitude,
        rotaKoordinatlari[baslangicIndeks + 1].longitude,
      );
    }

    // Rota üzerindeki noktalar arası mesafe
    for (int i = baslangicIndeks + 1; i < bitisIndeks && i < rotaKoordinatlari.length - 1; i++) {
      mesafe += Geolocator.distanceBetween(
        rotaKoordinatlari[i].latitude,
        rotaKoordinatlari[i].longitude,
        rotaKoordinatlari[i + 1].latitude,
        rotaKoordinatlari[i + 1].longitude,
      );
    }

    return mesafe;
  }

  /// Navigasyon metriklerini hesaplar
  /// Google Maps benzeri ileri projeksiyon ve dönüş takibi kullanır
  static NavigasyonMetrikleri metrikleriHesapla(
    LatLng kullaniciKonumu,
    RotaVerisi rota, {
    double? hiz,
    int? oncekiIlerlemeIndeks,
    int? oncekiDonusIndeks,
  }) {
    final kalanMesafe = kalanMesafeHesapla(
      kullaniciKonumu,
      rota,
      oncekiIlerlemeIndeks: oncekiIlerlemeIndeks,
    );
    final kalanSure = kalanSureHesapla(kalanMesafe, hiz: hiz);
    final varisZamani = varisZamaniHesapla(kalanSure);
    const double varisEsigiMetre = 20.0;

    String? talimat;
    double? talimatMesafe;
    int? talimatIndeks;

    if (kalanMesafe <= varisEsigiMetre) {
      // Hedefe ulaşıldı
      talimat = 'Arrived';
      talimatMesafe = 0.0;
      talimatIndeks = rota.koordinatlar.isNotEmpty ? rota.koordinatlar.length - 1 : null;
    } else {
      final sonrakiDonus = sonrakiDonusBul(
        kullaniciKonumu,
        rota,
        oncekiIlerlemeIndeks: oncekiIlerlemeIndeks,
        oncekiDonusIndeks: oncekiDonusIndeks,
      );
      talimat = sonrakiDonus?['talimat'] as String?;
      talimatMesafe = sonrakiDonus?['mesafe'] as double?;
      talimatIndeks = sonrakiDonus?['indeks'] as int?;
    }

    return NavigasyonMetrikleri(
      kalanMesafe: kalanMesafe,
      kalanSure: kalanSure,
      varisZamani: varisZamani,
      sonrakiDonus: talimat,
      sonrakiDonusMesafesi: talimatMesafe,
      sonrakiDonusIndeksi: talimatIndeks,
    );
  }

  /// Mesafeyi formatlanmış string olarak döner
  static String mesafeFormatla(double mesafeMetre) {
    if (mesafeMetre < 1000) {
      return '${mesafeMetre.toStringAsFixed(0)} m';
    } else {
      return '${(mesafeMetre / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Süreyi formatlanmış string olarak döner (Türkçe)
  static String sureFormatla(double sureSaniye) {
    if (sureSaniye < 60) {
      return '${sureSaniye.toStringAsFixed(0)} sn';
    } else if (sureSaniye < 3600) {
      final dakika = (sureSaniye / 60).floor();
      return '$dakika dk';
    } else {
      final saat = (sureSaniye / 3600).floor();
      final dakika = ((sureSaniye % 3600) / 60).floor();
      return '$saat sa $dakika dk';
    }
  }

  /// Zamanı formatlanmış string olarak döner (HH:mm)
  static String zamanFormatla(DateTime zaman) {
    final saat = zaman.hour.toString().padLeft(2, '0');
    final dakika = zaman.minute.toString().padLeft(2, '0');
    return '$saat:$dakika';
  }

  /// En yakın kiralık istasyonu bulur
  static KiralikIstasyon? enYakinKiralikIstasyonBul(
    LatLng kullaniciKonumu,
    List<KiralikIstasyon> istasyonlar,
  ) {
    if (istasyonlar.isEmpty) return null;

    KiralikIstasyon? enYakin;
    double enKisaMesafe = double.infinity;

    for (final istasyon in istasyonlar) {
      final mesafe = Geolocator.distanceBetween(
        kullaniciKonumu.latitude,
        kullaniciKonumu.longitude,
        istasyon.konum.latitude,
        istasyon.konum.longitude,
      );

      if (mesafe < enKisaMesafe) {
        enKisaMesafe = mesafe;
        enYakin = istasyon;
      }
    }

    return enYakin;
  }

  /// En yakın park alanını bulur
  static ParkAlani? enYakinParkAlaniBul(
    LatLng kullaniciKonumu,
    List<ParkAlani> parkAlanlari,
  ) {
    if (parkAlanlari.isEmpty) return null;

    ParkAlani? enYakin;
    double enKisaMesafe = double.infinity;

    for (final parkAlani in parkAlanlari) {
      final mesafe = Geolocator.distanceBetween(
        kullaniciKonumu.latitude,
        kullaniciKonumu.longitude,
        parkAlani.konum.latitude,
        parkAlani.konum.longitude,
      );

      if (mesafe < enKisaMesafe) {
        enKisaMesafe = mesafe;
        enYakin = parkAlani;
      }
    }

    return enYakin;
  }

  /// En yakın tamir istasyonunu bulur
  static TamirIstasyonu? enYakinTamirIstasyonuBul(
    LatLng kullaniciKonumu,
    List<TamirIstasyonu> tamirIstasyonlari,
  ) {
    if (tamirIstasyonlari.isEmpty) return null;

    TamirIstasyonu? enYakin;
    double enKisaMesafe = double.infinity;

    for (final tamirIstasyonu in tamirIstasyonlari) {
      final mesafe = Geolocator.distanceBetween(
        kullaniciKonumu.latitude,
        kullaniciKonumu.longitude,
        tamirIstasyonu.konum.latitude,
        tamirIstasyonu.konum.longitude,
      );

      if (mesafe < enKisaMesafe) {
        enKisaMesafe = mesafe;
        enYakin = tamirIstasyonu;
      }
    }

    return enYakin;
  }
}
