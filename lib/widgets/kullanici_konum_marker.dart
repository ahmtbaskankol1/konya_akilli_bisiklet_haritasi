import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Kullanıcı konumu marker'ı
/// Mavi nokta ile kullanıcı konumunu gösterir
class KullaniciKonumMarker extends Marker {
  KullaniciKonumMarker({
    required LatLng konum,
  }) : super(
          point: konum,
          width: 30,
          height: 30,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.amber.shade800,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.shade800.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.my_location,
              color: Colors.white,
              size: 16,
            ),
          ),
        );
}

