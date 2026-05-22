import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/station_recognition_log_model.dart';

void main() {
  group('StationRecognitionLogModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'station_id': 5,
        'station_name': 'المحطة 1',
        'matched_employee_id': 10,
        'employee_name': 'أحمد',
        'verification_method': 'face',
        'confidence_score': 0.92,
        'result': 'success',
        'failure_reason': null,
        'created_at': '2025-06-01T08:30:00Z',
      };

      final log = StationRecognitionLogModel.fromJson(json);

      expect(log.id, 1);
      expect(log.stationId, 5);
      expect(log.stationName, 'المحطة 1');
      expect(log.matchedEmployeeId, 10);
      expect(log.employeeName, 'أحمد');
      expect(log.verificationMethod, 'face');
      expect(log.confidenceScore, 0.92);
      expect(log.result, 'success');
      expect(log.failureReason, isNull);
      expect(log.createdAt, isNotNull);
    });

    test('بيانات ناقصة', () {
      final log = StationRecognitionLogModel.fromJson({});

      expect(log.id, 0);
      expect(log.stationId, 0);
      expect(log.stationName, '');
      expect(log.matchedEmployeeId, isNull);
      expect(log.employeeName, isNull);
      expect(log.verificationMethod, '');
      expect(log.confidenceScore, isNull);
      expect(log.result, '');
    });

    test('resultLabel — success', () {
      final log = StationRecognitionLogModel.fromJson({'result': 'success'});
      expect(log.resultLabel, 'recognition_success');
    });

    test('resultLabel — low_confidence', () {
      final log = StationRecognitionLogModel.fromJson({'result': 'low_confidence'});
      expect(log.resultLabel, 'recognition_low_confidence');
    });

    test('resultLabel — no_match', () {
      final log = StationRecognitionLogModel.fromJson({'result': 'no_match'});
      expect(log.resultLabel, 'recognition_no_match');
    });

    test('resultLabel — spoofing_detected', () {
      final log = StationRecognitionLogModel.fromJson({'result': 'spoofing_detected'});
      expect(log.resultLabel, 'recognition_spoofing');
    });

    test('resultLabel — manual_fallback', () {
      final log = StationRecognitionLogModel.fromJson({'result': 'manual_fallback'});
      expect(log.resultLabel, 'recognition_manual');
    });

    test('resultLabel — unknown result', () {
      final log = StationRecognitionLogModel.fromJson({'result': 'other'});
      expect(log.resultLabel, 'other');
    });

    test('تاريخ غير صالح يستخدم now', () {
      final log = StationRecognitionLogModel.fromJson({'created_at': 'bad-date'});
      expect(log.createdAt, isNotNull);
    });
  });
}
