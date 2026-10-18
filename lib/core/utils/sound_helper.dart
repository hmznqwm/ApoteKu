import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SoundHelper {
  static final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  static Uint8List? _beepWavBytes;
  static bool _isInitialized = false;

  /// Inisialisasi audio player & cache gelombang suara beep POS scanner
  static void init() {
    if (_isInitialized) return;
    try {
      _beepWavBytes = _generateScannerBeepWav(
        frequency: 2400.0,
        durationMs: 85,
        sampleRate: 44100,
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error init SoundHelper: $e');
    }
  }

  /// Memainkan suara scanner "TITT / BEEP" kasir standar supermarket
  static Future<void> playScannerBeep() async {
    // 1. Getaran Haptik untuk smartphone
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    // 2. Mainkan suara beep melalui AudioPlayer
    try {
      if (!_isInitialized || _beepWavBytes == null) {
        init();
      }

      if (_beepWavBytes != null) {
        // Hentikan suara sebelumnya jika masih ada & putar ulang dengan latensi minimal
        await _player.stop();
        await _player.play(BytesSource(_beepWavBytes!), volume: 1.0);
      } else {
        // Fallback SystemSound jika audio byte gagal
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (e) {
      debugPrint('Fallback to system sound: $e');
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Memainkan nada sukses transaksi
  static Future<void> playSuccessChime() async {
    try {
      HapticFeedback.lightImpact();
      final chimeBytes = _generateDoubleBeepWav();
      await _player.stop();
      await _player.play(BytesSource(chimeBytes), volume: 0.9);
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Membuat format WAV PCM 16-Bit Mono untuk nada beep scanner POS
  static Uint8List _generateScannerBeepWav({
    required double frequency,
    required int durationMs,
    int sampleRate = 44100,
  }) {
    final int numSamples = (sampleRate * (durationMs / 1000.0)).round();
    final int subChunk2Size = numSamples * 2; // 16-bit = 2 bytes per sample
    final int chunkSize = 36 + subChunk2Size;

    final ByteData byteData = ByteData(44 + subChunk2Size);

    // RIFF chunk descriptor
    byteData.setUint8(0, 0x52); // R
    byteData.setUint8(1, 0x49); // I
    byteData.setUint8(2, 0x46); // F
    byteData.setUint8(3, 0x46); // F
    byteData.setUint32(4, chunkSize, Endian.little);
    byteData.setUint8(8, 0x57);  // W
    byteData.setUint8(9, 0x41);  // A
    byteData.setUint8(10, 0x56); // V
    byteData.setUint8(11, 0x45); // E

    // fmt sub-chunk
    byteData.setUint8(12, 0x66); // f
    byteData.setUint8(13, 0x6D); // m
    byteData.setUint8(14, 0x74); // t
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    byteData.setUint16(20, 1, Endian.little);  // AudioFormat (1 for PCM)
    byteData.setUint16(22, 1, Endian.little);  // NumChannels (1 = Mono)
    byteData.setUint32(24, sampleRate, Endian.little); // SampleRate
    byteData.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    byteData.setUint16(32, 2, Endian.little);  // BlockAlign
    byteData.setUint16(34, 16, Endian.little); // BitsPerSample

    // data sub-chunk
    byteData.setUint8(36, 0x64); // d
    byteData.setUint8(37, 0x61); // a
    byteData.setUint8(38, 0x74); // t
    byteData.setUint8(39, 0x61); // a
    byteData.setUint32(40, subChunk2Size, Endian.little);

    final int attackSamples = (sampleRate * 0.006).round(); // 6ms attack
    final int decaySamples = (sampleRate * 0.018).round();  // 18ms decay
    const double maxAmplitude = 30000.0; // Max amplitude for 16-bit signed PCM

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      double envelope = 1.0;

      // Smooth attack to avoid audio pop
      if (i < attackSamples) {
        envelope = i / attackSamples;
      }
      // Smooth decay at the end
      else if (i > numSamples - decaySamples) {
        envelope = (numSamples - i) / decaySamples;
      }

      final double sampleValue = math.sin(2 * math.pi * frequency * t) * maxAmplitude * envelope;
      final int sampleInt = sampleValue.clamp(-32768.0, 32767.0).round();
      byteData.setInt16(44 + (i * 2), sampleInt, Endian.little);
    }

    return byteData.buffer.asUint8List();
  }

  /// Membuat nada double-chime untuk notifikasi
  static Uint8List _generateDoubleBeepWav() {
    const int sampleRate = 44100;
    const int durationMs = 150;
    final int numSamples = (sampleRate * (durationMs / 1000.0)).round();
    final int subChunk2Size = numSamples * 2;
    final int chunkSize = 36 + subChunk2Size;

    final ByteData byteData = ByteData(44 + subChunk2Size);

    // RIFF
    byteData.setUint8(0, 0x52); byteData.setUint8(1, 0x49); byteData.setUint8(2, 0x46); byteData.setUint8(3, 0x46);
    byteData.setUint32(4, chunkSize, Endian.little);
    byteData.setUint8(8, 0x57); byteData.setUint8(9, 0x41); byteData.setUint8(10, 0x56); byteData.setUint8(11, 0x45);
    // fmt
    byteData.setUint8(12, 0x66); byteData.setUint8(13, 0x6D); byteData.setUint8(14, 0x74); byteData.setUint8(15, 0x20);
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little);
    byteData.setUint16(22, 1, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);
    // data
    byteData.setUint8(36, 0x64); byteData.setUint8(37, 0x61); byteData.setUint8(38, 0x74); byteData.setUint8(39, 0x61);
    byteData.setUint32(40, subChunk2Size, Endian.little);

    final int midPoint = numSamples ~/ 2;
    for (int i = 0; i < numSamples; i++) {
      final double freq = i < midPoint ? 1800.0 : 2700.0;
      final double t = i / sampleRate;
      final double sampleVal = (math.sin(2 * math.pi * freq * t) * 26000.0).clamp(-32768.0, 32767.0);
      byteData.setInt16(44 + (i * 2), sampleVal.round(), Endian.little);
    }

    return byteData.buffer.asUint8List();
  }
}
