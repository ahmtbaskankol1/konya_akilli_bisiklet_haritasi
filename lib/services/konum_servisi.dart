import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Kullanıcı konum servisi
/// Geolocator kullanarak kullanıcı konumunu alır ve yönetir
class KonumServisi {
  /// Konum izinlerini kontrol eder ve gerekirse ister
  static Future<bool> konumIzniniKontrolEt() async {
    // Önce servislerin açık olup olmadığını kontrol et
    bool servisAktif = await Geolocator.isLocationServiceEnabled();
    if (!servisAktif) {
      // Servisler kapalıysa kullanıcıyı ayarlara yönlendir
      return false;
    }

    // İzin durumunu kontrol et
    LocationPermission izin = await Geolocator.checkPermission();
    
    if (izin == LocationPermission.denied) {
      // İzin verilmemişse iste
      izin = await Geolocator.requestPermission();
      if (izin == LocationPermission.denied) {
        return false;
      }
    }

    if (izin == LocationPermission.deniedForever) {
      // İzin kalıcı olarak reddedilmişse ayarlara yönlendir
      return false;
    }

    // İzin verilmiş
    return true;
  }

  /// Mevcut konumu alır
  /// İzin yoksa null döner
  static Future<LatLng?> mevcutKonumuAl() async {
    try {
      // Önce izin kontrolü yap
      bool izinVar = await konumIzniniKontrolEt();
      if (!izinVar) {
        return null;
      }

      // Konumu al
      Position konum = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LatLng(konum.latitude, konum.longitude);
    } catch (e) {
      print('Konum alınırken hata: $e');
      return null;
    }
  }

  /// Konum güncellemelerini dinler
  /// Stream olarak sürekli konum bilgisi döner
  static Stream<LatLng?> konumGuncellemeleriniDinle() async* {
    try {
      // Önce izin kontrolü yap
      bool izinVar = await konumIzniniKontrolEt();
      if (!izinVar) {
        yield null;
        return;
      }

      // Konum güncellemelerini dinle
      await for (Position konum in Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // 10 metre değişiklikte güncelle
        ),
      )) {
        yield LatLng(konum.latitude, konum.longitude);
      }
    } catch (e) {
      print('Konum dinlenirken hata: $e');
      yield null;
    }
  }

  /// İki konum arasındaki mesafeyi metre cinsinden hesaplar
  static double mesafeHesapla(LatLng konum1, LatLng konum2) {
    return Geolocator.distanceBetween(
      konum1.latitude,
      konum1.longitude,
      konum2.latitude,
      konum2.longitude,
    );
  }

  /// İki konum arasındaki mesafeyi kilometre cinsinden formatlanmış string olarak döner
  static String mesafeFormatla(LatLng konum1, LatLng konum2) {
    double mesafeMetre = mesafeHesapla(konum1, konum2);
    
    if (mesafeMetre < 1000) {
      return '${mesafeMetre.toStringAsFixed(0)} m';
    } else {
      return '${(mesafeMetre / 1000).toStringAsFixed(2)} km';
    }
  }
}

