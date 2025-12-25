import 'package:latlong2/latlong.dart';

/// Rota verisi modeli
/// Rota koordinatları ve bilgilerini tutar
class RotaVerisi {
  final List<LatLng> koordinatlar;
  final double? mesafe; // metre
  final double? sure; // saniye
  final LatLng baslangic;
  final LatLng bitis;

  const RotaVerisi({
    required this.koordinatlar,
    this.mesafe,
    this.sure,
    required this.baslangic,
    required this.bitis,
  });

  /// Rota var mı kontrol eder
  bool get rotaVar => koordinatlar.isNotEmpty;

  /// Mesafeyi formatlanmış string olarak döner
  String get mesafeFormatted {
    if (mesafe == null) return 'Bilinmiyor';
    if (mesafe! < 1000) {
      return '${mesafe!.toStringAsFixed(0)} m';
    } else {
      return '${(mesafe! / 1000).toStringAsFixed(2)} km';
    }
  }

  /// Süreyi formatlanmış string olarak döner
  String get sureFormatted {
    if (sure == null) return 'Bilinmiyor';
    final sureSaniye = sure!;
    
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

