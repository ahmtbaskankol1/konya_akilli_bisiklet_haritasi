/// Sesli yönlendirme aşaması
enum VoiceStage {
  /// Henüz mesaj söylenmedi
  none,
  
  /// İlk mesaj söylendi (X metre sonra)
  initial,
  
  /// 50 metre mesajı söylendi
  near50,
  
  /// "Şimdi dön" mesajı söylendi
  now,
}

/// Sesli yönlendirme durumu
/// Her dönüş için sesli yönlendirme aşamasını takip eder
class VoiceGuidanceState {
  /// İlk mesafeden dönüşe kadar olan mesafe (metre)
  final double initialDistanceToTurn;
  
  /// Mevcut sesli yönlendirme aşaması
  final VoiceStage voiceStage;
  
  /// Sonraki dönüş indeksi (hangi dönüş için bu durum)
  final int? turnIndex;
  
  /// Sonraki dönüş talimatı ("Turn left", "Turn right", "Go straight")
  final String? turnInstruction;

  const VoiceGuidanceState({
    required this.initialDistanceToTurn,
    required this.voiceStage,
    this.turnIndex,
    this.turnInstruction,
  });

  VoiceGuidanceState copyWith({
    double? initialDistanceToTurn,
    VoiceStage? voiceStage,
    int? turnIndex,
    String? turnInstruction,
  }) {
    return VoiceGuidanceState(
      initialDistanceToTurn: initialDistanceToTurn ?? this.initialDistanceToTurn,
      voiceStage: voiceStage ?? this.voiceStage,
      turnIndex: turnIndex ?? this.turnIndex,
      turnInstruction: turnInstruction ?? this.turnInstruction,
    );
  }

  /// Yeni bir dönüş için durumu sıfırla
  VoiceGuidanceState resetForNewTurn({
    required double newInitialDistance,
    required int newTurnIndex,
    required String newTurnInstruction,
  }) {
    return VoiceGuidanceState(
      initialDistanceToTurn: newInitialDistance,
      voiceStage: VoiceStage.none,
      turnIndex: newTurnIndex,
      turnInstruction: newTurnInstruction,
    );
  }
}

