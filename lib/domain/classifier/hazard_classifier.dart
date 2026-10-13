import '../models/hazard_result.dart';
import '../models/sensor_window.dart';

abstract class HazardClassifier {
  HazardResult classify(SensorWindow window);
}
