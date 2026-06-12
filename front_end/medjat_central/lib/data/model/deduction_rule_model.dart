/// A single rung of the late-arrival deduction ladder: when an employee's
/// late minutes reach [thresholdMinutes], [deductionDays] (a fraction of a
/// working day) is deducted. The highest matching rung wins.
class LateTier {
  final int? id;
  final int thresholdMinutes;
  final double deductionDays;

  const LateTier({
    this.id,
    required this.thresholdMinutes,
    required this.deductionDays,
  });

  factory LateTier.fromJson(Map<String, dynamic> json) => LateTier(
    id: (json['id'] as num?)?.toInt(),
    thresholdMinutes: (json['threshold_minutes'] as num?)?.toInt() ?? 0,
    deductionDays: (json['deduction_days'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'threshold_minutes': thresholdMinutes,
    'deduction_days': deductionDays,
  };

  LateTier copyWith({int? thresholdMinutes, double? deductionDays}) => LateTier(
    id: id,
    thresholdMinutes: thresholdMinutes ?? this.thresholdMinutes,
    deductionDays: deductionDays ?? this.deductionDays,
  );
}

/// Tenant-level deduction configuration: the late-tier ladder plus the absence
/// rate (days deducted per absent day).
class DeductionConfig {
  final List<LateTier> tiers;
  final double absenceDays;

  const DeductionConfig({this.tiers = const [], this.absenceDays = 1.5});

  factory DeductionConfig.fromJson(Map<String, dynamic> json) {
    final rawTiers = json['tiers'];
    final tiers = rawTiers is List
        ? rawTiers
              .map((e) => LateTier.fromJson(e as Map<String, dynamic>))
              .toList()
        : <LateTier>[];
    tiers.sort((a, b) => a.thresholdMinutes.compareTo(b.thresholdMinutes));
    return DeductionConfig(
      tiers: tiers,
      absenceDays: (json['absence_days'] as num?)?.toDouble() ?? 1.5,
    );
  }
}
