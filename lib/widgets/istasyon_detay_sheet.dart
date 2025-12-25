import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/kiralik_istasyon.dart';
import '../models/park_alani.dart';
import '../models/tamir_istasyonu.dart';
import '../providers/rota_provider.dart';
import 'package:konya_akilli_bisiklet_haritasi/providers/navigation_provider.dart';
import '../services/konum_servisi.dart';
import '../models/rota_verisi.dart';

/// İstasyon detay bottom sheet widget'ı
/// Marker'a tıklandığında gösterilir
class IstasyonDetaySheet extends ConsumerWidget {
  final dynamic istasyon; // KiralikIstasyon, ParkAlani veya TamirIstasyonu

  const IstasyonDetaySheet({
    super.key,
    required this.istasyon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık çubuğu
          Row(
            children: [
              _getIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getBaslik(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          
          // Detay bilgileri
          _buildDetaySatiri(
            icon: Icons.location_on,
            label: 'Konum',
            deger: _getKonumBilgisi(),
          ),
          const SizedBox(height: 12),
          
          if (istasyon is KiralikIstasyon) ...[
            _buildDetaySatiri(
              icon: Icons.qr_code,
              label: 'İstasyon Kodu',
              deger: (istasyon as KiralikIstasyon).istasyonKodu,
            ),
            const SizedBox(height: 12),
            _buildDetaySatiri(
              icon: Icons.bike_scooter,
              label: 'Peron Sayısı',
              deger: '${(istasyon as KiralikIstasyon).peronAdet}',
            ),
            const SizedBox(height: 12),
          ],
          
          if (istasyon is ParkAlani) ...[
            _buildDetaySatiri(
              icon: Icons.park,
              label: 'Park Alanı ID',
              deger: '#${(istasyon as ParkAlani).id}',
            ),
            const SizedBox(height: 12),
          ],
          
          if (istasyon is TamirIstasyonu) ...[
            _buildDetaySatiri(
              icon: Icons.build,
              label: 'Tamir İstasyonu',
              deger: 'Bakım ve Tamir Hizmeti',
            ),
            const SizedBox(height: 12),
          ],
          
          if (_getAdres() != null && _getAdres()!.isNotEmpty) ...[
            _buildDetaySatiri(
              icon: Icons.place,
              label: 'Adres',
              deger: _getAdres()!,
            ),
            const SizedBox(height: 12),
          ],
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          // Rota Göster butonu
          _RotaGosterButonu(
            istasyon: istasyon,
            onRotaGosterildi: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _getIcon() {
    Color renk;
    IconData icon;
    
    if (istasyon is KiralikIstasyon) {
      renk = const Color(0xFF2196F3);
      icon = Icons.bike_scooter;
    } else if (istasyon is ParkAlani) {
      renk = const Color(0xFF4CAF50);
      icon = Icons.park;
    } else {
      renk = const Color(0xFFFF9800);
      icon = Icons.build;
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: renk, size: 24),
    );
  }

  String _getBaslik() {
    if (istasyon is KiralikIstasyon) {
      return (istasyon as KiralikIstasyon).adres;
    } else if (istasyon is ParkAlani) {
      return (istasyon as ParkAlani).isim;
    } else {
      return (istasyon as TamirIstasyonu).baslik;
    }
  }

  String _getKonumBilgisi() {
    double enlem, boylam;
    if (istasyon is KiralikIstasyon) {
      enlem = (istasyon as KiralikIstasyon).enlem;
      boylam = (istasyon as KiralikIstasyon).boylam;
    } else if (istasyon is ParkAlani) {
      enlem = (istasyon as ParkAlani).enlem;
      boylam = (istasyon as ParkAlani).boylam;
    } else {
      enlem = (istasyon as TamirIstasyonu).enlem;
      boylam = (istasyon as TamirIstasyonu).boylam;
    }
    return '${enlem.toStringAsFixed(6)}, ${boylam.toStringAsFixed(6)}';
  }

  String? _getAdres() {
    if (istasyon is KiralikIstasyon) {
      return (istasyon as KiralikIstasyon).adres;
    }
    return null;
  }

  Widget _buildDetaySatiri({
    required IconData icon,
    required String label,
    required String deger,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                deger,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rota Göster butonu widget'ı
class _RotaGosterButonu extends ConsumerStatefulWidget {
  final dynamic istasyon;
  final VoidCallback onRotaGosterildi;

  const _RotaGosterButonu({
    required this.istasyon,
    required this.onRotaGosterildi,
  });

  @override
  ConsumerState<_RotaGosterButonu> createState() => _RotaGosterButonuState();
}

class _RotaGosterButonuState extends ConsumerState<_RotaGosterButonu> {
  bool _yukleniyor = false;

  LatLng _istasyonKonumuAl() {
    if (widget.istasyon is KiralikIstasyon) {
      return (widget.istasyon as KiralikIstasyon).konum;
    } else if (widget.istasyon is ParkAlani) {
      return (widget.istasyon as ParkAlani).konum;
    } else {
      return (widget.istasyon as TamirIstasyonu).konum;
    }
  }

  Future<void> _rotaGoster() async {
    setState(() {
      _yukleniyor = true;
    });

    try {
      // Klavyeyi kapat (rota oluşturma başlamadan önce)
      FocusScope.of(context).unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
      
      // Manuel rota oluşturma başladı - otomatik reroute'u devre dışı bırak
      ref.read(manuelRotaOlusturmaDevamEdiyorProvider.notifier).state = true;
      
      // Reset cancellation timestamp (new route creation)
      ref.read(rotaIptalEdildiAtProvider.notifier).state = null;
      
      // ÖNCE: Mevcut rotayı temizle (yeni rota başlatmadan önce)
      ref.read(aktifRotaProvider.notifier).state = null;
      // Navigasyon indekslerini sıfırla
      ref.read(navigasyonIlerlemeIndeksProvider.notifier).state = null;
      ref.read(navigasyonSonDonusIndeksProvider.notifier).state = null;
      
      // Sesli yönlendirme durumunu da temizle
      ref.read(voiceGuidanceStateProvider.notifier).state = null;

      // Kullanıcı konumunu al
      final kullaniciKonumu = await KonumServisi.mevcutKonumuAl();

      if (kullaniciKonumu == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Konum izni gerekli. Lütfen ayarlardan konum iznini açın.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        setState(() {
          _yukleniyor = false;
        });
        return;
      }

      // İstasyon konumunu al
      final istasyonKonumu = _istasyonKonumuAl();

      // Debug: Log route start
      print('ROUTE START requested: from=${kullaniciKonumu.latitude},${kullaniciKonumu.longitude} to=${istasyonKonumu.latitude},${istasyonKonumu.longitude}');

      // Rota parametrelerini oluştur
      final parametreler = RotaParametreleri(
        baslangic: kullaniciKonumu,
        bitis: istasyonKonumu,
        profil: 'cycling', // Bisiklet için 'cycling' kullan
      );

      // Debug: Log route calculation start
      print('ROUTE CALC started');

      // Provider cache'ini refresh et - bu önceki cache'i temizler ve yeni hesaplama yapar
      ref.refresh(rotaHesaplamaProvider(parametreler));
      
      // Rota hesapla
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

          // Klavyeyi kapat (hem FocusScope hem global)
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();

          // Rota başarıyla hesaplandı - sheet'i kapat
          widget.onRotaGosterildi();
          
          // Bir kez daha klavyeyi kapat (UI rebuild sonrası)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              FocusScope.of(context).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();
            }
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Rota gösteriliyor: ${rotaAsync.mesafeFormatted} (${rotaAsync.sureFormatted})',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // Rota hesaplanamadı
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rota hesaplanamadı. Lütfen tekrar deneyin.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      
      // Manuel rota oluşturma tamamlandı - otomatik reroute'u tekrar etkinleştir
      ref.read(manuelRotaOlusturmaDevamEdiyorProvider.notifier).state = false;
    } catch (e) {
      // Manuel rota oluşturma tamamlandı (hata olsa bile) - otomatik reroute'u tekrar etkinleştir
      ref.read(manuelRotaOlusturmaDevamEdiyorProvider.notifier).state = false;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rota hesaplama hatası: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _yukleniyor ? null : _rotaGoster,
        icon: _yukleniyor
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.directions),
        label: Text(_yukleniyor ? 'Rota Hesaplanıyor...' : 'Rota Göster'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber.shade800,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

