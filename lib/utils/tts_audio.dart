import 'dart:math' as math;
import 'dart:typed_data';

/// Turns raw Gemini-TTS PCM (signed 16-bit little-endian, mono) into a clean WAV file.
///
/// Gemini TTS clips tend to carry artifacts at their edges: a DC offset / low rumble,
/// a click on the very first sample and a short burst of hiss ("ghost speech") after the
/// last word. The pre-generated lesson clips are cleaned server-side with the same
/// algorithm (scratch/audio_tools/audio_clean.js); this is the on-device port so that the
/// teacher's spoken ANSWERS sound exactly like the lesson narration.
///
/// Pipeline: high-pass (DC/rumble) → find speech chunks → drop a noisy trailing/leading
/// fragment that follows a long pause → trim → fade in/out → short silent tail.
class TtsAudio {
  TtsAudio._();

  /// Sample rate declared in a Gemini `inlineData.mimeType`
  /// (e.g. `audio/L16;codec=pcm;rate=24000`). Defaults to 24 kHz.
  static int rateFromMime(String? mime) {
    final m = RegExp(r'rate=\s*(\d+)').firstMatch(mime ?? '');
    return m == null ? 24000 : int.tryParse(m.group(1)!) ?? 24000;
  }

  /// Gemini TTS models answer either with raw 16-bit PCM (`audio/L16`) or with a complete
  /// WAV file (`audio/wav`). Accepts both and returns a cleaned, playable WAV.
  static Uint8List cleanedWavFromGemini(Uint8List data, String? mime) {
    var pcm = data;
    var rate = rateFromMime(mime);
    final isRiff = data.length > 44 &&
        data[0] == 0x52 && // R
        data[1] == 0x49 && // I
        data[2] == 0x46 && // F
        data[3] == 0x46; // F
    if (isRiff) {
      final bd = ByteData.sublistView(data);
      var o = 12;
      while (o + 8 <= data.length) {
        final id = String.fromCharCodes(data.sublist(o, o + 4));
        final size = bd.getUint32(o + 4, Endian.little);
        if (id == 'fmt ' && o + 16 <= data.length) {
          rate = bd.getUint32(o + 12, Endian.little);
        } else if (id == 'data') {
          final endAt = math.min(data.length, o + 8 + size);
          pcm = Uint8List.sublistView(data, o + 8, endAt);
          break;
        }
        o += 8 + size + (size.isOdd ? 1 : 0);
      }
    }
    return cleanedWav(pcm, rate: rate);
  }

  /// PCM16 (little-endian, mono) → cleaned, playable WAV bytes.
  static Uint8List cleanedWav(Uint8List pcm, {int rate = 24000}) {
    final n0 = pcm.length ~/ 2;
    if (n0 == 0) return _wav(Int16List(0), rate);
    final bd = ByteData.sublistView(pcm);
    final input = Float32List(n0);
    for (var i = 0; i < n0; i++) {
      input[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return _wav(_clean(input, rate), rate);
  }

  static Int16List _clean(Float32List input, int rate) {
    final n0 = input.length;
    final x = Float32List(n0);

    // 1) DC removal + 1-pole high-pass at 70 Hz
    final rc = 1 / (2 * math.pi * 70);
    final a = rc / (rc + 1 / rate);
    double px = 0, py = 0;
    for (var i = 0; i < n0; i++) {
      final y = a * (py + input[i] - px);
      px = input[i];
      py = y;
      x[i] = y;
    }

    // 2) Frame loudness (20 ms)
    final fl = math.max(1, (rate * 0.02).round());
    final nf = n0 ~/ fl;
    if (nf < 3) return _toInt16(x, 0, n0, rate);
    final rms = Float32List(nf);
    for (var f = 0; f < nf; f++) {
      double e = 0;
      for (var i = f * fl; i < (f + 1) * fl; i++) {
        e += x[i] * x[i];
      }
      rms[f] = math.sqrt(e / fl);
    }
    final sorted = rms.toList()..sort();
    final ref = sorted[(sorted.length * 0.9).floor().clamp(0, sorted.length - 1)];
    final thresh = math.max(0.004, ref * 0.07);

    // 3) Group active frames into chunks (a quiet gap > 5 frames starts a new chunk)
    const merge = 5;
    final chunks = <List<int>>[]; // [startFrame, endFrame]
    for (var f = 0; f < nf; f++) {
      if (rms[f] <= thresh) continue;
      if (chunks.isNotEmpty && f - chunks.last[1] <= merge) {
        chunks.last[1] = f;
      } else {
        chunks.add([f, f]);
      }
    }
    if (chunks.isEmpty) return _toInt16(x, 0, n0, rate);

    ({double sec, double rms, double peak, double zcr}) stats(List<int> c) {
      final a0 = c[0] * fl, a1 = (c[1] + 1) * fl;
      double en = 0, pk = 0;
      var z = 0;
      for (var i = a0; i < a1; i++) {
        en += x[i] * x[i];
        final v = x[i].abs();
        if (v > pk) pk = v;
        if (i > a0 && (x[i] >= 0) != (x[i - 1] >= 0)) z++;
      }
      final len = a1 - a0;
      return (sec: len / rate, rms: math.sqrt(en / len), peak: pk, zcr: z / len);
    }

    // 4) Edge artifacts: noisy burst after a pause at the end / a 1–2 frame pop at the start
    while (chunks.length > 1) {
      final s = chunks.last[0];
      final prevEnd = chunks[chunks.length - 2][1];
      final st = stats(chunks.last);
      final gapBefore = (s - prevEnd - 1) * 0.02;
      final noisy = st.zcr >= 0.22 || st.peak >= 0.95 || st.rms >= ref * 1.6;
      if (gapBefore >= 0.1 && st.sec <= 0.8 && noisy) {
        chunks.removeLast();
      } else {
        break;
      }
    }
    while (chunks.length > 1) {
      final st = stats(chunks.first);
      final gapAfter = (chunks[1][0] - chunks[0][1] - 1) * 0.02;
      if (st.sec <= 0.15 && gapAfter >= 0.1) {
        chunks.removeAt(0);
      } else {
        break;
      }
    }

    final start = math.max(0, chunks.first[0] * fl - (rate * 0.06).round());
    final end = math.min(n0, (chunks.last[1] + 1) * fl + (rate * 0.12).round());
    return _toInt16(x, start, end, rate);
  }

  /// Trim → fades → silent tail → clamp → int16.
  static Int16List _toInt16(Float32List x, int start, int end, int rate) {
    final bodyLen = math.max(0, end - start);
    final tail = (rate * 0.25).round();
    final out = Float32List(bodyLen + tail);
    for (var i = 0; i < bodyLen; i++) {
      out[i] = x[start + i];
    }
    final fin = math.min(bodyLen, (rate * 0.012).round());
    final fout = math.min(bodyLen, (rate * 0.06).round());
    for (var i = 0; i < fin; i++) {
      out[i] *= i / fin;
    }
    for (var i = 0; i < fout; i++) {
      out[bodyLen - 1 - i] *= i / fout;
    }
    final pcm = Int16List(out.length);
    for (var i = 0; i < out.length; i++) {
      final v = out[i].clamp(-0.98, 0.98);
      pcm[i] = (v * 32767).round();
    }
    return pcm;
  }

  static Uint8List _wav(Int16List pcm, int rate) {
    final dataLen = pcm.length * 2;
    final b = ByteData(44 + dataLen);
    void tag(int o, String s) {
      for (var i = 0; i < 4; i++) {
        b.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    tag(0, 'RIFF');
    b.setUint32(4, 36 + dataLen, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    b.setUint32(16, 16, Endian.little); // PCM chunk size
    b.setUint16(20, 1, Endian.little); // PCM format
    b.setUint16(22, 1, Endian.little); // mono
    b.setUint32(24, rate, Endian.little);
    b.setUint32(28, rate * 2, Endian.little); // byte rate
    b.setUint16(32, 2, Endian.little); // block align
    b.setUint16(34, 16, Endian.little); // bits per sample
    tag(36, 'data');
    b.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < pcm.length; i++) {
      b.setInt16(44 + i * 2, pcm[i], Endian.little);
    }
    return b.buffer.asUint8List();
  }
}
