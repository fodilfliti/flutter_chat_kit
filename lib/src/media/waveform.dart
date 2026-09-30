import 'dart:math' as math;

/// Reduces [samples] (0..1) to [bars] values: the peak of each bucket,
/// scaled so the loudest bar is 1. Fewer samples than bars are stretched.
List<double> downsampleWaveform(List<double> samples, {int bars = 40}) {
  if (bars <= 0) return const [];
  if (samples.isEmpty) return List.filled(bars, 0);
  final out = List<double>.filled(bars, 0);
  for (var i = 0; i < bars; i++) {
    final start = (i * samples.length / bars).floor();
    final end = math.max(start + 1, ((i + 1) * samples.length / bars).floor());
    var peak = 0.0;
    for (var j = start; j < end && j < samples.length; j++) {
      peak = math.max(peak, samples[j]);
    }
    out[i] = peak.clamp(0, 1);
  }
  final top = out.reduce(math.max);
  if (top <= 0) return out;
  return [for (final v in out) v / top];
}

/// Maps a recorder level in dBFS (about -60 quiet .. 0 loud) to 0..1.
double normalizeDecibels(double dbfs, {double floor = -60}) {
  if (dbfs.isNaN || dbfs <= floor) return 0;
  if (dbfs >= 0) return 1;
  return (dbfs - floor) / -floor;
}
