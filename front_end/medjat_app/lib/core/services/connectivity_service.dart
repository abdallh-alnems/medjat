import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class ConnectivityService extends GetxService {
  final _isOnline = true.obs;
  bool get isOnline => _isOnline.value;
  Stream<bool> get onConnectivityChanged => _connectivityStream.stream;

  final _connectivityStream = StreamController<bool>.broadcast();
  StreamSubscription? _subscription;

  @override
  void onInit() {
    super.onInit();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      final wasOffline = !_isOnline.value;
      _isOnline.value = online;
      _connectivityStream.add(online);
      if (online && wasOffline) {
        _connectivityStream.add(true);
      }
    });
    _checkInitial();
  }

  Future<void> _checkInitial() async {
    final results = await Connectivity().checkConnectivity();
    _isOnline.value = results.any((r) => r != ConnectivityResult.none);
  }

  static Future<bool> checkOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _connectivityStream.close();
    super.onClose();
  }
}
