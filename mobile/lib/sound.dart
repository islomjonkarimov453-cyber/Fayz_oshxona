import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Ovoz signallari — veb-versiyadagi kabi yumshoq signal.
///
/// Budilnik (alarm) o'rniga har 5 sekundda qisqa signal chaladi:
/// - oshpaz: `cook_ring.wav` (yangi buyurtma qabul qilinmaguncha)
/// - ofitsiant: `waiter_ring.wav` (taom tayyor bo'lib olinmaguncha)
class SoundFx {
  static final AudioPlayer _player = AudioPlayer();
  static Timer? _timer;

  static Future<void> _play(String asset) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Ovoz chalmasa ham davom etamiz.
    }
  }

  /// Signalni yoqadi: darhol bir marta, keyin har 5 sekundda.
  static void startSignal(String asset) {
    _play(asset);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _play(asset);
    });
  }

  /// Signalni to'xtatadi.
  static void stopSignal() {
    _timer?.cancel();
    _timer = null;
    _player.stop();
  }

  /// Oshpaz signali (yangi buyurtma).
  static void startCookSignal() => startSignal('sounds/cook_ring.wav');

  /// Ofitsiant signali (taom tayyor).
  static void startWaiterSignal() => startSignal('sounds/waiter_ring.wav');

  // Eski nomlar (moslashuv uchun).
  static Future<void> beep() => _play('sounds/waiter_ring.wav');
  static Future<void> ring() => _play('sounds/cook_ring.wav');
  static void startAlarm() => startCookSignal();
  static void stopAlarm() => stopSignal();
}
