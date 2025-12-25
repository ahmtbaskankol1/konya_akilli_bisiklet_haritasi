import 'package:latlong2/latlong.dart';

/// Paylaşımlı kiralık bisiklet istasyonu modeli
class KiralikIstasyon {
  final int id;
  final String istasyonKodu;
  final double enlem;
  final double boylam;
  final String adres;
  final int peronAdet;

  const KiralikIstasyon({
    required this.id,
    required this.istasyonKodu,
    required this.enlem,
    required this.boylam,
    required this.adres,
    required this.peronAdet,
  });

  /// Koordinat bilgisini LatLng formatına dönüştürür
  /// LatLng(latitude, longitude) formatında
  /// CSV'deki "enlem" aslında boylam, "boylam" aslında enlem olabilir - ters çeviriyoruz
  LatLng get konum => LatLng(boylam, enlem);

  /// CSV satırından model oluşturur
  factory KiralikIstasyon.fromCsvRow(Map<String, dynamic> row) {
    // Sütun isimlerini esnek şekilde oku (büyük/küçük harf duyarsız)
    final rowLower = row.map((key, value) => MapEntry(key.toLowerCase(), value));
    
    // ID alanını bul
    final idStr = rowLower['_id']?.toString() ?? 
                  rowLower['id']?.toString() ?? 
                  '';
    
    // İstasyon kodu alanını bul
    final istasyonKoduStr = rowLower['istasyon_kodu']?.toString() ?? 
                           rowLower['istasyonkodu']?.toString() ??
                           rowLower['kod']?.toString() ??
                           '';
    
    // Enlem alanını bul (CSV'de "enlem" yazıyor ama aslında boylam olabilir)
    final enlemStr = rowLower['enlem']?.toString() ?? 
                    rowLower['latitude']?.toString() ??
                    rowLower['lat']?.toString() ??
                    '';
    
    // Boylam alanını bul (CSV'de "boylam" yazıyor ama aslında enlem olabilir)
    final boylamStr = rowLower['boylam']?.toString() ?? 
                     rowLower['longitude']?.toString() ??
                     rowLower['lon']?.toString() ??
                     rowLower['lng']?.toString() ??
                     '';
    
    // Adres alanını bul
    final adresStr = rowLower['adres']?.toString() ?? 
                    rowLower['address']?.toString() ??
                    '';
    
    // Peron adet alanını bul
    final peronAdetStr = rowLower['peron_adet']?.toString() ?? 
                        rowLower['peronadet']?.toString() ??
                        rowLower['peron']?.toString() ??
                        '';
    
    // Koordinatları parse et - virgül veya nokta ayırıcı destekle
    double? enlem = _parseKoordinat(enlemStr);
    double? boylam = _parseKoordinat(boylamStr);
    
    // Eğer koordinatlar parse edilemediyse, 0.0 kullan
    enlem ??= 0.0;
    boylam ??= 0.0;
    
    return KiralikIstasyon(
      id: int.tryParse(idStr) ?? 0,
      istasyonKodu: istasyonKoduStr.trim(),
      enlem: enlem,
      boylam: boylam,
      adres: adresStr.trim(),
      peronAdet: int.tryParse(peronAdetStr) ?? 0,
    );
  }
  
  /// Koordinat string'ini double'a çevirir (virgül veya nokta ayırıcı destekler)
  static double? _parseKoordinat(String? str) {
    if (str == null || str.isEmpty) return null;
    
    // Boşlukları temizle
    str = str.trim();
    
    // Virgülü noktaya çevir (Türkçe format: 32,470592 -> 32.470592)
    str = str.replaceAll(',', '.');
    
    // Birden fazla nokta varsa, sadece ilkini tut
    final noktaIndex = str.indexOf('.');
    if (noktaIndex != -1) {
      final ilkKisim = str.substring(0, noktaIndex + 1);
      final sonKisim = str.substring(noktaIndex + 1).replaceAll('.', '');
      str = ilkKisim + sonKisim;
    }
    
    return double.tryParse(str);
  }

  @override
  String toString() => 
      'KiralikIstasyon(kod: $istasyonKodu, adres: $adres, konum: $konum)';
}

