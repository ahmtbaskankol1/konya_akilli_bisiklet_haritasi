import 'package:latlong2/latlong.dart';

/// Bisiklet tamir ve bakım istasyonu modeli
class TamirIstasyonu {
  final String baslik;
  final double enlem;
  final double boylam;

  const TamirIstasyonu({
    required this.baslik,
    required this.enlem,
    required this.boylam,
  });

  /// Koordinat bilgisini LatLng formatına dönüştürür
  /// LatLng(latitude, longitude) formatında
  /// CSV'deki "enlem" aslında boylam, "boylam" aslında enlem olabilir - ters çeviriyoruz
  LatLng get konum => LatLng(boylam, enlem);

  /// CSV satırından model oluşturur
  factory TamirIstasyonu.fromCsvRow(Map<String, dynamic> row) {
    return TamirIstasyonu(
      baslik: row['Başlık']?.toString().trim() ?? '',
      enlem: double.tryParse(row['Enlem']?.toString() ?? '') ?? 0.0,
      boylam: double.tryParse(row['Boylam']?.toString() ?? '') ?? 0.0,
    );
  }

  @override
  String toString() => 'TamirIstasyonu(baslik: $baslik, konum: $konum)';
}

