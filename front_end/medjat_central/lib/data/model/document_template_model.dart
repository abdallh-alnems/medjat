import 'package:get/get.dart';

class DocumentTemplateModel {
  final int id;
  final String? templateKey;
  final String nameAr;
  final String? nameEn;
  final String bodyAr;
  final String? bodyEn;
  final bool isSystem;
  final bool isActive;
  final int sortOrder;

  DocumentTemplateModel({
    required this.id,
    this.templateKey,
    required this.nameAr,
    this.nameEn,
    required this.bodyAr,
    this.bodyEn,
    this.isSystem = false,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory DocumentTemplateModel.fromJson(Map<String, dynamic> json) {
    return DocumentTemplateModel(
      id: _toInt(json['id']),
      templateKey: json['template_key'] as String?,
      nameAr: (json['name_ar'] as String?) ?? '',
      nameEn: json['name_en'] as String?,
      bodyAr: (json['body_ar'] as String?) ?? '',
      bodyEn: json['body_en'] as String?,
      isSystem: _toBool(json['is_system']),
      isActive: _toBool(json['is_active']),
      sortOrder: _toInt(json['sort_order']),
    );
  }

  /// Localized display name: prefers Arabic, falls back to English.
  String get displayName {
    final locale = Get.locale?.languageCode ?? 'ar';
    if (locale == 'en' && (nameEn?.trim().isNotEmpty ?? false)) {
      return nameEn!;
    }
    return nameAr;
  }

  /// Whether this template expects a bank name (bank introduction letter).
  bool get needsBankName =>
      templateKey == 'bank_letter' || bodyAr.contains('{{bank_name}}');

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }
}
