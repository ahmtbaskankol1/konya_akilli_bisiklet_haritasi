import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/istasyon_turu.dart';
import '../providers/istasyon_provider.dart';

/// Filtre butonları widget'ı
/// İstasyon türüne göre filtreleme yapar
class FiltreButonlari extends ConsumerWidget {
  const FiltreButonlari({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seciliTur = ref.watch(seciliIstasyonTuruProvider);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FiltreButonu(
              tur: IstasyonTuru.hepsi,
              seciliTur: seciliTur,
              onTap: () {
                ref.read(seciliIstasyonTuruProvider.notifier).state =
                    IstasyonTuru.hepsi;
              },
            ),
            const SizedBox(width: 8),
            _FiltreButonu(
              tur: IstasyonTuru.kiralik,
              seciliTur: seciliTur,
              renk: const Color(0xFF2196F3), // Mavi
              onTap: () {
                ref.read(seciliIstasyonTuruProvider.notifier).state =
                    IstasyonTuru.kiralik;
              },
            ),
            const SizedBox(width: 8),
            _FiltreButonu(
              tur: IstasyonTuru.park,
              seciliTur: seciliTur,
              renk: const Color(0xFF4CAF50), // Yeşil
              onTap: () {
                ref.read(seciliIstasyonTuruProvider.notifier).state =
                    IstasyonTuru.park;
              },
            ),
            const SizedBox(width: 8),
            _FiltreButonu(
              tur: IstasyonTuru.tamir,
              seciliTur: seciliTur,
              renk: const Color(0xFFFF9800), // Turuncu
              onTap: () {
                ref.read(seciliIstasyonTuruProvider.notifier).state =
                    IstasyonTuru.tamir;
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek bir filtre butonu widget'ı
class _FiltreButonu extends StatelessWidget {
  final IstasyonTuru tur;
  final IstasyonTuru seciliTur;
  final VoidCallback onTap;
  final Color? renk;

  const _FiltreButonu({
    required this.tur,
    required this.seciliTur,
    required this.onTap,
    this.renk,
  });

  @override
  Widget build(BuildContext context) {
    final secili = tur == seciliTur;
    final butonRenk = renk ?? Colors.grey;

    return Material(
      color: secili ? butonRenk : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: secili ? butonRenk : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (renk != null) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: secili ? Colors.white : butonRenk,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                tur.ad,
                style: TextStyle(
                  color: secili ? Colors.white : Colors.black87,
                  fontWeight: secili ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

