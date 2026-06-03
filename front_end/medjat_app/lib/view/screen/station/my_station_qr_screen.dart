import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/class/status_request.dart';
import '../../../../data/data_source/remote/station_data/station_data.dart';

class MyStationQrScreen extends StatefulWidget {
  const MyStationQrScreen({super.key});

  @override
  State<MyStationQrScreen> createState() => _MyStationQrScreenState();
}

class _MyStationQrScreenState extends State<MyStationQrScreen> {
  final _stationData = Get.find<StationData>();
  String? _qrToken;
  int _expiresIn = 30;
  Timer? _refreshTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQr();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadQr() async {
    try {
      final response = await _stationData.getMyStationQr();
      if (response['status'] == StatusRequest.success) {
        final data = response['data'] as Map<String, dynamic>?;
        setState(() {
          _qrToken = data?['qr_token'] as String?;
          _expiresIn = (data?['expires_in'] as int?) ?? 30;
          _isLoading = false;
        });
        _startCountdown();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _startCountdown() {
    _refreshTimer?.cancel();
    int remaining = _expiresIn;

    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      if (remaining <= 0) {
        timer.cancel();
        _loadQr();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('my_station_qr'.tr)),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _qrToken == null
                ? _buildError(context)
                : _buildQr(context),
      ),
    );
  }

  Widget _buildQr(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_2, size: 48, color: AppColors.brand(context)),
          const SizedBox(height: 16),
          Text('show_qr_kiosk'.tr, style: AppTextStyles.h3(context)),
          const SizedBox(height: 8),
          Text('qr_auto_refresh'.tr, style: AppTextStyles.bodySecondary(context)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: _qrToken!,
              size: 250,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _isLoading = true);
              _loadQr();
            },
            icon: const Icon(Icons.refresh),
            label: Text('refresh_qr'.tr),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand(context),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text('qr_unavailable'.tr, style: AppTextStyles.bodySecondary(context)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() => _isLoading = true);
            _loadQr();
          },
          child: Text('retry'.tr),
        ),
      ],
    );
  }
}
