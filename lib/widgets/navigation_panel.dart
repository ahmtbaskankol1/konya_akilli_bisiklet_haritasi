import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:konya_akilli_bisiklet_haritasi/providers/navigation_provider.dart'
    show
        NavigasyonDurumu,
        navigasyonDurumuProvider,
        nextTurnSmootherProvider,
        sonrakiDonusMesafesiStabilProvider,
        voiceGuidanceProvider,
        voiceGuidanceStateProvider,
        rotaIptalEdildiAtProvider,
        rerouteInProgressProvider,
        rerouteBasladiProvider,
        navigasyonIlerlemeIndeksProvider,
        navigasyonSonDonusIndeksProvider;
import 'package:konya_akilli_bisiklet_haritasi/providers/rota_provider.dart' as rota;
import 'package:konya_akilli_bisiklet_haritasi/services/navigation_service.dart';

/// Navigasyon paneli widget'ı
/// Modern navigasyon uygulamalarına benzer bilgi paneli gösterir
class NavigationPanel extends ConsumerWidget {
  const NavigationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigasyonAsync = ref.watch(navigasyonDurumuProvider);
    
    // Sesli yönlendirme provider'ını izle (otomatik olarak sesli yönlendirme yapar)
    ref.watch(voiceGuidanceProvider);
    // Mesafe stabilizer'ı aktifleştir
    ref.watch(nextTurnSmootherProvider);

    return navigasyonAsync.when(
      data: (navigasyon) {
        // Rota yoksa veya aktif değilse göster
        if (!navigasyon.aktif && navigasyon.kalanMesafe == 0.0) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Üst banner: Sonraki dönüş talimatı (sadece aktif navigasyonda)
              if (navigasyon.aktif && navigasyon.sonrakiDonus != null)
                _SonrakiDonusBanner(
                  talimat: navigasyon.sonrakiDonus!,
                  mesafe: ref.watch(sonrakiDonusMesafesiStabilProvider) ??
                      navigasyon.sonrakiDonusMesafesi ??
                      0.0,
                ),
              // Alt panel: Navigasyon bilgileri
              _NavigasyonBilgiPaneli(navigasyon: navigasyon),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Sonraki dönüş banner'ı
/// "In X meters turn left/right" gibi talimatları gösterir
class _SonrakiDonusBanner extends StatelessWidget {
  final String talimat;
  final double mesafe;

  const _SonrakiDonusBanner({
    required this.talimat,
    required this.mesafe,
  });

  @override
  Widget build(BuildContext context) {
    // Mesafeyi formatla (Türkçe format)
    String mesafeStr;
    if (mesafe < 1000) {
      mesafeStr = '${mesafe.toStringAsFixed(0)} m';
    } else {
      final km = (mesafe / 1000).toStringAsFixed(1);
      mesafeStr = '${km.replaceAll('.', ',')} km';
    }

    // Talimat metnini oluştur (Türkçe)
    String talimatMetni;
    if (talimat.toLowerCase().contains('straight')) {
      // Düz devam için mesafe söyleme
      talimatMetni = 'Düz devam et';
    } else if (talimat == 'Arrived') {
      talimatMetni = 'Hedefe ulaşıldı';
    } else if (talimat == 'Turn left') {
      talimatMetni = '$mesafeStr sonra sola dön';
    } else if (talimat == 'Turn right') {
      talimatMetni = '$mesafeStr sonra sağa dön';
    } else {
      talimatMetni = '$mesafeStr sonra $talimat';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Dönüş ikonu
          _DonusIkonu(talimat: talimat),
          const SizedBox(width: 16),
          // Talimat metni
          Expanded(
            child: Text(
              talimatMetni,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dönüş ikonu widget'ı
class _DonusIkonu extends StatelessWidget {
  final String talimat;

  const _DonusIkonu({required this.talimat});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    if (talimat == 'Arrived') {
      icon = Icons.flag;
      color = Colors.green;
    } else if (talimat.contains('left')) {
      icon = Icons.turn_left;
      color = Colors.amber.shade800;
    } else if (talimat.contains('right')) {
      icon = Icons.turn_right;
      color = Colors.amber.shade800;
    } else {
      icon = Icons.straight;
      color = Colors.green;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }
}

/// Navigasyon bilgi paneli
/// Alt kısımda gösterilen detaylı bilgiler
class _NavigasyonBilgiPaneli extends StatelessWidget {
  final NavigasyonDurumu navigasyon;

  const _NavigasyonBilgiPaneli({required this.navigasyon});

  @override
  Widget build(BuildContext context) {
    // Mesafeyi formatla (referans görseldeki gibi: "1,4km")
    String mesafeFormatted;
    if (navigasyon.kalanMesafe < 1000) {
      mesafeFormatted = '${navigasyon.kalanMesafe.toStringAsFixed(0)} m';
    } else {
      // Virgül ile formatla (Türkçe format)
      final km = (navigasyon.kalanMesafe / 1000).toStringAsFixed(1);
      mesafeFormatted = '${km.replaceAll('.', ',')} km';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Koyu gri, referans görsele yakın
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Kapat butonu (sol tarafta)
          _KapatButonu(),
          const SizedBox(width: 20),
          // Bilgi alanları (ortalanmış, yan yana)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Kalan mesafe
                _BilgiKutusu(
                  etiket: 'KALAN MESAFE',
                  deger: mesafeFormatted,
                ),
                // Kalan süre
                _BilgiKutusu(
                  etiket: 'SÜRE',
                  deger: NavigationServisi.sureFormatla(navigasyon.kalanSure),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kapat butonu widget'ı
/// Navigasyonu kapatmak için kırmızı X butonu
class _KapatButonu extends ConsumerWidget {
  const _KapatButonu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        // Mark route as cancelled (prevents reroute results from overwriting)
        ref.read(rotaIptalEdildiAtProvider.notifier).state = DateTime.now();
        
        // Stop any in-progress reroute
        ref.read(rerouteInProgressProvider.notifier).state = false;
        ref.read(rerouteBasladiProvider.notifier).state = false;
        
        // Rota durumunu temizle
        ref.read(rota.aktifRotaProvider.notifier).state = null;
        
        // Navigasyon indekslerini temizle
        ref.read(navigasyonIlerlemeIndeksProvider.notifier).state = null;
        ref.read(navigasyonSonDonusIndeksProvider.notifier).state = null;
        
        // Sesli yönlendirme durumunu da temizle
        ref.read(voiceGuidanceStateProvider.notifier).state = null;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rota temizlendi'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.close,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

/// Bilgi kutusu widget'ı
/// Her bir bilgi öğesi için (etiket + değer)
class _BilgiKutusu extends StatelessWidget {
  final String etiket;
  final String deger;

  const _BilgiKutusu({
    required this.etiket,
    required this.deger,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            etiket,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[500],
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            deger,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

