import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/harita_ekrani.dart';

/// Konya Akıllı Bisiklet Haritası Uygulaması
/// Selçuk Üniversitesi Teknoloji Fakültesi Bilgisayar Mühendisliği Uygulamaları
void main() {
  runApp(
    const ProviderScope(
      child: KonyaAkilliBisikletApp(),
    ),
  );
}

/// Ana uygulama widget'ı
class KonyaAkilliBisikletApp extends StatelessWidget {
  const KonyaAkilliBisikletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Konya Akıllı Bisiklet Haritası',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: Colors.amber.shade700,
          secondary: Colors.amber.shade400,
          surface: const Color(0xFF2D2D1F), // Koyu sarımsı yüzey
          background: const Color(0xFF1A1A1A), // Koyu arka plan
          error: Colors.red.shade400,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: Colors.amber.shade100,
          onBackground: Colors.amber.shade100,
          onError: Colors.white,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        // Koyu sarı tema için ek ayarlar
        scaffoldBackgroundColor: const Color(0xFF1A1A1A), // Koyu arka plan
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white, // Beyaz arka plan
          foregroundColor: Colors.amber.shade700, // Sarı yazı
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.amber.shade700),
          titleTextStyle: TextStyle(
            color: Colors.amber.shade700,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardColor: const Color(0xFF2D2D1F),
        drawerTheme: DrawerThemeData(
          backgroundColor: Colors.white, // Beyaz arka plan
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2D2D1F),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber.shade700),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber.shade700.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber.shade700, width: 2),
          ),
        ),
      ),
      home: const HaritaEkrani(),
    );
  }
}

