import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../storage/kiosk_token_store.dart';
import 'kiosk_result.dart';

/// Every call the kiosk makes to the backend.
///
/// Two rules, both load-bearing:
///
/// 1. **Everything is POST.** Writes require POST across this backend
///    (`Auth::requirePost`), and the reads are kept consistent with their
///    neighbours rather than split across two verbs.
/// 2. **The kiosk token is not an employee token.** It goes in `X-Kiosk-Token`
///    and resolves to a branch, never to a person. No endpoint reachable from
///    this app accepts `X-Employee-Token`, which is what stops the tablet from
///    ever acting as one particular employee.
class KioskCrud {
  KioskCrud({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 15);

  /// Longer: these carry a base64 capture upstream.
  static const Duration _uploadTimeout = Duration(seconds: 30);

  Map<String, String> _baseHeaders() {
    final securityUser = dotenv.env['SECURITY_USER'] ?? '';
    final securityKey = dotenv.env['SECURITY_KEY'] ?? '';
    final basicAuth =
        'Basic ${base64Encode(utf8.encode('$securityUser:$securityKey'))}';
    return {
      'Authorization': basicAuth,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<Map<String, String>> _headers({String? adminSession}) async {
    final headers = _baseHeaders();

    final token = await KioskTokenStore.getToken();
    if (token != null && token.isNotEmpty) {
      headers['X-Kiosk-Token'] = token;
    }
    if (adminSession != null && adminSession.isNotEmpty) {
      headers['X-Kiosk-Admin-Session'] = adminSession;
    }
    return headers;
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// POSTs [body] to [url].
  ///
  /// [authenticated] is false only for `pair.php`, where the pairing code *is*
  /// the credential and no token exists yet.
  Future<KioskResult> post(
    String url,
    Map<String, dynamic> body, {
    bool authenticated = true,
    String? adminSession,
    bool isUpload = false,
  }) async {
    if (!await _isOnline()) {
      // Connectivity is checked before the request rather than inferred from a
      // timeout: a worker at a door should be told in a second, not in fifteen.
      return const KioskResult(status: KioskStatus.offline);
    }

    try {
      final headers = authenticated
          ? await _headers(adminSession: adminSession)
          : _baseHeaders();

      final response = await _client
          .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(isUpload ? _uploadTimeout : _timeout);

      return _interpret(response);
    } catch (e) {
      debugPrint('KioskCrud POST failed: $url — $e');
      return const KioskResult(status: KioskStatus.failure);
    }
  }

  KioskResult _interpret(http.Response response) {
    Map<String, dynamic> decoded = const {};
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map<String, dynamic>) decoded = parsed;
    } catch (_) {
      // An HTML error page from nginx, or a truncated body. Fall through to the
      // status-code mapping below, which is still meaningful.
    }

    final messageKey = decoded['message_key'] as String? ??
        decoded['message'] as String?;
    final data = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : decoded;

    // A failed identification is a 200 with an `outcome` — a normal result of a
    // normal interaction, not an error. Only transport and policy failures are
    // encoded in the status line.
    switch (response.statusCode) {
      case >= 200 && < 300:
        return KioskResult(
          status: KioskStatus.success,
          data: data,
          messageKey: messageKey,
          httpStatus: response.statusCode,
        );

      case 401:
        return KioskResult(
          status: KioskStatus.unauthorised,
          messageKey: messageKey,
          httpStatus: 401,
        );

      case 426:
        return KioskResult(
          status: KioskStatus.updateRequired,
          data: data,
          messageKey: messageKey,
          httpStatus: 426,
        );

      case 503:
        return KioskResult(
          status: KioskStatus.maintenance,
          messageKey: messageKey,
          httpStatus: 503,
        );

      case 410:
        return KioskResult(
          status: KioskStatus.codeSpent,
          messageKey: messageKey,
          httpStatus: 410,
        );

      case 429:
        return KioskResult(
          status: KioskStatus.throttled,
          messageKey: messageKey,
          httpStatus: 429,
        );

      case 403:
      case 409:
      case 422:
        return KioskResult(
          status: KioskStatus.refused,
          data: data,
          messageKey: messageKey,
          httpStatus: response.statusCode,
        );

      default:
        return KioskResult(
          status: KioskStatus.failure,
          messageKey: messageKey,
          httpStatus: response.statusCode,
        );
    }
  }

  void dispose() => _client.close();
}
