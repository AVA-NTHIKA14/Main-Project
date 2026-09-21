import '../models/sensor_sample.dart';
import '../models/sensor_window.dart';

abstract class SensorPreprocessor {
  SensorWindow alignToVehicleFrame(SensorWindow raw);
}

class GravityVectorRemovalPreprocessor implements SensorPreprocessor {
  const GravityVectorRemovalPreprocessor({this.alpha = 0.8});

  final double alpha;

  @override
  SensorWindow alignToVehicleFrame(SensorWindow raw) {
    if (raw.samples.isEmpty) {
      return raw;
    }

    var gravityX = 0.0;
    var gravityY = 0.0;
    var gravityZ = 0.0;
    final filteredSamples = <SensorSample>[];

    for (final sample in raw.samples) {
      gravityX = alpha * gravityX + (1 - alpha) * sample.ax;
      gravityY = alpha * gravityY + (1 - alpha) * sample.ay;
      gravityZ = alpha * gravityZ + (1 - alpha) * sample.az;
      filteredSamples.add(
        SensorSample(
          ax: sample.ax - gravityX,
          ay: sample.ay - gravityY,
          az: sample.az - gravityZ,
          gx: sample.gx,
          gy: sample.gy,
          gz: sample.gz,
          timestamp: sample.timestamp,
        ),
      );
    }

    return SensorWindow(
      samples: filteredSamples,
      gpsFix: raw.gpsFix,
      windowStart: raw.windowStart,
      windowEnd: raw.windowEnd,
    );
  }
}

// TODO(ML team): replace with proper orientation estimation (Madgwick/Kalman) — this is a known hard problem.
