import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:konya_akilli_bisiklet_haritasi/models/rota_verisi.dart';
import 'package:konya_akilli_bisiklet_haritasi/services/navigation_service.dart';
import 'package:konya_akilli_bisiklet_haritasi/providers/rota_provider.dart';
import 'package:konya_akilli_bisiklet_haritasi/providers/konum_provider.dart';
import 'package:konya_akilli_bisiklet_haritasi/models/voice_stage.dart';
import 'package:konya_akilli_bisiklet_haritasi/services/voice_navigation_service.dart';

/// Navigasyon durumu modeli
class NavigasyonDurumu {
  final double kalanMesafe; // metre
  final double kalanSure; // saniye
  final DateTime? varisZamani;
  final String? sonrakiDonus;
  final double? sonrakiDonusMesafesi; // metre
  final int? sonrakiDonusIndeksi; // dönüş indeksi
  final bool aktif;

  const NavigasyonDurumu({
    required this.kalanMesafe,
    required this.kalanSure,
    this.varisZamani,
    this.sonrakiDonus,
    this.sonrakiDonusMesafesi,
    this.sonrakiDonusIndeksi,
    this.aktif = false,
  });

  NavigasyonDurumu copyWith({
    double? kalanMesafe,
    double? kalanSure,
    DateTime? varisZamani,
    String? sonrakiDonus,
    double? sonrakiDonusMesafesi,
    int? sonrakiDonusIndeksi,
    bool? aktif,
  }) {
    return NavigasyonDurumu(
      kalanMesafe: kalanMesafe ?? this.kalanMesafe,
      kalanSure: kalanSure ?? this.kalanSure,
      varisZamani: varisZamani ?? this.varisZamani,
      sonrakiDonus: sonrakiDonus ?? this.sonrakiDonus,
      sonrakiDonusMesafesi: sonrakiDonusMesafesi ?? this.sonrakiDonusMesafesi,
      sonrakiDonusIndeksi: sonrakiDonusIndeksi ?? this.sonrakiDonusIndeksi,
      aktif: aktif ?? this.aktif,
    );
  }
}

/// Navigasyon durumu provider'ı
/// Aktif rota ve kullanıcı konumuna göre navigasyon metriklerini hesaplar
final navigasyonDurumuProvider = Provider<AsyncValue<NavigasyonDurumu>>((ref) {
  final aktifRota = ref.watch(aktifRotaProvider);
  final kullaniciKonumuAsync = ref.watch(konumGuncellemeleriProvider);

  // Rota yoksa boş durum döndür
  if (aktifRota == null || aktifRota.koordinatlar.isEmpty) {
    return AsyncValue.data(const NavigasyonDurumu(
      kalanMesafe: 0.0,
      kalanSure: 0.0,
      aktif: false,
    ));
  }

  // Kullanıcı konumunu kontrol et
  return kullaniciKonumuAsync.when(
    data: (kullaniciKonumu) {
      if (kullaniciKonumu == null) {
        // Konum yoksa, rota bilgilerini göster (başlangıç durumu)
        return AsyncValue.data(NavigasyonDurumu(
          kalanMesafe: aktifRota.mesafe ?? 0.0,
          kalanSure: aktifRota.sure ?? 0.0,
          varisZamani: aktifRota.sure != null
              ? DateTime.now().add(Duration(seconds: aktifRota.sure!.round()))
              : null,
          aktif: false,
        ));
      }

      // Önceki ilerleme ve dönüş indekslerini al
      final oncekiIlerlemeIndeks = ref.read(navigasyonIlerlemeIndeksProvider);
      final oncekiDonusIndeks = ref.read(navigasyonSonDonusIndeksProvider);

      // Navigasyon metriklerini hesapla (Google Maps benzeri mantık)
      final metrikler = NavigationServisi.metrikleriHesapla(
        kullaniciKonumu,
        aktifRota,
        oncekiIlerlemeIndeks: oncekiIlerlemeIndeks,
        oncekiDonusIndeks: oncekiDonusIndeks,
      );

      // İlerleme noktasını bul ve güncelle (asenkron olarak, yan etki olarak)
      final ilerlemeSonuc = NavigationServisi.rotaUzerindekiIlerlemeNoktasiBul(
        kullaniciKonumu,
        aktifRota.koordinatlar,
        oncekiIlerlemeIndeks: oncekiIlerlemeIndeks,
      );
      final yeniIlerlemeIndeks = ilerlemeSonuc['indeks'] as int;

      // İlerleme indeksini güncelle (mikro görev olarak, build'i etkilememek için)
      Future.microtask(() {
        ref.read(navigasyonIlerlemeIndeksProvider.notifier).state = yeniIlerlemeIndeks;
      });

      // Dönüş indeksini güncelle (yeni dönüş bulunduysa veya geçildiyse)
      final yeniDonusIndeks = metrikler.sonrakiDonusIndeksi;
      if (yeniDonusIndeks != null) {
        // Eğer dönüş çok yakınsa (geçildi olarak işaretle), bir sonraki dönüşe geç
        if (metrikler.sonrakiDonusMesafesi != null && 
            metrikler.sonrakiDonusMesafesi! <= 20.0 &&
            (oncekiDonusIndeks == null || yeniDonusIndeks != oncekiDonusIndeks)) {
          Future.microtask(() {
            ref.read(navigasyonSonDonusIndeksProvider.notifier).state = yeniDonusIndeks;
          });
        }
      }

      return AsyncValue.data(NavigasyonDurumu(
        kalanMesafe: metrikler.kalanMesafe,
        kalanSure: metrikler.kalanSure,
        varisZamani: metrikler.varisZamani,
        sonrakiDonus: metrikler.sonrakiDonus,
        sonrakiDonusMesafesi: metrikler.sonrakiDonusMesafesi,
        sonrakiDonusIndeksi: metrikler.sonrakiDonusIndeksi,
        aktif: true,
      ));
    },
    loading: () => AsyncValue.data(NavigasyonDurumu(
      kalanMesafe: aktifRota.mesafe ?? 0.0,
      kalanSure: aktifRota.sure ?? 0.0,
      varisZamani: aktifRota.sure != null
          ? DateTime.now().add(Duration(seconds: aktifRota.sure!.round()))
          : null,
      aktif: false,
    )),
    error: (error, stack) => AsyncValue.data(NavigasyonDurumu(
      kalanMesafe: aktifRota.mesafe ?? 0.0,
      kalanSure: aktifRota.sure ?? 0.0,
      varisZamani: aktifRota.sure != null
          ? DateTime.now().add(Duration(seconds: aktifRota.sure!.round()))
          : null,
      aktif: false,
    )),
  );
});

/// Navigasyon ilerleme indeksi (rota üzerindeki gerçek ilerleme noktası)
/// Google Maps benzeri forward projection için kullanılır
final navigasyonIlerlemeIndeksProvider = StateProvider<int?>((ref) => null);

/// Son geçilen dönüş indeksi
/// Bir dönüşü geçtikten sonra o dönüşü tekrar göstermemek için kullanılır
final navigasyonSonDonusIndeksProvider = StateProvider<int?>((ref) => null);

/// Navigasyon aktif mi kontrol provider'ı
final navigasyonAktifProvider = Provider<bool>((ref) {
  final aktifRota = ref.watch(aktifRotaProvider);
  return aktifRota != null && aktifRota.koordinatlar.isNotEmpty;
});

/// Mock navigasyon durumu provider'ı (test için)
/// GPS olmadan navigasyon panelini test etmek için kullanılabilir
final mockNavigasyonDurumuProvider = Provider<NavigasyonDurumu>((ref) {
  final aktifRota = ref.watch(aktifRotaProvider);
  
  if (aktifRota == null || aktifRota.koordinatlar.isEmpty) {
    return const NavigasyonDurumu(
      kalanMesafe: 0.0,
      kalanSure: 0.0,
      aktif: false,
    );
  }

  // Mock konum: Rota başlangıcına yakın bir nokta
  final mockKonum = aktifRota.koordinatlar.isNotEmpty
      ? aktifRota.koordinatlar.first
      : aktifRota.baslangic;

  // Navigasyon metriklerini hesapla
  final metrikler = NavigationServisi.metrikleriHesapla(
    mockKonum,
    aktifRota,
  );

  return NavigasyonDurumu(
    kalanMesafe: metrikler.kalanMesafe,
    kalanSure: metrikler.kalanSure,
    varisZamani: metrikler.varisZamani,
    sonrakiDonus: metrikler.sonrakiDonus,
    sonrakiDonusMesafesi: metrikler.sonrakiDonusMesafesi,
    aktif: true,
  );
});

/// Sesli yönlendirme durumu provider'ı
/// Her dönüş için sesli yönlendirme aşamasını takip eder
final voiceGuidanceStateProvider = StateProvider<VoiceGuidanceState?>((ref) => null);

/// Sonraki dönüş mesafesi için stabilizer cache
class _NextTurnCache {
  final int? turnIndex;
  final double? distance;

  const _NextTurnCache({
    required this.turnIndex,
    required this.distance,
  });
}

final nextTurnCacheProvider = StateProvider<_NextTurnCache?>((ref) => null);

/// Navigasyon mesafe stabilizer (UI'da mesafe sıçramalarını azaltır)
final nextTurnSmootherProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<NavigasyonDurumu>>(navigasyonDurumuProvider, (previous, next) {
    next.whenData((navigasyon) {
      final cacheNotifier = ref.read(nextTurnCacheProvider.notifier);
      final cache = ref.read(nextTurnCacheProvider);

      // Navigasyon yoksa veya dönüş bilgisi yoksa cache'i temizle
      if (!navigasyon.aktif ||
          navigasyon.sonrakiDonusMesafesi == null ||
          navigasyon.sonrakiDonusIndeksi == null) {
        if (cache != null) {
          cacheNotifier.state = null;
        }
        return;
      }

      final incomingDistance = navigasyon.sonrakiDonusMesafesi!;
      final incomingIndex = navigasyon.sonrakiDonusIndeksi!;

      if (cache != null && cache.turnIndex == incomingIndex) {
        // Aynı dönüş için mesafeyi sadece düşecek şekilde stabilize et (maks +5m tolerans)
        final smoothed = cache.distance != null
            ? math.min(cache.distance!, incomingDistance + 5)
            : incomingDistance;
        cacheNotifier.state = _NextTurnCache(
          turnIndex: incomingIndex,
          distance: smoothed,
        );
      } else {
        // Yeni dönüş: cache'i tazele
        cacheNotifier.state = _NextTurnCache(
          turnIndex: incomingIndex,
          distance: incomingDistance,
        );
      }
    });
  });
});

/// Stabilize edilmiş sonraki dönüş mesafesi (UI için)
final sonrakiDonusMesafesiStabilProvider = Provider<double?>((ref) {
  final navAsync = ref.watch(navigasyonDurumuProvider);
  final cache = ref.watch(nextTurnCacheProvider);

  return navAsync.when(
    data: (nav) {
      if (cache != null && cache.turnIndex == nav.sonrakiDonusIndeksi && cache.distance != null) {
        return cache.distance;
      }
      return nav.sonrakiDonusMesafesi;
    },
    loading: () => cache?.distance,
    error: (_, __) => cache?.distance,
  );
});

/// Sesli yönlendirme provider'ı
/// Navigasyon durumuna göre sesli yönlendirme mesajlarını yönetir
final voiceGuidanceProvider = Provider<void>((ref) {
  final voiceService = VoiceNavigationService();

  ref.listen<AsyncValue<NavigasyonDurumu>>(navigasyonDurumuProvider, (previous, next) {
    next.whenData((navigasyon) {
      // ref.listen callback senkron; async işleri microtask'e taşı
      Future.microtask(() async {
        final voiceState = ref.read(voiceGuidanceStateProvider);

        // Navigasyon kapalı veya dönüş yoksa state'i sıfırla
        if (!navigasyon.aktif ||
            navigasyon.sonrakiDonus == null ||
            navigasyon.sonrakiDonusMesafesi == null) {
          if (voiceState != null) {
            ref.read(voiceGuidanceStateProvider.notifier).state = null;
          }
          return;
        }

        final distanceToTurn = navigasyon.sonrakiDonusMesafesi!;
        final turnInstruction = navigasyon.sonrakiDonus!;
        final turnIndex = navigasyon.sonrakiDonusIndeksi;

        final isNewTurn = voiceState == null ||
            voiceState.turnIndex != turnIndex ||
            voiceState.turnInstruction != turnInstruction;

        VoiceGuidanceState currentState = isNewTurn
            ? VoiceGuidanceState(
                initialDistanceToTurn: distanceToTurn,
                voiceStage: VoiceStage.none,
                turnIndex: turnIndex,
                turnInstruction: turnInstruction,
              )
            : voiceState!;

        // Aşama 1
        if (currentState.voiceStage == VoiceStage.none && distanceToTurn > 100) {
          final initialDistanceRounded =
              ((currentState.initialDistanceToTurn / 10).round() * 10).toDouble();
          final mesafeStr = _mesafeFormatla(initialDistanceRounded);
          final talimat = _talimatOlustur(turnInstruction, mesafeStr, false);

          await voiceService.speakInstruction(talimat);

          ref.read(voiceGuidanceStateProvider.notifier).state =
              currentState.copyWith(voiceStage: VoiceStage.initial);

          return;
        }

        // Aşama 2
        if (currentState.voiceStage == VoiceStage.initial && distanceToTurn <= 50) {
          final talimat = _talimatOlustur(turnInstruction, '50', false);

          await voiceService.speakInstruction(talimat);

          ref.read(voiceGuidanceStateProvider.notifier).state =
              currentState.copyWith(voiceStage: VoiceStage.near50);

          return;
        }

        // Aşama 3
        if (currentState.voiceStage == VoiceStage.near50 && distanceToTurn <= 15) {
          final talimat = _talimatOlustur(turnInstruction, null, true);

          await voiceService.speakInstruction(talimat);

          ref.read(voiceGuidanceStateProvider.notifier).state =
              currentState.copyWith(voiceStage: VoiceStage.now);

          return;
        }

        // Yeni dönüşse ve henüz stage tetiklenmediyse state'i yaz
        if (isNewTurn) {
          ref.read(voiceGuidanceStateProvider.notifier).state = currentState;
        }
      });
    });
  });
});

/// Mesafeyi Türkçe formatla
/// Mesafeyi en yakın 10 metreye yuvarlar (780 -> 780, 785 -> 790)
String _mesafeFormatla(double mesafe) {
  final rounded = (mesafe / 10).round() * 10;
  if (rounded < 1000) {
    return rounded.toStringAsFixed(0);
  } else {
    // 1000 metreden fazla ise km cinsinden göster
    return '${(rounded / 1000).toStringAsFixed(1)}';
  }
}

/// Türkçe talimat metni oluştur
String _talimatOlustur(String turnInstruction, String? mesafe, bool simdi) {
  String yon;
  
  if (turnInstruction == 'Turn left') {
    yon = 'sola';
  } else if (turnInstruction == 'Turn right') {
    yon = 'sağa';
  } else if (turnInstruction == 'Go straight') {
    yon = 'düz';
  } else {
    yon = 'ileri';
  }

  if (simdi) {
    if (yon == 'düz') {
      return 'Şimdi düz devam edin';
    } else {
      return 'Şimdi $yon dön';
    }
  } else {
    final mesafeStr = mesafe ?? '0';
    if (yon == 'düz') {
      return '$mesafeStr metre sonra düz devam edin';
    } else {
      return '$mesafeStr metre sonra $yon dön';
    }
  }
}

/// Son reroute zamanını tutan provider
final sonRerouteZamaniProvider = StateProvider<DateTime?>((ref) => null);

/// Reroute başladı mı kontrol provider'ı
final rerouteBasladiProvider = StateProvider<bool>((ref) => false);

/// Reroute devam ediyor mu? (concurrent reroute'ları önlemek için)
final rerouteInProgressProvider = StateProvider<bool>((ref) => false);

/// Rota iptal edildi mi? (timestamp - reroute sonuçlarını ignore etmek için)
final rotaIptalEdildiAtProvider = StateProvider<DateTime?>((ref) => null);

/// Off-route distance provider (PURE COMPUTATION - no side effects)
/// Sadece rotadan uzaklığı hesaplar, side effect yapmaz
/// IMPORTANT: Bu provider sadece hesaplama yapar, state değiştirmez
final offRouteDistanceProvider = Provider<double?>((ref) {
  final aktifRota = ref.watch(aktifRotaProvider);
  final kullaniciKonumuAsync = ref.watch(konumGuncellemeleriProvider);
  final manuelRotaOlusturmaDevamEdiyor = ref.watch(manuelRotaOlusturmaDevamEdiyorProvider);
  
  // Rota yoksa veya konum yoksa null döndür
  if (aktifRota == null || aktifRota.koordinatlar.isEmpty) {
    return null;
  }
  
  // Manuel rota oluşturma devam ediyorsa null döndür
  if (manuelRotaOlusturmaDevamEdiyor) {
    return null;
  }
  
  // Kullanıcı konumunu al (sadece data durumunda)
  return kullaniciKonumuAsync.when(
    data: (kullaniciKonumu) {
      if (kullaniciKonumu == null) {
        return null;
      }
      
      // Rotadan uzaklığı hesapla (PURE COMPUTATION)
      return NavigationServisi.rotadanUzaklikHesapla(
        kullaniciKonumu,
        aktifRota.koordinatlar,
      );
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Public function to trigger reroute (called from UI listener)
/// This is safe to call from ref.listen side effects
Future<void> otomatikRerouteYap(
  WidgetRef ref,
  LatLng kullaniciKonumu,
  RotaVerisi mevcutRota,
) async {
  final simdi = DateTime.now();
  await _otomatikRerouteYap(ref, kullaniciKonumu, mevcutRota, simdi);
}

/// Otomatik reroute yapar (internal)
/// [kullaniciKonumu] Kullanıcının mevcut konumu
/// [mevcutRota] Mevcut rota (hedef aynı kalacak)
/// [rerouteStartedAt] Reroute başlangıç zamanı (cancel guard için)
/// 
/// IMPORTANT: Bu fonksiyon sadece otomatik reroute için kullanılır.
/// Manuel rota oluşturma işlemlerini etkilemez.
Future<void> _otomatikRerouteYap(
  WidgetRef ref,
  LatLng kullaniciKonumu,
  RotaVerisi mevcutRota,
  DateTime rerouteStartedAt,
) async {
  try {
    // Log reroute start with current location and destination
    print('REROUTE from (${kullaniciKonumu.latitude.toStringAsFixed(6)},${kullaniciKonumu.longitude.toStringAsFixed(6)}) to (${mevcutRota.bitis.latitude.toStringAsFixed(6)},${mevcutRota.bitis.longitude.toStringAsFixed(6)})');
    
    // Yeni rota parametreleri (mevcut konumdan aynı hedefe)
    final parametreler = RotaParametreleri(
      baslangic: kullaniciKonumu,
      bitis: mevcutRota.bitis,
      profil: 'cycling',
    );
    
    // Provider cache'ini refresh et
    ref.refresh(rotaHesaplamaProvider(parametreler));
    
    // Yeni rota hesapla
    final yeniRota = await ref.read(rotaHesaplamaProvider(parametreler).future);
    
    // GUARD: Check if route was cancelled during reroute calculation
    final rotaIptalEdildiAt = ref.read(rotaIptalEdildiAtProvider);
    if (rotaIptalEdildiAt != null && rotaIptalEdildiAt.isAfter(rerouteStartedAt)) {
      print('Reroute result ignored (route cancelled at ${rotaIptalEdildiAt})');
      return;
    }
    
    // GUARD: Check if route still exists
    final currentRota = ref.read(aktifRotaProvider);
    if (currentRota == null || currentRota.koordinatlar.isEmpty) {
      print('Reroute result ignored (route no longer active)');
      return;
    }
    
    if (yeniRota != null && yeniRota.koordinatlar.isNotEmpty) {
      // Log OLD route before update
      final oldRota = ref.read(aktifRotaProvider);
      if (oldRota != null && oldRota.koordinatlar.isNotEmpty) {
        print('OLD route: len=${oldRota.koordinatlar.length}, first=(${oldRota.koordinatlar.first.latitude.toStringAsFixed(6)},${oldRota.koordinatlar.first.longitude.toStringAsFixed(6)}), last=(${oldRota.koordinatlar.last.latitude.toStringAsFixed(6)},${oldRota.koordinatlar.last.longitude.toStringAsFixed(6)})');
      } else {
        print('OLD route: null or empty');
      }
      
      // Log NEW route after calculation
      print('NEW route: len=${yeniRota.koordinatlar.length}, first=(${yeniRota.koordinatlar.first.latitude.toStringAsFixed(6)},${yeniRota.koordinatlar.first.longitude.toStringAsFixed(6)}), last=(${yeniRota.koordinatlar.last.latitude.toStringAsFixed(6)},${yeniRota.koordinatlar.last.longitude.toStringAsFixed(6)})');
      
      // CRITICAL: Create IMMUTABLE route state with fresh list reference
      // This ensures FlutterMap detects the change and rebuilds the polyline
      final newPoints = List<LatLng>.from(yeniRota.koordinatlar);
      final immutableRota = RotaVerisi(
        koordinatlar: newPoints,
        mesafe: yeniRota.mesafe,
        sure: yeniRota.sure,
        baslangic: yeniRota.baslangic,
        bitis: yeniRota.bitis,
      );
      
      // Rota versiyonunu artır (polyline rebuild için) - ONLY after successful calculation
      final newVersion = ref.read(rotaVersiyonuProvider) + 1;
      ref.read(rotaVersiyonuProvider.notifier).state = newVersion;
      
      // Set the new immutable route
      ref.read(aktifRotaProvider.notifier).state = immutableRota;
      
      // Verify state was set correctly
      final verifyRota = ref.read(aktifRotaProvider);
      if (verifyRota != null && verifyRota.koordinatlar.isNotEmpty) {
        print('REROUTE state verify: aktifRota set with ${verifyRota.koordinatlar.length} points, version=$newVersion');
      } else {
        print('REROUTE ERROR: aktifRota is null or empty after setting!');
      }
      
      // Sesli yönlendirme durumunu sıfırla (yeni rota için)
      ref.read(voiceGuidanceStateProvider.notifier).state = null;
      
      print('Reroute completed: new distance=${immutableRota.mesafeFormatted}, duration=${immutableRota.sureFormatted}, points=${immutableRota.koordinatlar.length}');
    } else {
      print('Reroute failed: Rota hesaplanamadı veya boş');
      // Hata durumunda mevcut rotayı koru - state'i değiştirme
    }
  } catch (e) {
    print('Reroute error: $e');
    // Hata durumunda state'i temizleme - mevcut rotayı koru
  } finally {
    // Reroute tamamlandı, flag'i sıfırla
    ref.read(rerouteInProgressProvider.notifier).state = false;
  }
}

