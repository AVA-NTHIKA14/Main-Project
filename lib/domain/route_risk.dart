import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'route_hazard_matcher.dart';

/// Configurable criteria to determine whether a hazard is eligible for route
/// hazard scoring and warnings.
@immutable
class HazardEligibilityFilter {
  const HazardEligibilityFilter({
    this.maxAge = defaultMaxAge,
    this.minimumConfidence = defaultMinimumConfidence,
  });

  /// Default staleness threshold: hazards not observed within the last 7 days are excluded.
  static const Duration defaultMaxAge = Duration(days: 7);

  /// Default minimum confidence threshold (0.0 to 1.0).
  static const double defaultMinimumConfidence = 0.7;

  final Duration maxAge;
  final double minimumConfidence;

  /// Determines whether [hazard] is eligible for route scoring and alerts at [now].
  ///
  /// Criteria:
  /// 1. Not stale (last observed within [maxAge]).
  /// 2. Confidence is at or above [minimumConfidence].
  bool isEligible(RouteHazardPoint hazard, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final age = currentTime.difference(hazard.lastObserved);
    if (age > maxAge) return false;
    if (hazard.confidence < minimumConfidence) return false;
    return true;
  }
}

/// Represents the evaluated risk for a calculated route based on matched hazards.
///
/// IMPORTANT: Route risk scores are relative ranking aids for route comparison
/// and do NOT represent validated physical accident probabilities. No route can
/// ever be claimed as completely "safe" or guaranteed free of road hazards.
@immutable
class RouteRisk {
  const RouteRisk({
    required this.matchedHazards,
    required this.eligibleHazards,
    required this.score,
    required this.highSeverityCount,
  });

  /// An empty risk evaluation when no hazards are matched.
  static const RouteRisk zero = RouteRisk(
    matchedHazards: [],
    eligibleHazards: [],
    score: 0.0,
    highSeverityCount: 0,
  );

  /// All hazards matched to the route geometry within the distance threshold.
  final List<RouteHazardMatch> matchedHazards;

  /// The subset of matched hazards that meet eligibility criteria (not stale, sufficient confidence).
  final List<RouteHazardMatch> eligibleHazards;

  /// Composite risk score: sum(severityWeight * confidence) over eligible hazards.
  /// Used solely as a relative ranking aid between alternative routes.
  final double score;

  /// Number of high-severity eligible hazards on the route.
  final int highSeverityCount;

  bool get hasHighSeverityHazard => highSeverityCount > 0;
  bool get hasHazards => eligibleHazards.isNotEmpty;

  /// Earliest eligible hazard along the route, if any.
  RouteHazardMatch? get firstHazard =>
      eligibleHazards.isEmpty ? null : eligibleHazards.first;

  /// Earliest eligible high-severity hazard along the route, if any.
  RouteHazardMatch? get firstHighSeverityHazard {
    for (final match in eligibleHazards) {
      if (match.hazard.severityWeight >= 3.0 ||
          match.hazard.severityLabel.toLowerCase() == 'high') {
        return match;
      }
    }
    return null;
  }

  @override
  String toString() =>
      'RouteRisk(score: ${score.toStringAsFixed(2)}, eligible: ${eligibleHazards.length}, highSeverity: $highSeverityCount)';
}

/// Evaluates alternative route trade-offs against the baseline (fastest) route.
@immutable
class RouteTradeOff {
  const RouteTradeOff({
    required this.routeIndex,
    required this.extraMinutes,
    required this.extraPercentage,
    required this.riskScoreDiff,
    required this.hazardsAvoided,
    required this.tradeOffText,
    required this.isRecommended,
  });

  final int routeIndex;
  final int extraMinutes;
  final double extraPercentage;
  final double riskScoreDiff;
  final int hazardsAvoided;
  final String tradeOffText;
  final bool isRecommended;
}

/// Calculates risk scores for routes by filtering eligible hazards and summing weights.
class RouteRiskCalculator {
  const RouteRiskCalculator({
    this.filter = const HazardEligibilityFilter(),
    this.maxExtraMinutes = 5,
    this.maxExtraPercentage = 0.20,
  });

  final HazardEligibilityFilter filter;
  final int maxExtraMinutes;
  final double maxExtraPercentage;

  /// Evaluates risk for a list of [matches] along a route at [now].
  RouteRisk calculateRisk(List<RouteHazardMatch> matches, {DateTime? now}) {
    if (matches.isEmpty) {
      return RouteRisk.zero;
    }

    final eligible = <RouteHazardMatch>[];
    var totalScore = 0.0;
    var highSeverity = 0;

    for (final match in matches) {
      if (filter.isEligible(match.hazard, now: now)) {
        eligible.add(match);
        // Relative ranking aid formula: severityWeight * confidence
        totalScore += match.hazard.severityWeight * match.hazard.confidence;
        if (match.hazard.severityWeight >= 3.0 ||
            match.hazard.severityLabel.toLowerCase() == 'high') {
          highSeverity++;
        }
      }
    }

    return RouteRisk(
      matchedHazards: matches,
      eligibleHazards: eligible,
      score: totalScore,
      highSeverityCount: highSeverity,
    );
  }

  /// Evaluates trade-off of an alternative route compared to the fastest baseline route.
  RouteTradeOff evaluateTradeOff({
    required int routeIndex,
    required double baselineDurationSeconds,
    required RouteRisk baselineRisk,
    required double alternativeDurationSeconds,
    required RouteRisk alternativeRisk,
  }) {
    final extraSeconds = math.max(
      0.0,
      alternativeDurationSeconds - baselineDurationSeconds,
    );
    final extraMinutes = (extraSeconds / 60.0).round();
    final extraPercentage = baselineDurationSeconds > 0
        ? extraSeconds / baselineDurationSeconds
        : 0.0;

    final hazardsAvoided =
        baselineRisk.eligibleHazards.length -
        alternativeRisk.eligibleHazards.length;
    final riskDiff = baselineRisk.score - alternativeRisk.score;

    // Recommend lower-risk alternative only if extra time is under limit: min(5 min, 20%)
    final underTimeLimit =
        extraMinutes <= maxExtraMinutes &&
        extraPercentage <= maxExtraPercentage;
    final isLowerRisk =
        riskDiff > 0.1 || (hazardsAvoided > 0 && riskDiff >= 0.0);
    final isRecommended = isLowerRisk && underTimeLimit;

    String tradeOffText;
    if (hazardsAvoided > 0) {
      tradeOffText =
          '+$extraMinutes min, avoids $hazardsAvoided hazard${hazardsAvoided == 1 ? '' : 's'}';
    } else if (extraMinutes == 0) {
      tradeOffText =
          'Same time, relative risk ${alternativeRisk.score.toStringAsFixed(1)}';
    } else {
      tradeOffText = '+$extraMinutes min';
    }

    return RouteTradeOff(
      routeIndex: routeIndex,
      extraMinutes: extraMinutes,
      extraPercentage: extraPercentage,
      riskScoreDiff: riskDiff,
      hazardsAvoided: hazardsAvoided,
      tradeOffText: tradeOffText,
      isRecommended: isRecommended,
    );
  }
}
