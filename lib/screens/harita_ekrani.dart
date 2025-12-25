import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../providers/istasyon_provider.dart';
import '../providers/konum_provider.dart';
import '../providers/rota_provider.dart';
import '../models/rota_verisi.dart';
import '../models/kiralik_istasyon.dart';
import '../models/park_alani.dart';
import '../models/tamir_istasyonu.dart';
import '../widgets/filtre_butonlari.dart';
import '../widgets/istasyon_marker.dart';
import '../widgets/istasyon_detay_sheet.dart';
import '../widgets/kullanici_konum_marker.dart';
import '../widgets/navigation_panel.dart';
import '../widgets/arama_cubugu.dart';
import '../services/konum_servisi.dart';
import '../services/navigation_service.dart';
import 'package:konya_akilli_bisiklet_haritasi/providers/navigation_provider.dart';
import '../providers/search_provider.dart';
import '../services/station_search_service.dart';

/// Harita ekranı - OpenStreetMap tabanlı harita görünümü
/// Konya şehir merkezine odaklanmış harita gösterimi
class HaritaEkrani extends ConsumerStatefulWidget {
  const HaritaEkrani({super.key});

  @override
  ConsumerState<HaritaEkrani> createState() => _HaritaEkraniState();
}

class _HaritaEkraniState extends ConsumerState<HaritaEkrani> {
  // Konya şehir merkezi koordinatları
  // Enlem (Latitude): 37.8746, Boylam (Longitude): 32.4932
  static const LatLng konyaMerkez = LatLng(37.8746, 32.4932);
  
  // Harita kontrolcüsü
  final MapController _haritaKontrolcusu = MapController();
  
  // Scaffold key - Drawer'ı açmak için
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Başlangıç zoom seviyesi
  static const double baslangicZoom = 12.0;
  
  // Önceki rota (değişiklik kontrolü için)
  RotaVerisi? _oncekiRota;

  /// Haritayı rotaya fit eder
  void _haritayiRotayaFitEt(RotaVerisi rota) {
    if (rota.koordinatlar.isEmpty) return;

    // Tüm rota noktalarını içeren bounds hesapla
    double minLat = rota.koordinatlar.first.latitude;
    double maxLat = rota.koordinatlar.first.latitude;
    double minLon = rota.koordinatlar.first.longitude;
    double maxLon = rota.koordinatlar.first.longitude;

    for (final nokta in rota.koordinatlar) {
      if (nokta.latitude < minLat) minLat = nokta.latitude;
      if (nokta.latitude > maxLat) maxLat = nokta.latitude;
      if (nokta.longitude < minLon) minLon = nokta.longitude;
      if (nokta.longitude > maxLon) maxLon = nokta.longitude;
    }

    // Başlangıç ve bitiş noktalarını da ekle
    if (rota.baslangic.latitude < minLat) minLat = rota.baslangic.latitude;
    if (rota.baslangic.latitude > maxLat) maxLat = rota.baslangic.latitude;
    if (rota.baslangic.longitude < minLon) minLon = rota.baslangic.longitude;
    if (rota.baslangic.longitude > maxLon) maxLon = rota.baslangic.longitude;

    if (rota.bitis.latitude < minLat) minLat = rota.bitis.latitude;
    if (rota.bitis.latitude > maxLat) maxLat = rota.bitis.latitude;
    if (rota.bitis.longitude < minLon) minLon = rota.bitis.longitude;
    if (rota.bitis.longitude > maxLon) maxLon = rota.bitis.longitude;

    // Padding ekle (margin)
    final latFark = maxLat - minLat;
    final lonFark = maxLon - minLon;
    final padding = 0.1; // %10 padding

    minLat -= latFark * padding;
    maxLat += latFark * padding;
    minLon -= lonFark * padding;
    maxLon += lonFark * padding;

    // Merkez noktasını hesapla
    final merkez = LatLng(
      (minLat + maxLat) / 2,
      (minLon + maxLon) / 2,
    );

    // Zoom seviyesini hesapla (basit bir yaklaşım)
    final enBuyukFark = latFark > lonFark ? latFark : lonFark;
    double zoom = 15.0;
    if (enBuyukFark > 0.1) zoom = 12.0;
    if (enBuyukFark > 0.05) zoom = 13.0;
    if (enBuyukFark > 0.02) zoom = 14.0;
    if (enBuyukFark > 0.01) zoom = 15.0;
    if (enBuyukFark < 0.005) zoom = 16.0;
    if (enBuyukFark < 0.002) zoom = 17.0;

    // Haritayı güncelle
    _haritaKontrolcusu.move(merkez, zoom);
  }
  
  /// Haritayı yakınlaştırır (ekranda görünen merkeze göre)
  void _zoomIn() {
    // Ekranda görünen haritanın merkez noktasını al
    final mevcutCamera = _haritaKontrolcusu.camera;
    final mevcutMerkez = mevcutCamera.center;
    final mevcutZoom = mevcutCamera.zoom;
    
    // Daha hassas zoom adımı (0.5)
    final yeniZoom = (mevcutZoom + 0.5).clamp(5.0, 18.0);
    _haritaKontrolcusu.move(mevcutMerkez, yeniZoom);
  }
  
  /// Haritayı uzaklaştırır (ekranda görünen merkeze göre)
  void _zoomOut() {
    // Ekranda görünen haritanın merkez noktasını al
    final mevcutCamera = _haritaKontrolcusu.camera;
    final mevcutMerkez = mevcutCamera.center;
    final mevcutZoom = mevcutCamera.zoom;
    
    // Daha hassas zoom adımı (0.5)
    final yeniZoom = (mevcutZoom - 0.5).clamp(5.0, 18.0);
    _haritaKontrolcusu.move(mevcutMerkez, yeniZoom);
  }

  @override
  Widget build(BuildContext context) {
    final filtrelenmisIstasyonlar = ref.watch(filtrelenmisIstasyonlarProvider);
    final kullaniciKonumu = ref.watch(konumGuncellemeleriProvider);
    final aktifRota = ref.watch(aktifRotaProvider);
    
    // Debug: Log when aktifRota changes
    if (aktifRota != null && aktifRota.koordinatlar.isNotEmpty) {
      print('aktifRota in build: ${aktifRota.koordinatlar.length} points');
    }
    
    // SAFE: Listen to off-route distance and trigger reroute as side effect
    // This replaces the unsafe Provider<void> that was doing side effects during build
    ref.listen<double?>(offRouteDistanceProvider, (previous, next) {
      // Only trigger reroute if distance is available and exceeds threshold
      if (next == null) {
        return;
      }
      
      const double offRouteEsigi = 30.0; // metre
      
      // Kullanıcı rotaya geri döndüğünde cooldown'u sıfırla
      // Bu sayede kullanıcı tekrar rotadan çıktığında yeni reroute tetiklenebilir
      if (previous != null && previous > offRouteEsigi && next <= offRouteEsigi) {
        // Kullanıcı off-route'tan on-route'a döndü, cooldown'u sıfırla
        ref.read(sonRerouteZamaniProvider.notifier).state = null;
        print('Route active again (distance=${next.toStringAsFixed(1)}m), cooldown reset - ready for next reroute');
        return;
      }
      
      if (next > offRouteEsigi) {
        // Check if reroute is already in progress
        final rerouteInProgress = ref.read(rerouteInProgressProvider);
        if (rerouteInProgress) {
          return; // Already rerouting, skip
        }
        
        // Check cooldown
        final sonRerouteZamani = ref.read(sonRerouteZamaniProvider);
        final simdi = DateTime.now();
        
        if (sonRerouteZamani != null && 
            simdi.difference(sonRerouteZamani).inSeconds < 15) {
          final kalanSure = 15 - simdi.difference(sonRerouteZamani).inSeconds;
          print('Reroute skipped (cooldown active): ${kalanSure} saniye kaldı');
          return;
        }
        
        // Get current route and location
        final currentRota = ref.read(aktifRotaProvider);
        final kullaniciKonumuAsync = ref.read(konumGuncellemeleriProvider);
        
        if (currentRota == null || currentRota.koordinatlar.isEmpty) {
          return;
        }
        
        kullaniciKonumuAsync.whenData((kullaniciKonumu) async {
          if (kullaniciKonumu == null) {
            return;
          }
          
          // Set reroute in progress flag
          ref.read(rerouteInProgressProvider.notifier).state = true;
          
          // Set reroute started flag (for SnackBar)
          ref.read(rerouteBasladiProvider.notifier).state = true;
          
          // Update cooldown
          ref.read(sonRerouteZamaniProvider.notifier).state = simdi;
          
          // Log
          print('OFF-ROUTE detected distance=${next.toStringAsFixed(1)}m -> reroute starting');
          print('OFF-ROUTE detected, rerouting from (${kullaniciKonumu.latitude.toStringAsFixed(6)},${kullaniciKonumu.longitude.toStringAsFixed(6)}) to (${currentRota.bitis.latitude.toStringAsFixed(6)},${currentRota.bitis.longitude.toStringAsFixed(6)})');
          
          // Trigger reroute
          await otomatikRerouteYap(ref, kullaniciKonumu, currentRota);
          
          // Reroute completed, reset flag
          ref.read(rerouteBasladiProvider.notifier).state = false;
        });
      }
    });
    
    // Reroute mesajını izle ve SnackBar göster
    final rerouteBasladi = ref.watch(rerouteBasladiProvider);
    if (rerouteBasladi && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rotadan çıktınız, rota yeniden hesaplanıyor...'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }
    
    // Rota değişikliklerini dinle ve haritayı güncelle
    ref.listen<RotaVerisi?>(aktifRotaProvider, (previous, next) {
      // Debug: Log route state changes
      if (next == null) {
        print('aktifRota changed: null (route cleared)');
        _oncekiRota = null;
        return;
      }
      
      if (next.koordinatlar.isNotEmpty) {
        print('aktifRota changed: ${next.koordinatlar.length} points (route updated)');
        
        // Her zaman güncelle (reroute durumunda da çalışması için)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _haritayiRotayaFitEt(next);
          }
        });
        _oncekiRota = next;
      } else {
        print('aktifRota changed: empty coordinates');
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/konya_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox.shrink();
            },
          ),
        ),
        leadingWidth: 80,
        title: const Text(
          'Konya Akıllı Bisiklet Haritası',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      drawer: _NavigasyonDrawer(
        haritaKontrolcusu: _haritaKontrolcusu,
        onRotaOlustur: _rotaOlustur,
      ),
      body: Stack(
        children: [
          // Harita
          FlutterMap(
            mapController: _haritaKontrolcusu,
            options: MapOptions(
              initialCenter: konyaMerkez,
              initialZoom: baslangicZoom,
              minZoom: 5.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onMapEvent: (MapEvent event) {
                // Harita hareket ettiğinde event'leri dinle (gerekirse işlem yapılabilir)
              },
            ),
            children: [
              // OpenStreetMap tile layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.konya.akilli.bisiklet',
                maxZoom: 19,
              ),
              // Marker'lar
              filtrelenmisIstasyonlar.when(
                data: (data) => MarkerLayer(
                  markers: _markerOlustur(data),
                ),
                loading: () => const MarkerLayer(markers: []),
                error: (error, stack) => const MarkerLayer(markers: []),
              ),
              // Kullanıcı konumu marker'ı
              kullaniciKonumu.when(
                data: (konum) {
                  if (konum == null) return const MarkerLayer(markers: []);
                  return MarkerLayer(
                    markers: [
                      KullaniciKonumMarker(konum: konum),
                    ],
                  );
                },
                loading: () => const MarkerLayer(markers: []),
                error: (error, stack) => const MarkerLayer(markers: []),
              ),
              // Rota polyline layer
              // Use rotaVersiyonuProvider to force rebuild when route changes (including reroute)
              Builder(
                builder: (context) {
                  final aktifRota = ref.watch(aktifRotaProvider);
                  final routeVersion = ref.watch(rotaVersiyonuProvider);
                  
                  // Only show polyline if route exists and has coordinates
                  if (aktifRota == null || aktifRota.koordinatlar.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  
                  // Debug: Log when drawing polyline
                  print('Drawing polyline: version=$routeVersion, points=${aktifRota.koordinatlar.length}, first=(${aktifRota.koordinatlar.first.latitude.toStringAsFixed(6)},${aktifRota.koordinatlar.first.longitude.toStringAsFixed(6)}), last=(${aktifRota.koordinatlar.last.latitude.toStringAsFixed(6)},${aktifRota.koordinatlar.last.longitude.toStringAsFixed(6)})');
                  
                  // Key based on routeVersion to force rebuild when route changes
                  // This ensures the polyline updates on reroute
                  // CRITICAL: Use List.from() to ensure fresh list reference for FlutterMap
                  final polylinePoints = List<LatLng>.from(aktifRota.koordinatlar);
                  
                  return PolylineLayer(
                    key: ValueKey('route-$routeVersion'),
                    polylines: [
                      Polyline(
                        points: polylinePoints,
                        strokeWidth: 4.0,
                        color: Colors.blue,
                        borderStrokeWidth: 2.0,
                        borderColor: Colors.white,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          // Üst panel: Arama çubuğu + sonuçlar + filtre butonları
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _UstPanel(
                haritaKontrolcusu: _haritaKontrolcusu,
                onIstasyonSecildi: (istasyon) => _aramaSonucuSecildi(istasyon),
                onMenuPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ),
          ),
          // Navigasyon paneli (aktif rota varsa - en altta, SafeArea ile)
          if (aktifRota != null && aktifRota.koordinatlar.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: const NavigationPanel(),
            ),
          // Zoom butonları (sağ tarafta, navigasyon panelinin üstünde veya konum butonunun üstünde)
          Positioned(
            bottom: (aktifRota != null && aktifRota.koordinatlar.isNotEmpty) ? 200 : 100,
            right: 20,
            child: _ZoomButonlari(
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
            ),
          ),
          // Konum butonu (sağ altta, navigasyon panelinin üstünde veya normal konumda)
          Positioned(
            bottom: (aktifRota != null && aktifRota.koordinatlar.isNotEmpty) ? 140 : 20,
            right: 20,
            child: _KonumButonu(
              haritaKontrolcusu: _haritaKontrolcusu,
            ),
          ),
        ],
      ),
    );
  }

  /// Filtrelenmiş istasyonlardan marker'lar oluşturur
  List<Marker> _markerOlustur(FiltrelenmisIstasyonlar data) {
    final List<Marker> markerlar = [];

    // Kiralık istasyonlar (Mavi)
    for (final istasyon in data.kiralik) {
      markerlar.add(
        KiralikIstasyonMarker(
          konum: istasyon.konum,
          baslik: istasyon.adres,
          onTap: () => _istasyonDetayGoster(istasyon),
        ),
      );
    }

    // Park alanları (Yeşil)
    for (final parkAlani in data.park) {
      markerlar.add(
        ParkAlaniMarker(
          konum: parkAlani.konum,
          baslik: parkAlani.isim,
          onTap: () => _istasyonDetayGoster(parkAlani),
        ),
      );
    }

    // Tamir istasyonları (Turuncu)
    for (final tamirIstasyonu in data.tamir) {
      markerlar.add(
        TamirIstasyonuMarker(
          konum: tamirIstasyonu.konum,
          baslik: tamirIstasyonu.baslik,
          onTap: () => _istasyonDetayGoster(tamirIstasyonu),
        ),
      );
    }

    return markerlar;
  }

  /// İstasyon detay bottom sheet'ini gösterir
  void _istasyonDetayGoster(dynamic istasyon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => IstasyonDetaySheet(istasyon: istasyon),
    );
  }

  /// Merkezi rota oluşturma fonksiyonu
  /// Tüm rota oluşturma işlemleri bu fonksiyonu kullanır (marker, drawer, search)
  /// Bu fonksiyon her zaman state'i temizler ve hata durumunda bile state'i reset eder
  Future<void> _rotaOlustur(
    LatLng hedefKonum, {
    String? basariliMesaj,
  }) async {
    try {
      // Klavyeyi kapat (rota oluşturma başlamadan önce)
      _klavyeyiKapat();
      
      // Manuel rota oluşturma başladı - otomatik reroute'u devre dışı bırak
      // Bu, reroute'un manuel rota oluşturma sırasında çalışmasını önler
      ref.read(manuelRotaOlusturmaDevamEdiyorProvider.notifier).state = true;
      
      // Reset cancellation timestamp (new route creation)
      ref.read(rotaIptalEdildiAtProvider.notifier).state = null;
      
      // Önce mevcut rotayı temizle - her zaman temizle
      ref.read(aktifRotaProvider.notifier).state = null;
      ref.read(voiceGuidanceStateProvider.notifier).state = null;
      // Navigasyon indekslerini sıfırla
      ref.read(navigasyonIlerlemeIndeksProvider.notifier).state = null;
      ref.read(navigasyonSonDonusIndeksProvider.notifier).state = null;

      // Kullanıcı konumunu al
      final kullaniciKonumu = await KonumServisi.mevcutKonumuAl();

      if (kullaniciKonumu == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Konum alınamadı. Lütfen konum izinlerini kontrol edin.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Debug: Log route start
      print('ROUTE START requested: from=${kullaniciKonumu.latitude},${kullaniciKonumu.longitude} to=${hedefKonum.latitude},${hedefKonum.longitude}');

      // Rota parametrelerini oluştur
      final parametreler = RotaParametreleri(
        baslangic: kullaniciKonumu,
        bitis: hedefKonum,
        profil: 'cycling',
      );

      // Debug: Log route calculation start
      print('ROUTE CALC started');

      // Provider cache'ini refresh et - bu önceki cache'i temizler ve yeni hesaplama yapar
      ref.refresh(rotaHesaplamaProvider(parametreler));
      
      // Yeni rota hesapla
      final rotaAsync = await ref.read(rotaHesaplamaProvider(parametreler).future);

      // Debug: Log route calculation result
      if (rotaAsync != null) {
        print('ROUTE CALC result: points=${rotaAsync.koordinatlar.length}, distance=${rotaAsync.mesafeFormatted}, duration=${rotaAsync.sureFormatted}');
      } else {
        print('ROUTE CALC result: null (route calculation failed)');
      }

      if (mounted) {
        if (rotaAsync != null) {
          // CRITICAL: Create IMMUTABLE route state with fresh list reference
          // This ensures FlutterMap detects the change and rebuilds the polyline
          final newPoints = List<LatLng>.from(rotaAsync.koordinatlar);
          final immutableRota = RotaVerisi(
            koordinatlar: newPoints,
            mesafe: rotaAsync.mesafe,
            sure: rotaAsync.sure,
            baslangic: rotaAsync.baslangic,
            bitis: rotaAsync.bitis,
          );
          
          // Rota versiyonunu artır (polyline rebuild için)
          ref.read(rotaVersiyonuProvider.notifier).state++;
          
          // Aktif rotayı güncelle
          print('Setting aktifRotaProvider: ${immutableRota.koordinatlar.length} points');
          ref.read(aktifRotaProvider.notifier).state = immutableRota;

          // Klavyeyi kapat (rota başarıyla oluşturulduktan sonra)
          _klavyeyiKapat();

          // Haritayı rotaya fit et
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _haritayiRotayaFitEt(rotaAsync);
              // Bir kez daha klavyeyi kapat (UI rebuild sonrası)
              _klavyeyiKapat();
            }
          });

          // Başarı mesajı
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                basariliMesaj ?? 
                'Rota oluşturuldu: ${rotaAsync.mesafeFormatted} (${rotaAsync.sureFormatted})',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // Rota hesaplanamadı - state zaten temiz
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rota hesaplanamadı.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      
      // Manuel rota oluşturma tamamlandı - otomatik reroute'u tekrar etkinleştir
      ref.read(manuelRotaOlusturmaDevamEdiyorProvider.notifier).state = false;
    } catch (e) {
      // Hata durumunda state'i temizle
      ref.read(aktifRotaProvider.notifier).state = null;
      ref.read(voiceGuidanceStateProvider.notifier).state = null;
      // Navigasyon indekslerini sıfırla
      ref.read(navigasyonIlerlemeIndeksProvider.notifier).state = null;
      ref.read(navigasyonSonDonusIndeksProvider.notifier).state = null;
      
      // Manuel rota oluşturma tamamlandı (hata olsa bile) - otomatik reroute'u tekrar etkinleştir
      ref.read(manuelRotaOlusturmaDevamEdiyorProvider.notifier).state = false;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rota oluşturulurken hata: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Arama sonucu seçildiğinde çağrılır
  /// İstasyon detayını gösterir - kullanıcı "Rota oluştur" butonuna basarsa rota oluşturulur
  /// (Çift onay yok - sadece detay sheet'teki "Rota oluştur" butonu yeterli)
  Future<void> _aramaSonucuSecildi(dynamic istasyon) async {
    // Klavyeyi kapat (arama sonucu seçildiğinde)
    _klavyeyiKapat();
    
    // Sadece detay sheet'i göster - kullanıcı "Rota oluştur" butonuna basarsa rota oluşturulur
    // Çift onay yok, sadece bir kez onay (detay sheet'teki buton)
    _istasyonDetayGoster(istasyon);
  }

  /// Klavyeyi kapatır - hem FocusScope hem de global focus'u temizler
  void _klavyeyiKapat() {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }


  @override
  void dispose() {
    _haritaKontrolcusu.dispose();
    super.dispose();
  }
}

/// Zoom butonları widget'ı
/// Haritayı yakınlaştırma ve uzaklaştırma butonları
class _ZoomButonlari extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _ZoomButonlari({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Zoom In butonu
        FloatingActionButton(
          onPressed: onZoomIn,
          backgroundColor: Colors.white,
          mini: true,
          heroTag: 'zoomIn',
          child: const Icon(
            Icons.add,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        // Zoom Out butonu
        FloatingActionButton(
          onPressed: onZoomOut,
          backgroundColor: Colors.white,
          mini: true,
          heroTag: 'zoomOut',
          child: const Icon(
            Icons.remove,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Konum butonu widget'ı
/// Kullanıcının konumuna odaklanır
class _KonumButonu extends ConsumerWidget {
  final MapController haritaKontrolcusu;

  const _KonumButonu({
    required this.haritaKontrolcusu,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kullaniciKonumu = ref.watch(konumGuncellemeleriProvider);

    return FloatingActionButton(
      onPressed: () async {
        // Konum almayı dene
        final konum = await KonumServisi.mevcutKonumuAl();
        
        if (konum != null) {
          // Haritayı kullanıcı konumuna odakla
          haritaKontrolcusu.move(konum, 15.0);
        } else {
          // İzin yoksa kullanıcıyı bilgilendir
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Konum izni gerekli. Lütfen ayarlardan konum iznini açın.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      },
      backgroundColor: Colors.white,
      child: kullaniciKonumu.when(
        data: (konum) => Icon(
          konum != null ? Icons.my_location : Icons.location_searching,
          color: konum != null ? Colors.amber.shade800 : Colors.grey,
        ),
        loading: () => const Icon(
          Icons.location_searching,
          color: Colors.grey,
        ),
        error: (error, stack) => const Icon(
          Icons.location_off,
          color: Colors.red,
        ),
      ),
    );
  }
}

/// Rota temizle butonu widget'ı
/// Aktif rotayı temizler
class _RotaTemizleButonu extends ConsumerWidget {
  const _RotaTemizleButonu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      onPressed: () {
        // Rota durumunu temizle
        ref.read(aktifRotaProvider.notifier).state = null;
        
        // Sesli yönlendirme durumunu da temizle
        ref.read(voiceGuidanceStateProvider.notifier).state = null;
        // Navigasyon indekslerini sıfırla
        ref.read(navigasyonIlerlemeIndeksProvider.notifier).state = null;
        ref.read(navigasyonSonDonusIndeksProvider.notifier).state = null;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rota temizlendi'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      backgroundColor: Colors.red,
      mini: true,
      child: const Icon(
        Icons.close,
        color: Colors.white,
      ),
    );
  }
}

/// Navigasyon Drawer widget'ı
/// En yakın istasyon seçimi için menü
class _NavigasyonDrawer extends ConsumerWidget {
  final MapController haritaKontrolcusu;
  final Future<void> Function(LatLng hedefKonum, {String? basariliMesaj}) onRotaOlustur;

  const _NavigasyonDrawer({
    required this.haritaKontrolcusu,
    required this.onRotaOlustur,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer başlığı - Beyaz arka plan, sarı yazı
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Text(
                'En Yakın İstasyon',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Menü seçenekleri
            ListTile(
              leading: Icon(Icons.directions_bike, color: Colors.amber.shade700),
              title: Text(
                'En yakın kiralık istasyon',
                style: TextStyle(color: Colors.amber.shade700),
              ),
              onTap: () => _enYakinIstasyonSec(
                context,
                ref,
                IstasyonTipi.kiralik,
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.local_parking, color: Colors.amber.shade700),
              title: Text(
                'En yakın park alanı',
                style: TextStyle(color: Colors.amber.shade700),
              ),
              onTap: () => _enYakinIstasyonSec(
                context,
                ref,
                IstasyonTipi.park,
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.build, color: Colors.amber.shade700),
              title: Text(
                'En yakın tamir noktası',
                style: TextStyle(color: Colors.amber.shade700),
              ),
              onTap: () => _enYakinIstasyonSec(
                context,
                ref,
                IstasyonTipi.tamir,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// En yakın istasyon seçimi ve rota oluşturma
  Future<void> _enYakinIstasyonSec(
    BuildContext context,
    WidgetRef ref,
    IstasyonTipi tip,
  ) async {
    // Drawer'ı kapat
    Navigator.of(context).pop();

    // ÖNCE: Mevcut rotayı temizle (yeni rota başlatmadan önce)
    ref.read(aktifRotaProvider.notifier).state = null;
    // Navigasyon indekslerini sıfırla
    ref.read(navigasyonIlerlemeIndeksProvider.notifier).state = null;
    ref.read(navigasyonSonDonusIndeksProvider.notifier).state = null;

    // Kullanıcı konumunu al
    final kullaniciKonumu = await KonumServisi.mevcutKonumuAl();

    if (kullaniciKonumu == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konum alınamadı. Lütfen konum izinlerini kontrol edin.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // İstasyon verilerini al
    final kiralikAsync = ref.read(kiralikIstasyonlarProvider);
    final parkAsync = ref.read(parkAlanlariProvider);
    final tamirAsync = ref.read(tamirIstasyonlariProvider);

    LatLng? hedefKonum;
    String? basariliMesaj;

    switch (tip) {
      case IstasyonTipi.kiralik:
        await kiralikAsync.when(
          data: (istasyonlar) {
            final enYakin = NavigationServisi.enYakinKiralikIstasyonBul(
              kullaniciKonumu,
              istasyonlar,
            );
            if (enYakin != null) {
              hedefKonum = enYakin.konum;
              basariliMesaj = 'En yakın kiralık istasyon için rota oluşturuldu.';
            }
            return null;
          },
          loading: () => null,
          error: (_, __) => null,
        );
        break;

      case IstasyonTipi.park:
        await parkAsync.when(
          data: (parkAlanlari) {
            final enYakin = NavigationServisi.enYakinParkAlaniBul(
              kullaniciKonumu,
              parkAlanlari,
            );
            if (enYakin != null) {
              hedefKonum = enYakin.konum;
              basariliMesaj = 'En yakın park alanı için rota oluşturuldu.';
            }
            return null;
          },
          loading: () => null,
          error: (_, __) => null,
        );
        break;

      case IstasyonTipi.tamir:
        await tamirAsync.when(
          data: (tamirIstasyonlari) {
            final enYakin = NavigationServisi.enYakinTamirIstasyonuBul(
              kullaniciKonumu,
              tamirIstasyonlari,
            );
            if (enYakin != null) {
              hedefKonum = enYakin.konum;
              basariliMesaj = 'En yakın tamir noktası için rota oluşturuldu.';
            }
            return null;
          },
          loading: () => null,
          error: (_, __) => null,
        );
        break;
    }

    // İstasyon bulunamadı
    if (hedefKonum == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu türde kayıtlı istasyon bulunamadı.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Merkezi rota oluşturma fonksiyonunu kullan
    await onRotaOlustur(hedefKonum!, basariliMesaj: basariliMesaj);
  }

  /// Haritayı rotaya fit eder
  void _haritayiRotayaFitEt(RotaVerisi rota) {
    if (rota.koordinatlar.isEmpty) return;

    // Tüm rota noktalarını içeren bounds hesapla
    double minLat = rota.koordinatlar.first.latitude;
    double maxLat = rota.koordinatlar.first.latitude;
    double minLon = rota.koordinatlar.first.longitude;
    double maxLon = rota.koordinatlar.first.longitude;

    for (final nokta in rota.koordinatlar) {
      if (nokta.latitude < minLat) minLat = nokta.latitude;
      if (nokta.latitude > maxLat) maxLat = nokta.latitude;
      if (nokta.longitude < minLon) minLon = nokta.longitude;
      if (nokta.longitude > maxLon) maxLon = nokta.longitude;
    }

    // Başlangıç ve bitiş noktalarını da ekle
    if (rota.baslangic.latitude < minLat) minLat = rota.baslangic.latitude;
    if (rota.baslangic.latitude > maxLat) maxLat = rota.baslangic.latitude;
    if (rota.baslangic.longitude < minLon) minLon = rota.baslangic.longitude;
    if (rota.baslangic.longitude > maxLon) maxLon = rota.baslangic.longitude;

    if (rota.bitis.latitude < minLat) minLat = rota.bitis.latitude;
    if (rota.bitis.latitude > maxLat) maxLat = rota.bitis.latitude;
    if (rota.bitis.longitude < minLon) minLon = rota.bitis.longitude;
    if (rota.bitis.longitude > maxLon) maxLon = rota.bitis.longitude;

    // Padding ekle
    final latFark = maxLat - minLat;
    final lonFark = maxLon - minLon;
    final padding = 0.1;

    minLat -= latFark * padding;
    maxLat += latFark * padding;
    minLon -= lonFark * padding;
    maxLon += lonFark * padding;

    // Merkez noktasını hesapla
    final merkez = LatLng(
      (minLat + maxLat) / 2,
      (minLon + maxLon) / 2,
    );

    // Zoom seviyesini hesapla
    final enBuyukFark = latFark > lonFark ? latFark : lonFark;
    double zoom = 15.0;
    if (enBuyukFark > 0.1) zoom = 12.0;
    if (enBuyukFark > 0.05) zoom = 13.0;
    if (enBuyukFark > 0.02) zoom = 14.0;
    if (enBuyukFark > 0.01) zoom = 15.0;
    if (enBuyukFark < 0.005) zoom = 16.0;
    if (enBuyukFark < 0.002) zoom = 17.0;

    // Haritayı güncelle
    haritaKontrolcusu.move(merkez, zoom);
  }
}

/// İstasyon tipi enum'u
enum IstasyonTipi {
  kiralik,
  park,
  tamir,
}

/// Üst panel widget'ı
/// Arama çubuğu, sonuçlar ve filtre butonlarını içerir
class _UstPanel extends ConsumerWidget {
  final MapController? haritaKontrolcusu;
  final Function(dynamic istasyon)? onIstasyonSecildi;
  final VoidCallback? onMenuPressed;

  const _UstPanel({
    this.haritaKontrolcusu,
    this.onIstasyonSecildi,
    this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aramaSorgusu = ref.watch(aramaSorgusuProvider);
    final aramaAktif = aramaSorgusu.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Arama çubuğu
        AramaCubugu(
          haritaKontrolcusu: haritaKontrolcusu,
          onIstasyonSecildi: onIstasyonSecildi,
          onMenuPressed: onMenuPressed,
        ),
        // Arama sonuçları dropdown (sadece arama aktifken)
        if (aramaAktif)
          _AramaSonuclariDropdown(
            haritaKontrolcusu: haritaKontrolcusu,
            onIstasyonSecildi: onIstasyonSecildi,
          ),
        // Filtre butonları (her zaman göster)
        const FiltreButonlari(),
      ],
    );
  }
}

/// Arama sonuçları dropdown widget'ı
class _AramaSonuclariDropdown extends ConsumerWidget {
  final MapController? haritaKontrolcusu;
  final Function(dynamic istasyon)? onIstasyonSecildi;

  const _AramaSonuclariDropdown({
    this.haritaKontrolcusu,
    this.onIstasyonSecildi,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aramaSonuclari = ref.watch(aramaSonuclariProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.4; // Maksimum ekranın %40'ı

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: aramaSonuclari.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sonuç bulunamadı',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              itemCount: aramaSonuclari.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                thickness: 1,
              ),
              itemBuilder: (context, index) {
                final sonuc = aramaSonuclari[index];
                return _AramaSonucuItem(
                  sonuc: sonuc,
                  onTap: () {
                    // Klavyeyi kapat (hem FocusScope hem global)
                    FocusScope.of(context).unfocus();
                    FocusManager.instance.primaryFocus?.unfocus();

                    // Haritayı istasyona odakla
                    LatLng konum;
                    if (sonuc.istasyon is KiralikIstasyon) {
                      konum = (sonuc.istasyon as KiralikIstasyon).konum;
                    } else if (sonuc.istasyon is ParkAlani) {
                      konum = (sonuc.istasyon as ParkAlani).konum;
                    } else {
                      konum = (sonuc.istasyon as TamirIstasyonu).konum;
                    }

                    if (haritaKontrolcusu != null) {
                      haritaKontrolcusu!.move(konum, 16.0);
                    }

                    // Arama sorgusunu temizle
                    ref.read(aramaSorgusuProvider.notifier).state = '';

                    // Callback'i çağır
                    if (onIstasyonSecildi != null) {
                      onIstasyonSecildi!(sonuc.istasyon);
                    }
                  },
                );
              },
            ),
    );
  }
}

/// Arama sonucu öğesi widget'ı (harita ekranı içinde)
class _AramaSonucuItem extends StatelessWidget {
  final AramaSonucu sonuc;
  final VoidCallback onTap;

  const _AramaSonucuItem({
    required this.sonuc,
    required this.onTap,
  });

  IconData _getIcon() {
    switch (sonuc.tip) {
      case 'kiralik':
        return Icons.directions_bike;
      case 'park':
        return Icons.local_parking;
      case 'tamir':
        return Icons.build;
      default:
        return Icons.location_on;
    }
  }

  Color _getColor() {
    switch (sonuc.tip) {
      case 'kiralik':
        return const Color(0xFF2196F3); // Mavi
      case 'park':
        return const Color(0xFF4CAF50); // Yeşil
      case 'tamir':
        return const Color(0xFFFF9800); // Turuncu
      default:
        return Colors.grey;
    }
  }

  String _getMesafeText() {
    if (sonuc.mesafe == null) return '—';
    if (sonuc.mesafe! < 1000) {
      return '${sonuc.mesafe!.toStringAsFixed(0)} m';
    } else {
      return '${(sonuc.mesafe! / 1000).toStringAsFixed(2)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            // İkon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIcon(),
                color: _getColor(),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Başlık ve alt başlık
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sonuc.baslik,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sonuc.altBaslik != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      sonuc.altBaslik!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Mesafe (her zaman göster, "—" if null)
            const SizedBox(width: 8),
            Text(
              _getMesafeText(),
              style: TextStyle(
                fontSize: 12,
                color: sonuc.mesafe != null ? Colors.grey.shade600 : Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rota oluştur bottom sheet widget'ı
class _RotaOlusturBottomSheet extends StatelessWidget {
  const _RotaOlusturBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Rota oluşturulsun mu?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Hayır'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Evet'),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
