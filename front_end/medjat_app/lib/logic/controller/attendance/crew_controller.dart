import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/class/api_messages.dart';
import '../../../core/class/status_request.dart';
import '../../../core/services/device_integrity_service.dart';
import '../../../core/services/location_service.dart';
import '../../../data/data_source/remote/attendance_data/crew_data.dart';
import '../../../data/model/crew_member_model.dart';

/// The supervisor's side of crew attendance.
///
/// Everything here is about one person recording for several others, which is
/// why the selection lives in the controller rather than the screen: a foreman
/// ticking twenty names over a couple of minutes on a bad connection must not
/// lose the ticks to a rebuild.
class CrewController extends GetxController {
  final CrewData _crewData = Get.find<CrewData>();

  StatusRequest status = StatusRequest.none;
  String? errorMessage;

  List<CrewMemberModel> members = [];
  bool isSupervisor = false;
  bool photoRequired = false;

  /// Ids the supervisor has ticked.
  final Set<int> selected = <int>{};

  bool isSubmitting = false;

  /// Result of the last submission, kept so the screen can say "28 recorded,
  /// 2 already marked" instead of a bare success that hides what did not happen.
  int lastRecordedCount = 0;
  Map<String, dynamic> lastSkipped = const {};

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// True when the crew's day has not started — decides whether the button
  /// records arrival or departure.
  ///
  /// Read from the SELECTION, not the whole crew: a supervisor who ticks three
  /// people who are still clocked in is closing their day, even if the other
  /// twenty have not arrived.
  bool get isCheckOutMode {
    if (selected.isEmpty) return false;
    final picked = members.where((m) => selected.contains(m.id));
    return picked.isNotEmpty && picked.every((m) => m.isCheckedIn);
  }

  Future<void> load() async {
    status = StatusRequest.loading;
    errorMessage = null;
    update();

    final response = await _crewData.list();

    if (response['status'] == StatusRequest.success) {
      final data = _unwrap(response);
      if (data != null) {
        isSupervisor = data['is_supervisor'] == true;
        photoRequired = data['photo_required'] == true;
        members = (data['members'] as List? ?? [])
            .map((e) => CrewMemberModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();

        // Drop ticks for anybody no longer in the crew. Leaving them would send
        // an id the server refuses, and the whole batch is refused with it.
        selected.removeWhere((id) => !members.any((m) => m.id == id));

        status = StatusRequest.success;
        update();
        return;
      }
    }

    errorMessage = ApiMessages.of(response);
    status = StatusRequest.failure;
    update();
  }

  void toggle(int employeeId) {
    if (selected.contains(employeeId)) {
      selected.remove(employeeId);
    } else {
      selected.add(employeeId);
    }
    update();
  }

  /// Ticks everyone who still has something to record today.
  ///
  /// Skips finished days rather than selecting all: a supervisor who taps this
  /// and submits should not be told half the crew was "already marked" when the
  /// app knew that before sending.
  void selectAllActionable() {
    final actionable = members.where((m) => !m.isDayDone).map((m) => m.id);
    if (selected.length == actionable.length &&
        actionable.every(selected.contains)) {
      selected.clear();
    } else {
      selected
        ..clear()
        ..addAll(actionable);
    }
    update();
  }

  Future<void> submit() async {
    if (selected.isEmpty || isSubmitting) return;

    isSubmitting = true;
    errorMessage = null;
    update();

    try {
      final position = await LocationService().getCurrentPosition();

      // Reported, never trusted: the server decides what to do with it, and
      // only for companies that opted into rejecting spoofed locations.
      final integrity = await DeviceIntegrityService.check(position);

      String? photo;
      if (photoRequired) {
        photo = await _capturePhoto();
        if (photo == null) {
          // Cancelled the camera, or it failed. Say so instead of sending a
          // batch the server will refuse.
          errorMessage = 'crew_photo_needed'.tr;
          isSubmitting = false;
          update();
          return;
        }
      }

      final response = await _crewData.record(
        employeeIds: selected.toList(),
        latitude: position.latitude,
        longitude: position.longitude,
        isCheckOut: isCheckOutMode,
        isMockLocation: integrity.isMockLocation,
        photoBase64: photo,
      );

      if (response['status'] == StatusRequest.success) {
        final data = _unwrap(response) ?? {};
        lastRecordedCount = (data['count'] as num?)?.toInt() ?? 0;
        lastSkipped = data['skipped'] is Map
            ? Map<String, dynamic>.from(data['skipped'] as Map)
            : const {};

        selected.clear();
        isSubmitting = false;
        // Re-read rather than patching locally: the server is the only thing
        // that knows which rows actually changed.
        await load();
        return;
      }

      errorMessage = ApiMessages.of(response);
    } catch (_) {
      errorMessage = 'error_try_again'.tr;
    }

    isSubmitting = false;
    update();
  }

  /// One group photograph for the batch. Kept small on purpose — the server
  /// refuses anything over ~1.5 MB, and this is often sent on a weak signal.
  Future<String?> _capturePhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 70,
      );
      if (picked == null) return null;
      final bytes = await File(picked.path).readAsBytes();
      if (bytes.length > 1500000) return null;
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _unwrap(Map<String, dynamic> response) {
    dynamic data = response['data'];
    if (data is Map && data['data'] is Map) data = data['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }
}
