import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/device_data/device_data.dart';
import '../../../data/model/branch_model.dart';

/// Importing a punch export from a terminal that cannot reach us.
///
/// Deliberately two steps. A bulk import is the one action here whose mistakes
/// are both large and invisible — a file read with the day and month swapped
/// files a whole month of attendance on the wrong dates and nothing looks
/// broken. So the file is always parsed and described first, and only written
/// after the admin has seen what was understood.
class ImportPunchesController extends GetxController {
  final DeviceData _deviceData = Get.find<DeviceData>();
  final BranchData _branchData = Get.find<BranchData>();

  StatusRequest status = StatusRequest.none;
  List<BranchModel> branches = [];
  int? branchId;

  File? file;
  String? fileName;

  bool busy = false;
  ImportPreview? preview;
  ImportResult? result;
  String? error;

  bool get canPreview => file != null && branchId != null && !busy;

  @override
  void onInit() {
    super.onInit();
    loadBranches();
  }

  Future<void> loadBranches() async {
    status = StatusRequest.loading;
    update();

    final response = await _branchData.getBranches();
    if (response['status'] == StatusRequest.success) {
      final data = _unwrap(response['data']);
      final list = data is Map ? data['branches'] : null;
      branches = list is List
          ? list
              .whereType<Map<dynamic, dynamic>>()
              .map((e) => BranchModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [];
      if (branches.length == 1) {
        branchId = branches.first.id;
      }
      status = StatusRequest.success;
    } else {
      status = response['status'] as StatusRequest;
    }
    update();
  }

  void selectBranch(int? id) {
    branchId = id;
    // The branch decides where the punches land, so a change invalidates a
    // preview taken against the previous one.
    preview = null;
    result = null;
    update();
  }

  Future<void> pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt', 'dat', 'tsv'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    file = File(path);
    fileName = picked!.files.single.name;
    preview = null;
    result = null;
    error = null;
    update();
  }

  void clearFile() {
    file = null;
    fileName = null;
    preview = null;
    result = null;
    error = null;
    update();
  }

  Future<void> runPreview() async {
    if (!canPreview) return;
    busy = true;
    error = null;
    update();

    final response = await _deviceData.importPunches(
      file: file!,
      branchId: branchId,
      preview: true,
    );

    busy = false;
    if (response['status'] == StatusRequest.success) {
      final data = _unwrap(response['data']);
      preview = data is Map
          ? ImportPreview.fromJson(Map<String, dynamic>.from(data))
          : null;
    } else {
      error = (response['message'] as String?) ?? 'import_failed'.tr;
    }
    update();
  }

  Future<void> confirmImport() async {
    if (file == null || branchId == null || busy) return;
    busy = true;
    error = null;
    update();

    final response = await _deviceData.importPunches(
      file: file!,
      branchId: branchId,
    );

    busy = false;
    if (response['status'] == StatusRequest.success) {
      final data = _unwrap(response['data']);
      result = data is Map
          ? ImportResult.fromJson(Map<String, dynamic>.from(data))
          : null;
      preview = null;
    } else {
      error = (response['message'] as String?) ?? 'import_failed'.tr;
    }
    update();
  }

  void reset() {
    clearFile();
    update();
  }

  dynamic _unwrap(dynamic data) {
    if (data is Map && data['data'] is Map) return data['data'];
    return data;
  }
}

int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class ImportPreview {
  final int readableRows;
  final int unreadableRows;
  final int distinctUsers;
  final String firstPunch;
  final String lastPunch;
  final String dateOrder;
  final bool dateOrderAmbiguous;

  const ImportPreview({
    required this.readableRows,
    required this.unreadableRows,
    required this.distinctUsers,
    required this.firstPunch,
    required this.lastPunch,
    required this.dateOrder,
    required this.dateOrderAmbiguous,
  });

  factory ImportPreview.fromJson(Map<String, dynamic> json) => ImportPreview(
        readableRows: _toInt(json['readable_rows']),
        unreadableRows: _toInt(json['unreadable_rows']),
        distinctUsers: _toInt(json['distinct_users']),
        firstPunch: '${json['first_punch'] ?? ''}',
        lastPunch: '${json['last_punch'] ?? ''}',
        dateOrder: '${json['date_order'] ?? 'dmy'}',
        dateOrderAmbiguous: json['date_order_ambiguous'] == true,
      );
}

class ImportResult {
  final int readRows;
  final int applied;
  final int unmatched;
  final int alreadyImported;
  final int ignored;
  final int unlinkedUsers;

  const ImportResult({
    required this.readRows,
    required this.applied,
    required this.unmatched,
    required this.alreadyImported,
    required this.ignored,
    required this.unlinkedUsers,
  });

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    final results = json['results'];
    final map = results is Map
        ? Map<String, dynamic>.from(results)
        : const <String, dynamic>{};
    return ImportResult(
      readRows: _toInt(json['read_rows']),
      applied: _toInt(map['applied']),
      unmatched: _toInt(map['unmatched']),
      ignored: _toInt(map['ignored']),
      alreadyImported: _toInt(json['already_imported']),
      unlinkedUsers: _toInt(json['unlinked_users']),
    );
  }
}
