import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/model/employee_model.dart';
import '../../../logic/controller/shift/shift_controller.dart';
import '../../../core/shared/buttons/primary_button.dart';

class AssignShiftScreen extends StatelessWidget {
  const AssignShiftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shiftCtrl = Get.find<ShiftController>();
    final colors = AppColors.of(context);
    final selectedShift = Rxn<int>();
    final selectedEmployees = <int>[].obs;
    final isLoading = false.obs;
    final employees = <EmployeeModel>[].obs;
    final empStatus = StatusRequest.none.obs;

    _loadEmployees(employees, empStatus);

    return Scaffold(
      appBar: AppBar(title: Text('assign_employees_to_shift'.tr)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('select_shift'.tr,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: AppSpacing.s2),
                GetBuilder<ShiftController>(
                  builder: (_) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s3),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: colors.borderHairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedShift.value,
                          hint: Text('select_shift'.tr,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 14,
                                color: colors.textSecondary,
                              )),
                          isExpanded: true,
                          icon: Icon(Icons.expand_more,
                              color: colors.textTertiary),
                          items: shiftCtrl.shifts.map((s) {
                            return DropdownMenuItem<int>(
                              value: s.id,
                              child: Text(
                                '${s.name} (${_formatTime(s.startTime)} - ${_formatTime(s.endTime)})',
                                style: const TextStyle(
                                  fontFamily: 'IBM Plex Sans Arabic',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => selectedShift.value = v,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (empStatus.value == StatusRequest.loading) {
                return const Center(child: CircularProgressIndicator.adaptive());
              }
              if (employees.isEmpty) {
                return Center(
                  child: Text('no_employees'.tr,
                      style: AppTextStyles.bodySecondary(context)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s4),
                itemCount: employees.length,
                itemBuilder: (_, i) {
                  final emp = employees[i];
                  return Obx(() {
                    final isSelected =
                        selectedEmployees.contains(emp.id);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(
                        emp.name,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: emp.shiftName != null
                          ? Text(
                              emp.shiftName!,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            )
                          : null,
                      onChanged: (v) {
                        if (v == true) {
                          selectedEmployees.add(emp.id);
                        } else {
                          selectedEmployees.remove(emp.id);
                        }
                      },
                      controlAffinity:
                          ListTileControlAffinity.leading,
                      dense: true,
                    );
                  });
                },
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Obx(() => PrimaryButton(
                  text: 'assign_selected'.tr,
                  isLoading: isLoading.value,
                  enabled: selectedShift.value != null &&
                      selectedEmployees.isNotEmpty,
                  onPressed: () async {
                    if (selectedShift.value == null) return;
                    isLoading.value = true;
                    final count = await shiftCtrl.assignEmployees(
                      selectedShift.value!,
                      selectedEmployees.toList(),
                    );
                    isLoading.value = false;
                    if (count > 0) {
                      Get.snackbar(
                        'done'.tr,
                        'shift_assigned_success'.tr,
                        snackPosition: SnackPosition.BOTTOM,
                      );
                      Get.back(result: true);
                    }
                  },
                )),
          ),
        ],
      ),
    );
  }

  void _loadEmployees(
      RxList<EmployeeModel> employees, Rx<StatusRequest> empStatus) async {
    empStatus.value = StatusRequest.loading;
    final empData = Get.find<EmployeeData>();
    final response = await empData.getEmployees();
    if (response['status'] == StatusRequest.success) {
      final raw = response['data'];
      dynamic payload = raw;
      if (payload is Map && payload['data'] != null) payload = payload['data'];
      List<dynamic>? items;
      if (payload is List) {
        items = payload;
      } else if (payload is Map) {
        for (final key in const ['items', 'records', 'list', 'data']) {
          if (payload[key] is List) {
            items = payload[key] as List;
            break;
          }
        }
      }
      if (items != null) {
        employees.value = items
            .whereType<Map<String, dynamic>>()
            .map(EmployeeModel.fromJson)
            .toList();
      }
      empStatus.value = StatusRequest.success;
    } else {
      empStatus.value = StatusRequest.failure;
    }
  }

  String _formatTime(String t) {
    final parts = t.split(':');
    return '${parts[0]}:${parts[1]}';
  }
}
