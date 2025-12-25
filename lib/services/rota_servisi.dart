import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Rota hesaplama servisi
/// OSRM (Open Source Routing Machine) API kullanarak rota hesaplar
/// 
/// NOT: OSRM ücretsiz ve açık kaynak bir servistir, API anahtarı gerektirmez.
/// Alternatif olarak OpenRouteService de kullanılabilir (API anahtarı gerekir).
class RotaServisi {
  // OSRM public server URL'i
  // TODO: İleride kendi OSRM sunucunuzu kurabilirsiniz
  static const String osrmBaseUrl = 'https://router.project-osrm.org';
  
  // Alternatif: OpenRouteService (API anahtarı gerekir)
  // static const String orsBaseUrl = 'https://api.openrouteservice.org/v2';
  // static const String orsApiKey = 'YOUR_API_KEY_HERE'; // TODO: API anahtarını buraya ekleyin

  /// İki nokta arasında rota hesaplar
  /// 
  /// [baslangic] Başlangıç koordinatı
  /// [bitis] Bitiş koordinatı
  /// [profil] Rota profili: 'driving', 'walking', 'cycling' (varsayılan: 'driving')
  /// 
  /// Dönen değer: Rota koordinatları listesi (LatLng)
  static Future<List<LatLng>?> rotaHesapla({
    required LatLng baslangic,
    required LatLng bitis,
    String profil = 'driving', // 'driving', 'walking', 'cycling'
  }) async {
    try {
      // OSRM API endpoint'i
      // Format: /route/v1/{profile}/{coordinates}?overview=full&geometries=geojson
      final String url = '$osrmBaseUrl/route/v1/$profil/'
          '${baslangic.longitude},${baslangic.latitude};'
          '${bitis.longitude},${bitis.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> veri = json.decode(response.body);
        
        // Rota bulundu mu kontrol et
        if (veri['code'] == 'Ok' && veri['routes'] != null && veri['routes'].isNotEmpty) {
          final rota = veri['routes'][0];
          final geometri = rota['geometry'];
          
          // GeoJSON formatındaki koordinatları parse et
          if (geometri['type'] == 'LineString' && geometri['coordinates'] != null) {
            final List<dynamic> koordinatlar = geometri['coordinates'];
            
            // GeoJSON formatı: [longitude, latitude]
            // LatLng formatı: (latitude, longitude)
            final List<LatLng> rotaNoktalari = koordinatlar.map((koordinat) {
              return LatLng(
                koordinat[1].toDouble(), // latitude
                koordinat[0].toDouble(), // longitude
              );
            }).toList();
            
            return rotaNoktalari;
          }
        } else {
          print('Rota bulunamadı: ${veri['code']}');
          return null;
        }
      } else {
        print('Rota hesaplama hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Rota hesaplama servisi hatası: $e');
      return null;
    }
  }

  /// Rota mesafesini ve süresini hesaplar
  /// 
  /// [baslangic] Başlangıç koordinatı
  /// [bitis] Bitiş koordinatı
  /// [profil] Rota profili
  /// 
  /// Dönen değer: Map içinde 'mesafe' (metre) ve 'sure' (saniye) bilgileri
  static Future<Map<String, double>?> rotaBilgileriAl({
    required LatLng baslangic,
    required LatLng bitis,
    String profil = 'driving',
  }) async {
    try {
      final String url = '$osrmBaseUrl/route/v1/$profil/'
          '${baslangic.longitude},${baslangic.latitude};'
          '${bitis.longitude},${bitis.latitude}'
          '?overview=false';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> veri = json.decode(response.body);
        
        if (veri['code'] == 'Ok' && veri['routes'] != null && veri['routes'].isNotEmpty) {
          final rota = veri['routes'][0];
          
          return {
            'mesafe': (rota['distance'] as num).toDouble(), // metre
            'sure': (rota['duration'] as num).toDouble(), // saniye
          };
        }
      }
      
      return null;
    } catch (e) {
      print('Rota bilgileri alınırken hata: $e');
      return null;
    }
  }

  /// Mesafeyi formatlanmış string olarak döner
  static String mesafeFormatla(double mesafeMetre) {
    if (mesafeMetre < 1000) {
      return '${mesafeMetre.toStringAsFixed(0)} m';
    } else {
      return '${(mesafeMetre / 1000).toStringAsFixed(2)} km';
    }
  }

  /// Süreyi formatlanmış string olarak döner
  static String sureFormatla(double sureSaniye) {
    if (sureSaniye < 60) {
      return '${sureSaniye.toStringAsFixed(0)} sn';
    } else if (sureSaniye < 3600) {
      final dakika = (sureSaniye / 60).floor();
      final saniye = (sureSaniye % 60).floor();
      return '$dakika dk ${saniye}sn';
    } else {
      final saat = (sureSaniye / 3600).floor();
      final dakika = ((sureSaniye % 3600) / 60).floor();
      return '$saat sa $dakika dk';
    }
  }
}

