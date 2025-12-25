import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// İstasyon marker widget'ı
/// Farklı renklerde marker gösterir
class IstasyonMarker extends Marker {
  IstasyonMarker({
    required LatLng konum,
    required Color renk,
    required String baslik,
    required VoidCallback onTap,
  }) : super(
          point: konum,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: renk,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.location_on,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        );
}

/// Kiralık istasyon marker'ı (Mavi)
class KiralikIstasyonMarker extends IstasyonMarker {
  KiralikIstasyonMarker({
    required LatLng konum,
    required String baslik,
    required VoidCallback onTap,
  }) : super(
          konum: konum,
          renk: const Color(0xFF2196F3), // Mavi
          baslik: baslik,
          onTap: onTap,
        );
}

/// Park alanı marker'ı (Yeşil)
class ParkAlaniMarker extends IstasyonMarker {
  ParkAlaniMarker({
    required LatLng konum,
    required String baslik,
    required VoidCallback onTap,
  }) : super(
          konum: konum,
          renk: const Color(0xFF4CAF50), // Yeşil
          baslik: baslik,
          onTap: onTap,
        );
}

/// Tamir istasyonu marker'ı (Turuncu)
class TamirIstasyonuMarker extends IstasyonMarker {
  TamirIstasyonuMarker({
    required LatLng konum,
    required String baslik,
    required VoidCallback onTap,
  }) : super(
          konum: konum,
          renk: const Color(0xFFFF9800), // Turuncu
          baslik: baslik,
          onTap: onTap,
        );
}

