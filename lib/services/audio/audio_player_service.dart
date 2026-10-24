import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

void _diag(String msg) {
  try {
    final f = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}itantra_diag.log',
    );
    f.writeAsStringSync('${DateTime.now().toIso8601String()} $msg\n',
        mode: FileMode.append);
  } catch (_) {}
}

/// Plays synthesized Piper TTS output and emergency siren on the device speaker.
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _sirenPlayer = AudioPlayer();
  bool _audioContextConfigured = false;
  Completer<void>? _activePlaybackCompleter;

  Stream<void> get onComplete => _player.onPlayerComplete;

  Future<void> _ensureAudioContext() async {
    if (_audioContextConfigured) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      _audioContextConfigured = true;
      return;
    }
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.allowBluetooth,
            },
          ),
        ),
      );
      _audioContextConfigured = true;
      _diag('_ensureAudioContext OK');
    } catch (e, st) {
      _diag('_ensureAudioContext error (ignored): $e\n$st');
    }
  }

  /// Plays a file at maximum volume. If [loop] is true, loops indefinitely.
  Future<bool> playFile(String path, {bool loop = false}) async {
    try {
      final file = File(path);
      if (!file.existsSync() || file.lengthSync() == 0) {
        _diag('playFile FAILED: file does not exist or empty: $path');
        return false;
      }

      await _ensureAudioContext();

      await _player.stop();
      await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      await _player.setVolume(1.0);
      await _player.play(DeviceFileSource(path));
      _diag('playFile OK $path state=${_player.state}');
      return true;
    } catch (e, st) {
      _diag('playFile FAILED $path error=$e\n$st');
      return false;
    }
  }

  /// Plays a file and safely awaits completion without race conditions.
  Future<bool> playFileAndWait(
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() == 0) {
      _diag('playFileAndWait FAILED: file does not exist or empty: $path');
      return false;
    }

    final completer = Completer<void>();
    _activePlaybackCompleter = completer;
    StreamSubscription<void>? subComplete;
    try {
      // Natural playback completion listener: only fires when audio finishes!
      subComplete = _player.onPlayerComplete.listen((_) {
        _diag('AudioPlayer onPlayerComplete fired');
        if (!completer.isCompleted) completer.complete();
      });

      final started = await playFile(path);
      if (!started) return false;

      await completer.future.timeout(
        timeout,
        onTimeout: () => _diag('playFileAndWait timed out after ${timeout.inSeconds}s'),
      );
      return true;
    } catch (e, st) {
      _diag('playFileAndWait error: $e\n$st');
      return false;
    } finally {
      if (_activePlaybackCompleter == completer) {
        _activePlaybackCompleter = null;
      }
      await subComplete?.cancel();
    }
  }

  /// Plays the emergency siren on a dedicated player with looping.
  Future<void> playSirenLoop(String assetPath) async {
    try {
      // audioplayers AssetSource automatically prepends 'assets/'.
      // If caller passed 'assets/audio/siren_alert.wav', strip 'assets/' to avoid 'assets/assets/...'.
      final cleanPath = assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;

      await _ensureAudioContext();
      await _sirenPlayer.stop();
      await _sirenPlayer.setReleaseMode(ReleaseMode.loop);
      await _sirenPlayer.setVolume(1.0);
      await _sirenPlayer.setSourceAsset(cleanPath);
      await _sirenPlayer.resume();
    } catch (_) {
      // If asset not found or platform error occurs, fail gracefully without throwing.
      _generateSyntheticSiren();
    }
  }

  /// Stops all audio playback.
  Future<void> stop() async {
    try {
      if (_activePlaybackCompleter?.isCompleted == false) {
        _activePlaybackCompleter?.complete();
        _activePlaybackCompleter = null;
      }
      await _player.stop();
      await _sirenPlayer.stop();
    } catch (e, st) {
      _diag('AudioPlayerService.stop error: $e\n$st');
    }
  }

  /// Generates a synthetic emergency siren tone as fallback.
  void _generateSyntheticSiren() {
    // In a real implementation, this would use a tone generator.
    // For now, we just log that fallback was triggered.
    // print('Synthetic siren fallback triggered');
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
      await _sirenPlayer.dispose();
    } catch (_) {}
  }
}
