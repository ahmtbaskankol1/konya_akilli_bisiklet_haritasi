import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/konum_servisi.dart';

/// Kullanıcı konumu provider'ı
final kullaniciKonumuProvider = FutureProvider<LatLng?>(
  (ref) async {
    return await KonumServisi.mevcutKonumuAl();
  },
);

/// Konum izni durumu provider'ı
final konumIzniProvider = FutureProvider<bool>(
  (ref) async {
    return await KonumServisi.konumIzniniKontrolEt();
  },
);

/// Konum güncellemeleri stream provider'ı
/// Sürekli olarak konum güncellemelerini dinler
final konumGuncellemeleriProvider = StreamProvider<LatLng?>(
  (ref) {
    return KonumServisi.konumGuncellemeleriniDinle();
  },
);

