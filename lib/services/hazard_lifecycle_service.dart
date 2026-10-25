import '../domain/models/hazard_status.dart';

class HazardLifecycleService {
  static const Map<HazardStatus, Set<HazardStatus>> transitions = {
    HazardStatus.unverified: {
      HazardStatus.verified,
      HazardStatus.rejected,
      HazardStatus.expired,
    },
    HazardStatus.verified: {
      HazardStatus.closureRequested,
      HazardStatus.expired,
    },
    HazardStatus.closureRequested: {
      HazardStatus.verified,
      HazardStatus.repaired,
    },
    HazardStatus.repaired: {},
    HazardStatus.rejected: {},
    HazardStatus.expired: {},
  };

  bool canTransition(
    HazardStatus current,
    HazardStatus next,
  ) {
    return transitions[current]?.contains(next) ?? false;
  }
}