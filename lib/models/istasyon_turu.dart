/// İstasyon türü enum'u - Filtreleme için kullanılır
enum IstasyonTuru {
  /// Kiralık bisiklet istasyonları
  kiralik,
  
  /// Park alanları
  park,
  
  /// Tamir-bakım istasyonları
  tamir,
  
  /// Tüm istasyonlar
  hepsi,
}

/// İstasyon türü için yardımcı metodlar
extension IstasyonTuruExtension on IstasyonTuru {
  /// İstasyon türünün Türkçe adı
  String get ad {
    switch (this) {
      case IstasyonTuru.kiralik:
        return 'Kiralık İstasyonlar';
      case IstasyonTuru.park:
        return 'Park Alanları';
      case IstasyonTuru.tamir:
        return 'Tamir İstasyonları';
      case IstasyonTuru.hepsi:
        return 'Hepsini Göster';
    }
  }

  /// İstasyon türünün renk kodu (marker için)
  int get renkKodu {
    switch (this) {
      case IstasyonTuru.kiralik:
        return 0xFF2196F3; // Mavi
      case IstasyonTuru.park:
        return 0xFF4CAF50; // Yeşil
      case IstasyonTuru.tamir:
        return 0xFFFF9800; // Turuncu
      case IstasyonTuru.hepsi:
        return 0xFF757575; // Gri
    }
  }
}

