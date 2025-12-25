import 'package:flutter_tts/flutter_tts.dart';

/// Sesli yönlendirme servisi
/// TTS (Text-to-Speech) kullanarak navigasyon talimatlarını seslendirir
class VoiceNavigationService {
  static final VoiceNavigationService _instance = VoiceNavigationService._internal();
  factory VoiceNavigationService() => _instance;
  VoiceNavigationService._internal();

  FlutterTts? _tts;
  bool _initialized = false;
  bool _sesliYonlendirmeAktif = true; // Varsayılan olarak açık

  /// TTS servisini başlatır
  Future<void> initialize() async {
    if (_initialized) return;

    _tts = FlutterTts();
    
    // Dil ayarı - mevcut değilse fallback dene
    try {
      final trAvailable = await _tts!.isLanguageAvailable('tr-TR') ?? false;
      if (trAvailable) {
        await _tts!.setLanguage('tr-TR');
        print('[TTS] Language set to tr-TR');
      } else {
        await _tts!.setLanguage('tr');
        print('[TTS] Language tr-TR unavailable, fallback tr');
      }
    } catch (e) {
      print('[TTS] Language set error: $e');
    }
    
    // Hız ayarı (0.0 - 1.0)
    await _tts!.setSpeechRate(0.55);
    
    // Ses yüksekliği (0.0 - 1.0)
    await _tts!.setVolume(1.0);
    
    // Pitch (0.5 - 2.0)
    await _tts!.setPitch(1.0);

    // Konuşma tamamlanmasını bekle (Android emülatörlerde güvenilirlik için)
    try {
      await _tts!.awaitSpeakCompletion(true);
    } catch (e) {
      print('[TTS] awaitSpeakCompletion error: $e');
    }

    _initialized = true;
    print('[TTS] initialized');
  }

  /// Sesli yönlendirmeyi aç/kapat
  void setSesliYonlendirme(bool aktif) {
    _sesliYonlendirmeAktif = aktif;
  }

  /// Sesli yönlendirme aktif mi?
  bool get sesliYonlendirmeAktif => _sesliYonlendirmeAktif;

  /// Talimatı seslendirir
  /// [metin] Seslendirilecek Türkçe metin
  Future<void> speakInstruction(String metin) async {
    if (!_sesliYonlendirmeAktif) return;
    if (!_initialized) await initialize();
    if (_tts == null) return;

    try {
      print('[TTS] speak start: "$metin"');
      // Önceki konuşmayı durdur
      await _tts!.stop();
      
      // Yeni talimatı seslendir
      await _tts!.speak(metin);
      print('[TTS] speak done');
    } catch (e) {
      print('TTS hatası: $e');
    }
  }

  /// Konuşmayı durdurur
  Future<void> stop() async {
    if (!_initialized || _tts == null) return;
    try {
      await _tts!.stop();
    } catch (e) {
      print('TTS durdurma hatası: $e');
    }
  }

  /// Servisi temizler
  Future<void> dispose() async {
    if (_tts != null) {
      await _tts!.stop();
      _tts = null;
    }
    _initialized = false;
  }
}

