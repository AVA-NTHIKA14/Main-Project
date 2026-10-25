import 'package:flutter_test/flutter_test.dart';
import 'package:road_loop/domain/models/hazard_status.dart';
import 'package:road_loop/services/hazard_lifecycle_service.dart';

void main() {
group('HazardLifecycleService', () {
final service = HazardLifecycleService();


test('allows an unverified hazard to become verified', () {
  expect(
    service.canTransition(
      HazardStatus.unverified,
      HazardStatus.verified,
    ),
    isTrue,
  );
});

test('allows a verified hazard to request closure', () {
  expect(
    service.canTransition(
      HazardStatus.verified,
      HazardStatus.closureRequested,
    ),
    isTrue,
  );
});

test('prevents an unverified hazard from being repaired', () {
  expect(
    service.canTransition(
      HazardStatus.unverified,
      HazardStatus.repaired,
    ),
    isFalse,
  );
});

test('prevents a repaired hazard from reopening automatically', () {
  expect(
    service.canTransition(
      HazardStatus.repaired,
      HazardStatus.verified,
    ),
    isFalse,
  );
});


});
}
