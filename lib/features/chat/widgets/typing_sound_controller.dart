import 'package:audioplayers/audioplayers.dart';

class TypingSoundController {
  static final TypingSoundController _instance = TypingSoundController._internal();
  factory TypingSoundController() => _instance;
  TypingSoundController._internal();

  final AudioPlayer _player = AudioPlayer();
  int _activeTypers = 0; // Reference counter

  Future<void> init() async {
    // Set up the player once for the whole app lifecycle
    await _player.setSource(AssetSource('sounds/keyboard_typing_sound.mp3'));
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(0.8);
  }

  void startTyping() {
    _activeTypers++;
    if (_activeTypers == 1) {
      // First bubble started typing, so start the sound
      _player.resume();
    }
  }

  void stopTyping() {
    if (_activeTypers > 0) {
      _activeTypers--;
    }
    if (_activeTypers == 0) {
      // No bubbles are typing anymore, stop the sound
      _player.pause();
      _player.seek(Duration.zero); // Reset for next time
    }
  }
}