/// One person a supervisor may record attendance for.
///
/// Carries today's state alongside the name so the crew screen can show who is
/// already marked without a second request — a foreman on a site with one bar
/// of signal should pay for one round trip, not two.
class CrewMemberModel {
  final int id;
  final String name;
  final String? jobTitle;
  final String? profileImage;

  /// Null until somebody records their arrival today.
  final String? checkInTime;
  final String? checkOutTime;

  const CrewMemberModel({
    required this.id,
    required this.name,
    this.jobTitle,
    this.profileImage,
    this.checkInTime,
    this.checkOutTime,
  });

  bool get isCheckedIn => checkInTime != null && checkInTime!.isNotEmpty;
  bool get isCheckedOut => checkOutTime != null && checkOutTime!.isNotEmpty;

  /// Nothing left to record for this person today.
  bool get isDayDone => isCheckedIn && isCheckedOut;

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  factory CrewMemberModel.fromJson(Map<String, dynamic> json) {
    return CrewMemberModel(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      jobTitle: json['job_title']?.toString(),
      profileImage: json['profile_image']?.toString(),
      checkInTime: json['check_in_time']?.toString(),
      checkOutTime: json['check_out_time']?.toString(),
    );
  }
}
