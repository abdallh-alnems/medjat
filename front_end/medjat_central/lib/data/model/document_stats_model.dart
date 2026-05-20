class DocumentStatsModel {
  final int totalRequired;
  final int totalUploaded;
  final int totalMissing;
  final int totalExpired;
  final int totalExpiringSoon;

  DocumentStatsModel({
    this.totalRequired = 0,
    this.totalUploaded = 0,
    this.totalMissing = 0,
    this.totalExpired = 0,
    this.totalExpiringSoon = 0,
  });

  factory DocumentStatsModel.fromJson(Map<String, dynamic> json) {
    return DocumentStatsModel(
      totalRequired: (json['total_required'] as int?) ?? 0,
      totalUploaded: (json['total_uploaded'] as int?) ?? 0,
      totalMissing: (json['total_missing'] as int?) ?? 0,
      totalExpired: (json['total_expired'] as int?) ?? 0,
      totalExpiringSoon: (json['total_expiring_soon'] as int?) ?? 0,
    );
  }
}
