import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../widgets/interactive_toy.dart';

class AudioManager {
  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await _player.setVolume(0.6);
  }

  Future<void> warmUp() async {
    try {
      await _player.setAsset('assets/audio/ding.wav');
      await _player.stop();
    } catch (_) {}
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  Future<void> playToySound(ToyType type) async {
    final asset = _assetForType(type);
    try {
      await _player.setAsset(asset);
      await _player.play();
    } catch (_) {}
  }

  String _assetForType(ToyType type) {
    switch (type) {
      case ToyType.yarn:
        return 'assets/audio/ding.wav';
      case ToyType.mouse:
        return 'assets/audio/squeak.wav';
      case ToyType.feather:
        return 'assets/audio/rustle.wav';
      case ToyType.laser:
        return 'assets/audio/chirp.wav';
    }
  }

  void dispose() {
    _player.dispose();
  }
}
