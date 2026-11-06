import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Ovoz va tebranish signallari.
///
/// Yangi buyurtma signali qurilmaning alarm/qo'ng'iroq oqimida chalinadi —
/// oddiy tizim tovushidan ancha balandroq.
class SoundFx {
  static Future<void> beep() async {
    try {
      await FlutterRingtonePlayer().playAlarm();
      await HapticFeedback.mediumImpact();
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Oshpazga yangi buyurtma kelganda chalinadigan signal.
  static Future<void> ring() async {
    try {
      await FlutterRingtonePlayer().playAlarm(volume: 1.0, looping: false);
      await HapticFeedback.heavyImpact();
    } catch (_) {
      try {
        for (var i = 0; i < 3; i++) {
          await SystemSound.play(SystemSoundType.alert);
          await Future<void>.delayed(const Duration(milliseconds: 180));
        }
        await HapticFeedback.heavyImpact();
      } catch (_) {
        // Jim o'tkazamiz.
      }
    }
  }
}
