import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import '../providers/search_provider.dart';

/// Arama çubuğu widget'ı
/// Harita ekranının üstünde yer alır ve istasyon araması yapar
class AramaCubugu extends ConsumerStatefulWidget {
  final MapController? haritaKontrolcusu;
  final Function(dynamic istasyon)? onIstasyonSecildi;
  final VoidCallback? onMenuPressed;

  const AramaCubugu({
    super.key,
    this.haritaKontrolcusu,
    this.onIstasyonSecildi,
    this.onMenuPressed,
  });

  @override
  ConsumerState<AramaCubugu> createState() => _AramaCubuguState();
}

class _AramaCubuguState extends ConsumerState<AramaCubugu> {
  final TextEditingController _aramaController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _aramaAktif = false;
  String _oncekiSorgu = '';

  @override
  void initState() {
    super.initState();
    // Provider değişikliklerini dinle (dış kaynaklı değişiklikler için)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mevcutSorgu = ref.read(aramaSorgusuProvider);
      if (mevcutSorgu != _aramaController.text) {
        _aramaController.text = mevcutSorgu;
        _oncekiSorgu = mevcutSorgu;
      }
    });
  }

  @override
  void dispose() {
    _aramaController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Klavyeyi kapatır - hem FocusNode hem de global focus'u temizler
  void dismissKeyboard() {
    _focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _aramaYap(String query) {
    _oncekiSorgu = query;
    ref.read(aramaSorgusuProvider.notifier).state = query;
    // Arama aktif olduğunda sonuçları göster
    if (query.isNotEmpty) {
      setState(() {
        _aramaAktif = true;
      });
    }
  }

  void _aramaTemizle() {
    _aramaController.clear();
    _aramaYap('');
    _focusNode.unfocus();
    setState(() {
      _aramaAktif = false;
    });
  }

  void _aramaYenile() {
    // Mevcut metni al ve aramayı yeniden çalıştır
    final mevcutMetin = _aramaController.text.trim();
    if (mevcutMetin.isNotEmpty) {
      _aramaYap(mevcutMetin);
    } else {
      setState(() {
        _aramaAktif = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorgu = ref.watch(aramaSorgusuProvider);

    // Provider dış kaynaklı değiştiyse (örn: search result seçildi, sorgu temizlendi)
    // controller'ı güncelle, ama kullanıcı yazarken değil
    if (sorgu != _oncekiSorgu && sorgu != _aramaController.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && sorgu != _aramaController.text) {
          _aramaController.text = sorgu;
          _oncekiSorgu = sorgu;
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          // Hamburger menü butonu
          IconButton(
            icon: Icon(
              Icons.menu,
              color: Colors.amber.shade700,
            ),
            onPressed: widget.onMenuPressed ?? () {
              // Scaffold key'i almak için context kullan
              final scaffoldState = context.findAncestorStateOfType<ScaffoldState>();
              scaffoldState?.openDrawer();
            },
          ),
          // Arama çubuğu - flex ile küçültülmüş
          Expanded(
            child: TextField(
              controller: _aramaController,
              focusNode: _focusNode,
              autofocus: false, // Otomatik focus yok
              style: const TextStyle(color: Colors.black),
              onChanged: _aramaYap,
              onTap: () {
                setState(() {
                  _aramaAktif = true;
                });
                // Eğer mevcut metin varsa, aramayı yeniden çalıştır
                if (_aramaController.text.trim().isNotEmpty) {
                  _aramaYenile();
                }
              },
              onSubmitted: (value) {
                // Enter/search tuşuna basıldığında aramayı çalıştır
                _aramaYenile();
              },
              decoration: InputDecoration(
                hintText: 'İstasyon / Park alanı ara...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: sorgu.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _aramaTemizle,
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.amber.shade800, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

