import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../models/kiralik_istasyon.dart';
import '../models/park_alani.dart';
import '../models/tamir_istasyonu.dart';

/// CSV verilerini okuyan ve modellere dönüştüren servis
class VeriServisi {
  /// Kiralık bisiklet istasyonlarını yükler
  static Future<List<KiralikIstasyon>> kiralikIstasyonlariYukle() async {
    try {
      final String csvVerisi = await rootBundle.loadString(
        'assets/2024-paylasimli-kiralik-bisiklet-istasyon-konumlari.csv',
      );
      
      // CSV parser - hem virgül hem noktalı virgül destekler
      final List<List<dynamic>> csvListesi = const CsvToListConverter(
        fieldDelimiter: ',',
        eol: '\n',
        shouldParseNumbers: false, // Sayıları string olarak tut, sonra parse edeceğiz
      ).convert(csvVerisi);

      if (csvListesi.isEmpty) {
        print('CSV dosyası boş');
        return [];
      }

      // İlk satır başlık satırı
      final List<String> basliklar = csvListesi[0]
          .map((e) => e.toString().trim().toLowerCase()) // Küçük harfe çevir
          .toList()
          .cast<String>();

      print('CSV Başlıkları: $basliklar');
      print('Toplam satır sayısı: ${csvListesi.length}');

      final List<KiralikIstasyon> istasyonlar = [];
      int basariliSayisi = 0;
      int hataliSayisi = 0;

      for (int i = 1; i < csvListesi.length; i++) {
        if (csvListesi[i].isEmpty || csvListesi[i].length < basliklar.length) {
          hataliSayisi++;
          continue;
        }

        final Map<String, dynamic> satir = {};
        for (int j = 0; j < basliklar.length && j < csvListesi[i].length; j++) {
          final deger = csvListesi[i][j]?.toString().trim() ?? '';
          satir[basliklar[j]] = deger;
        }

        try {
          // Debug: İlk birkaç satırı yazdır
          if (i <= 3) {
            print('Satır $i: $satir');
          }

          final istasyon = KiralikIstasyon.fromCsvRow(satir);
          
          // Geçerli koordinat kontrolü - Konya için mantıklı aralıkta olmalı
          // Konya: Enlem ~37-38, Boylam ~32-33
          if (istasyon.enlem != 0.0 && 
              istasyon.boylam != 0.0 &&
              istasyon.enlem >= 30.0 && istasyon.enlem <= 40.0 &&
              istasyon.boylam >= 30.0 && istasyon.boylam <= 40.0) {
            istasyonlar.add(istasyon);
            basariliSayisi++;
            
            // İlk birkaç istasyonu yazdır
            if (basariliSayisi <= 3) {
              print('İstasyon $basariliSayisi: ${istasyon.istasyonKodu} - Enlem: ${istasyon.enlem}, Boylam: ${istasyon.boylam}, Konum: ${istasyon.konum}');
            }
          } else {
            hataliSayisi++;
            if (i <= 3) {
              print('Geçersiz koordinat - Satır $i: Enlem: ${istasyon.enlem}, Boylam: ${istasyon.boylam}');
            }
          }
        } catch (e) {
          hataliSayisi++;
          if (i <= 3) {
            print('Parse hatası - Satır $i: $e');
          }
          continue;
        }
      }

      print('Kiralık istasyonlar yüklendi: $basariliSayisi başarılı, $hataliSayisi hatalı');
      return istasyonlar;
    } catch (e, stackTrace) {
      print('Kiralık istasyonlar yüklenirken hata: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Park alanlarını yükler
  static Future<List<ParkAlani>> parkAlanlariYukle() async {
    try {
      // CSV dosyasını oku (UTF-8 encoding ile)
      final String csvVerisi = await rootBundle.loadString(
        'assets/2024_bisiklet_park_alanlari_istasyonlari_konumlar.csv',
      );

      // CSV parser - tamir istasyonu gibi basit parse
      final List<List<dynamic>> csvListesi = const CsvToListConverter(
        fieldDelimiter: ',',
        eol: '\n',
      ).convert(csvVerisi);

      if (csvListesi.isEmpty) {
        print('Park alanları CSV dosyası boş');
        return [];
      }

      // İlk satır başlık satırı (tamir istasyonu gibi direkt kullan, ParkAlani.fromCsvRow içinde küçük harfe çevrilecek)
      final List<String> basliklar = csvListesi[0]
          .map((e) => e.toString().trim())
          .toList()
          .cast<String>();

      print('=== PARK ALANLARI CSV YÜKLEME BAŞLADI ===');
      print('Park alanları CSV Başlıkları: $basliklar');
      print('Park alanları toplam satır sayısı: ${csvListesi.length}');

      final List<ParkAlani> parkAlanlari = [];
      int basariliSayisi = 0;
      int hataliSayisi = 0;

      for (int i = 1; i < csvListesi.length; i++) {
        if (csvListesi[i].isEmpty) continue;

        final Map<String, dynamic> satir = {};
        for (int j = 0; j < basliklar.length && j < csvListesi[i].length; j++) {
          final deger = csvListesi[i][j]?.toString().trim() ?? '';
          satir[basliklar[j]] = deger;
        }

        try {
          final parkAlani = ParkAlani.fromCsvRow(satir);
          
          // Geçerli koordinat kontrolü - Konya için mantıklı aralıkta olmalı
          // Konya: Latitude ~37-38, Longitude ~32-33
          // CSV'de enlem=longitude, boylam=latitude (swapped)
          // konum getter zaten LatLng(boylam, enlem) = LatLng(latitude, longitude) yapıyor
          final konum = parkAlani.konum;
          
          // Koordinatların geçerli olduğunu kontrol et
          // 0.0 kontrolü + Konya bölgesi kontrolü (daha geniş aralık)
          if (parkAlani.enlem != 0.0 && 
              parkAlani.boylam != 0.0 &&
              konum.latitude >= 36.0 && konum.latitude <= 40.0 &&
              konum.longitude >= 30.0 && konum.longitude <= 35.0) {
            parkAlanlari.add(parkAlani);
            basariliSayisi++;
          } else {
            hataliSayisi++;
            // Sadece ilk 10 hatalı satırı logla
            if (hataliSayisi <= 10) {
              print('⚠ Geçersiz koordinat - Satır $i: İsim="${parkAlani.isim}", Enlem=${parkAlani.enlem}, Boylam=${parkAlani.boylam}, Konum=${parkAlani.konum}');
            }
          }
        } catch (e) {
          // Hatalı satırları atla
          hataliSayisi++;
          // Sadece ilk 5 parse hatasını logla
          if (hataliSayisi <= 5) {
            print('⚠ Parse hatası - Satır $i: $e');
          }
          continue;
        }
      }

      print('=== PARK ALANLARI YÜKLEME TAMAMLANDI ===');
      print('Park alanları yüklendi: $basariliSayisi başarılı, $hataliSayisi hatalı');
      print('Toplam park alanı sayısı: ${parkAlanlari.length}');
      
      return parkAlanlari;
    } catch (e, stackTrace) {
      print('Park alanları yüklenirken hata: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Tamir-bakım istasyonlarını yükler
  static Future<List<TamirIstasyonu>> tamirIstasyonlariYukle() async {
    try {
      final String csvVerisi = await rootBundle.loadString(
        'assets/bisiklet_tamir_bakim_istasyon_konumlari.csv',
      );

      final List<List<dynamic>> csvListesi = const CsvToListConverter(
        fieldDelimiter: ',',
        eol: '\n',
      ).convert(csvVerisi);

      if (csvListesi.isEmpty) return [];

      // İlk satır başlık satırı (Türkçe karakterleri koru)
      final List<String> basliklar = csvListesi[0]
          .map((e) => e.toString().trim())
          .toList()
          .cast<String>();

      final List<TamirIstasyonu> tamirIstasyonlari = [];

      for (int i = 1; i < csvListesi.length; i++) {
        if (csvListesi[i].isEmpty) continue;

        final Map<String, dynamic> satir = {};
        for (int j = 0; j < basliklar.length && j < csvListesi[i].length; j++) {
          satir[basliklar[j]] = csvListesi[i][j];
        }

        try {
          final tamirIstasyonu = TamirIstasyonu.fromCsvRow(satir);
          // Geçerli koordinat kontrolü
          if (tamirIstasyonu.enlem != 0.0 && tamirIstasyonu.boylam != 0.0) {
            tamirIstasyonlari.add(tamirIstasyonu);
          }
        } catch (e) {
          // Hatalı satırları atla
          continue;
        }
      }

      return tamirIstasyonlari;
    } catch (e) {
      print('Tamir istasyonları yüklenirken hata: $e');
      return [];
    }
  }
}

