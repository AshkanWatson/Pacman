// Generates every sound effect and music loop used by the game.
//
// All audio is synthesised from scratch (square/triangle/noise waves), so
// the assets are original, tiny and free of third-party licences.
//
//   dart run tool/generate_audio.dart
//
// Output: assets/audio/*.wav (16-bit PCM, mono, 22.05 kHz).
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sampleRate = 22050;

typedef Wave = double Function(double phase);

double square(double p) => (p % 1) < 0.5 ? 1 : -1;
double pulse25(double p) => (p % 1) < 0.25 ? 1 : -1;
double triangle(double p) {
  final x = p % 1;
  return x < 0.5 ? 4 * x - 1 : 3 - 4 * x;
}

final _noiseRng = Random(42);
double noise(double _) => _noiseRng.nextDouble() * 2 - 1;

/// A growable mono mix buffer.
class Track {
  Track(double seconds) : data = Float64List((seconds * sampleRate).ceil());
  final Float64List data;

  /// Adds a tone whose frequency follows [freq] (Hz as a function of the
  /// normalised time 0..1 within the note).
  void tone({
    required double start,
    required double duration,
    required double Function(double t) freq,
    Wave wave = square,
    double volume = 0.3,
    double attack = 0.005,
    double release = 0.03,
  }) {
    final s0 = (start * sampleRate).round();
    final n = (duration * sampleRate).round();
    var phase = 0.0;
    for (var i = 0; i < n && s0 + i < data.length; i++) {
      final t = i / n;
      final secs = i / sampleRate;
      phase += freq(t) / sampleRate;
      var env = 1.0;
      if (secs < attack) env = secs / attack;
      final tail = duration - secs;
      if (tail < release) env *= max(0, tail / release);
      data[s0 + i] += wave(phase) * volume * env;
    }
  }

  void note(
    double start,
    double duration,
    double hz, {
    Wave wave = square,
    double volume = 0.25,
    double release = 0.03,
  }) => tone(
    start: start,
    duration: duration,
    freq: (_) => hz,
    wave: wave,
    volume: volume,
    release: release,
  );

  Uint8List toWav() {
    final bytes = BytesBuilder();
    final pcm = ByteData(data.length * 2);
    for (var i = 0; i < data.length; i++) {
      final v = (data[i].clamp(-1.0, 1.0) * 32767).round();
      pcm.setInt16(i * 2, v, Endian.little);
    }
    final header = ByteData(44);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    header.setUint32(4, 36 + pcm.lengthInBytes, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    str(36, 'data');
    header.setUint32(40, pcm.lengthInBytes, Endian.little);
    bytes.add(header.buffer.asUint8List());
    bytes.add(pcm.buffer.asUint8List());
    return bytes.toBytes();
  }
}

/// MIDI note number to Hz.
double midi(num n) => 440.0 * pow(2, (n - 69) / 12);

double lerp(double a, double b, double t) => a + (b - a) * t;

Map<String, Track> buildAll() {
  final out = <String, Track>{};

  // "Waka" chomp: two halves, alternated by the game for the classic feel.
  out['chomp_a'] = Track(0.09)
    ..tone(
      start: 0,
      duration: 0.085,
      freq: (t) => lerp(520, 260, t),
      wave: triangle,
      volume: 0.45,
    );
  out['chomp_b'] = Track(0.09)
    ..tone(
      start: 0,
      duration: 0.085,
      freq: (t) => lerp(260, 540, t),
      wave: triangle,
      volume: 0.45,
    );

  // Power brace: rising "compile" arpeggio.
  final power = Track(0.42);
  for (var i = 0; i < 8; i++) {
    power.note(i * 0.05, 0.05, midi(60 + i * 3), wave: pulse25, volume: 0.22);
  }
  out['power'] = power;

  // TypeScript mode loop: fast warble (loopable, 0.4 s).
  out['fright_loop'] = Track(0.4)
    ..tone(
      start: 0,
      duration: 0.4,
      freq: (t) => 300 + 160 * sin(t * 2 * pi * 4).abs(),
      wave: triangle,
      volume: 0.18,
      attack: 0,
      release: 0,
    );

  // Background siren (loopable, 0.8 s): the arcade's ever-present wail.
  out['siren_loop'] = Track(0.8)
    ..tone(
      start: 0,
      duration: 0.8,
      freq: (t) => 380 + 220 * sin(t * 2 * pi) * sin(t * 2 * pi),
      wave: triangle,
      volume: 0.12,
      attack: 0,
      release: 0,
    );

  // Eat ghost: rising sweep.
  out['eat_ghost'] = Track(0.32)
    ..tone(
      start: 0,
      duration: 0.3,
      freq: (t) => 200 + 1400 * t * t,
      wave: square,
      volume: 0.2,
    );

  // Eyes returning home.
  out['eyes'] = Track(0.2)
    ..tone(
      start: 0,
      duration: 0.2,
      freq: (t) => 900 - 500 * t,
      wave: pulse25,
      volume: 0.08,
      attack: 0,
      release: 0.01,
    );

  // Bonus bracket eaten.
  final bonus = Track(0.34);
  for (final (i, n) in [72, 76, 79, 84].indexed) {
    bonus.note(i * 0.07, 0.07, midi(n), wave: triangle, volume: 0.35);
  }
  out['bonus'] = bonus;

  // Death: a descending "traceback" wobble, then two blips.
  final death = Track(1.6);
  death.tone(
    start: 0,
    duration: 1.2,
    freq: (t) => lerp(900, 120, t) * (1 + 0.12 * sin(t * 2 * pi * 11)),
    wave: square,
    volume: 0.18,
    release: 0.1,
  );
  death.note(1.28, 0.1, 160, volume: 0.2);
  death.note(1.43, 0.12, 120, volume: 0.2);
  out['death'] = death;

  // Extra life: bell ding-ding.
  final life = Track(0.7);
  for (var i = 0; i < 3; i++) {
    life.note(i * 0.2, 0.18, midi(88), wave: triangle, volume: 0.3);
  }
  out['extra_life'] = life;

  // Level cleared: "all tests passed" jingle.
  final clear = Track(1.3);
  const clearNotes = [67, 72, 76, 79, 76, 79, 84];
  for (final (i, n) in clearNotes.indexed) {
    final len = i == clearNotes.length - 1 ? 0.45 : 0.11;
    clear.note(i * 0.12, len, midi(n), wave: pulse25, volume: 0.22);
    clear.note(i * 0.12, len, midi(n - 12), wave: triangle, volume: 0.2);
  }
  out['level_complete'] = clear;

  // Game start jingle (~4 s, plays under "READY!").
  final start = Track(4.1);
  const beat = 0.13;
  const melody = [
    72, 84, 79, 76, 84, 79, 76, -1, 73, 85, 80, 77, 85, 80, 77, -1, //
    72, 84, 79, 76, 84, 79, 76, -1, 76, 77, 78, -1, 78, 79, 80, -1, //
    80, 81, 82, -1, 84, -1, -1, -1,
  ];
  const bass = [48, 60, 49, 61, 48, 60, 55, 57, 59, 60];
  for (final (i, n) in melody.indexed) {
    if (n > 0) start.note(i * beat * 0.75, beat * 0.7, midi(n), volume: 0.16);
  }
  for (final (i, n) in bass.indexed) {
    start.note(i * 0.39, 0.3, midi(n), wave: triangle, volume: 0.3);
  }
  out['start'] = start;

  // Game over: sad descending phrase.
  final over = Track(1.6);
  const overNotes = [67, 66, 65, 64];
  for (final (i, n) in overNotes.indexed) {
    final len = i == 3 ? 0.7 : 0.25;
    over.note(i * 0.28, len, midi(n), wave: square, volume: 0.16);
    over.note(i * 0.28, len, midi(n - 24), wave: triangle, volume: 0.25);
  }
  out['game_over'] = over;

  // UI click and achievement chime.
  out['click'] = Track(0.05)..note(0, 0.045, 1320, wave: pulse25, volume: 0.15);
  final ach = Track(0.45)
    ..note(0, 0.12, midi(83), wave: triangle, volume: 0.35)
    ..note(0.12, 0.3, midi(88), wave: triangle, volume: 0.35);
  out['achievement'] = ach;

  // Menu music: a loopable 4-bar chiptune (Am - F - C - G) at 132 bpm.
  const bpm = 132.0;
  const sixteenth = 60 / bpm / 4;
  const bars = 4;
  final music = Track(bars * 16 * sixteenth);
  const chords = [
    [57, 60, 64], // Am
    [53, 57, 60], // F
    [48, 52, 55], // C
    [55, 59, 62], // G
  ];
  const lead = [
    76, -1, 74, 76, -1, 72, -1, 69, 72, -1, 74, -1, 76, -1, -1, -1, //
    77, -1, 76, 74, -1, 72, -1, 69, 72, -1, 69, -1, 65, -1, -1, -1, //
    72, -1, 74, 76, -1, 79, -1, 76, 74, -1, 72, -1, 67, -1, -1, -1, //
    71, -1, 72, 74, -1, 79, -1, 74, 71, -1, 67, -1, 71, -1, 74, -1,
  ];
  for (var bar = 0; bar < bars; bar++) {
    final chord = chords[bar];
    for (var s = 0; s < 16; s++) {
      final t = (bar * 16 + s) * sixteenth;
      // Arpeggio.
      music.note(
        t,
        sixteenth * 0.9,
        midi(chord[s % 3] + 12),
        wave: pulse25,
        volume: 0.07,
        release: 0.02,
      );
      // Bass on eighths.
      if (s.isEven) {
        music.note(
          t,
          sixteenth * 1.8,
          midi(chord[0] - 12 + (s % 8 == 6 ? 7 : 0)),
          wave: triangle,
          volume: 0.28,
        );
      }
      // Hi-hat.
      if (s % 4 == 2) {
        music.tone(
          start: t,
          duration: 0.03,
          freq: (_) => 1,
          wave: noise,
          volume: 0.05,
          attack: 0,
          release: 0.02,
        );
      }
      final n = lead[bar * 16 + s];
      if (n > 0) {
        var len = 1;
        while (bar * 16 + s + len < lead.length &&
            lead[bar * 16 + s + len] < 0 &&
            len < 3) {
          len++;
        }
        music.note(
          t,
          sixteenth * len * 0.95,
          midi(n),
          wave: square,
          volume: 0.09,
          release: 0.04,
        );
      }
    }
  }
  out['menu_music'] = music;

  return out;
}

void main() {
  final dir = Directory('assets/audio')..createSync(recursive: true);
  var total = 0;
  for (final entry in buildAll().entries) {
    final bytes = entry.value.toWav();
    File('${dir.path}/${entry.key}.wav').writeAsBytesSync(bytes);
    total += bytes.length;
    stdout.writeln(
      '${entry.key}.wav  ${(bytes.length / 1024).toStringAsFixed(1)} KB',
    );
  }
  stdout.writeln('Total: ${(total / 1024).toStringAsFixed(1)} KB');
}
