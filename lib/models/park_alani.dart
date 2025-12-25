import 'package:latlong2/latlong.dart';

/// Bisiklet park alanı modeli
class ParkAlani {
  final int id;
  final String isim;
  final double enlem;
  final double boylam;

  const ParkAlani({
    required this.id,
    required this.isim,
    required this.enlem,
    required this.boylam,
  });

  /// Koordinat bilgisini LatLng formatına dönüştürür
  /// LatLng(latitude, longitude) formatında
  /// CSV'deki "enlem" aslında boylam, "boylam" aslında enlem olabilir - ters çeviriyoruz
  LatLng get konum => LatLng(boylam, enlem);

  /// CSV satırından model oluşturur
  factory ParkAlani.fromCsvRow(Map<String, dynamic> row) {
    // Sütun isimlerini esnek şekilde oku (büyük/küçük harf duyarsız)
    final rowLower = row.map((key, value) => MapEntry(key.toLowerCase(), value));
    
    // ID alanını bul
    final idStr = rowLower['_id']?.toString() ?? 
                  rowLower['id']?.toString() ?? 
                  '';
    
    // İsim alanını bul
    final isimStr = rowLower['park_alani_isimleri']?.toString() ?? 
                   rowLower['parkalanisimleri']?.toString() ??
                   rowLower['isim']?.toString() ??
                   rowLower['name']?.toString() ??
                   rowLower['baslik']?.toString() ??
                   '';
    
    // Enlem alanını bul (CSV'de "enlem" yazıyor ama aslında boylam/longitude olabilir)
    final enlemStr = rowLower['enlem']?.toString() ?? 
                    rowLower['latitude']?.toString() ??
                    rowLower['lat']?.toString() ??
                    '';
    
    // Boylam alanını bul (CSV'de "boylam" yazıyor ama aslında enlem/latitude olabilir)
    final boylamStr = rowLower['boylam']?.toString() ?? 
                     rowLower['longitude']?.toString() ??
                     rowLower['lon']?.toString() ??
                     rowLower['lng']?.toString() ??
                     '';
    
    // Koordinatları parse et - Türkçe format (virgül) veya İngilizce format (nokta) destekle
    // Önce virgülü noktaya çevir, sonra parse et
    String enlemCleaned = enlemStr.trim().replaceAll(',', '.');
    String boylamCleaned = boylamStr.trim().replaceAll(',', '.');
    
    double enlem = double.tryParse(enlemCleaned) ?? 0.0;
    double boylam = double.tryParse(boylamCleaned) ?? 0.0;
    
    return ParkAlani(
      id: int.tryParse(idStr) ?? 0,
      isim: isimStr.trim(),
      enlem: enlem,
      boylam: boylam,
    );
  }

  @override
  String toString() => 'ParkAlani(id: $id, isim: $isim, konum: $konum)';
}

