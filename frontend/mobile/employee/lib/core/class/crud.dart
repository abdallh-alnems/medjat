import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/token_storage_service.dart';
import 'status_request.dart';

typedef SessionExpiredCallback = void Function();

class CRUD {
  final http.Client _client;

  static SessionExpiredCallback? onSessionExpired;

  CRUD({http.Client? client}) : _client = client ?? http.Client();
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

  Future<Map<String, String>> _headers() async {
    final headers = _baseHeaders();
    final token = await TokenStorageService.getToken();
    if (token != null && token.isNotEmpty) {
      headers['X-Employee-Token'] = token;
    }
    return headers;
  }

  /// Builds the request URI, **keeping** any query string already baked into
  /// [url] and merging [queryParameters] on top of it.
  ///
  /// `Uri.replace(queryParameters: …)` overwrites the whole query, so calling
  /// it unconditionally erased the parameters carried by links such as
  /// `v1/payroll/me?month=2026-04&format=pdf` — the endpoint then fell back to
  /// its defaults (JSON, current month) and the caller silently got the wrong
  /// response.
  @visibleForTesting
  static Uri buildUri(String url, Map<String, dynamic>? queryParameters) {
    final uri = Uri.parse(url);
    if (queryParameters == null || queryParameters.isEmpty) return uri;

    return uri.replace(queryParameters: <String, String>{
      ...uri.queryParameters,
      for (final entry in queryParameters.entries)
        entry.key: entry.value.toString(),
    });
  }

  Future<StatusRequest> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final online = results.any((r) => r != ConnectivityResult.none);
    return online ? StatusRequest.none : StatusRequest.offline;
  }

  Future<Map<String, dynamic>> getData(String url,
      {Map<String, dynamic>? queryParameters}) async {
    final connectivity = await _checkConnectivity();
    if (connectivity == StatusRequest.offline) {
      return {'status': StatusRequest.offline};
    }

    try {
      final headers = await _headers();
      final response = await _client
          .get(buildUri(url, queryParameters), headers: headers)
          .timeout(const Duration(seconds: 15));

      return handleResponse(response);
    } catch (e) {
      debugPrint('GET Error: $e');
      return {'status': StatusRequest.failure};
    }
  }

  Future<Map<String, dynamic>> getBytes(String url,
      {Map<String, dynamic>? queryParameters}) async {
    final connectivity = await _checkConnectivity();
    if (connectivity == StatusRequest.offline) {
      return {'status': StatusRequest.offline};
    }

    try {
      final headers = await _headers();
      final response = await _client
          .get(buildUri(url, queryParameters), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // The content type travels with the bytes: a 200 does not guarantee a
        // binary payload — an endpoint can answer JSON (or an HTML error page)
        // with the same status, and the caller must be able to tell.
        return {
          'status': StatusRequest.success,
          'bytes': response.bodyBytes,
          'contentType': response.headers['content-type'] ?? '',
        };
      }
      return _errorFromStatus(response.statusCode);
    } catch (e) {
      debugPrint('GET BYTES Error: $e');
      return {'status': StatusRequest.failure};
    }
  }

  Future<Map<String, dynamic>> postData(String url, Map<String, dynamic> data,
      {bool auth = true}) async {
    final connectivity = await _checkConnectivity();
    if (connectivity == StatusRequest.offline) {
      return {'status': StatusRequest.offline};
    }

    try {
      final headers = auth ? await _headers() : _baseHeaders();
      final response = await _client
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      return handleResponse(response);
    } catch (e) {
      debugPrint('POST Error: $e');
      return {'status': StatusRequest.failure};
    }
  }

  Future<Map<String, dynamic>> putData(String url, Map<String, dynamic> data,
      {bool auth = true}) async {
    final connectivity = await _checkConnectivity();
    if (connectivity == StatusRequest.offline) {
      return {'status': StatusRequest.offline};
    }

    try {
      final headers = auth ? await _headers() : _baseHeaders();
      final response = await _client
          .put(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      return handleResponse(response);
    } catch (e) {
      debugPrint('PUT Error: $e');
      return {'status': StatusRequest.failure};
    }
  }

  /// PATCH — replaces part of a resource whose id is in the path.
  ///
  /// The API addresses resources rather than taking an action named "update",
  /// so the id does not travel in [data].
  Future<Map<String, dynamic>> patchData(String url, Map<String, dynamic> data,
      {bool auth = true}) async {
    final connectivity = await _checkConnectivity();
    if (connectivity == StatusRequest.offline) {
      return {'status': StatusRequest.offline};
    }

    try {
      final headers = auth ? await _headers() : _baseHeaders();
      final response = await _client
          .patch(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      return handleResponse(response);
    } catch (e) {
      debugPrint('PATCH Error: $e');
      return {'status': StatusRequest.failure};
    }
  }

  Future<Map<String, dynamic>> deleteData(String url,
      {bool auth = true}) async {
    final connectivity = await _checkConnectivity();
    if (connectivity == StatusRequest.offline) {
      return {'status': StatusRequest.offline};
    }

    try {
      final headers = auth ? await _headers() : _baseHeaders();
      final response = await _client
          .delete(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      return handleResponse(response);
    } catch (e) {
      debugPrint('DELETE Error: $e');
      return {'status': StatusRequest.failure};
    }
  }

  Future<Map<String, dynamic>> postFile(
    String url,
    File file, {
    Map<String, String>? fields,
    String fieldName = 'file',
  }) async {
    final connectivity = await _checkConnectivity();
    if (connectivity == StatusRequest.offline) {
      return {'status': StatusRequest.offline};
    }

    try {
      final headers = await _headers();
      headers.remove('Content-Type');

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(headers);
      request.files
          .add(await http.MultipartFile.fromPath(fieldName, file.path));

      if (fields != null) {
        request.fields.addAll(fields);
      }

      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      return handleResponse(response);
    } catch (e) {
      debugPrint('POST FILE Error: $e');
      return {'status': StatusRequest.failure};
    }
  }

  Map<String, dynamic> _errorFromStatus(int statusCode) {
    return {
      'status': StatusRequest.failure,
      'statusCode': statusCode,
    };
  }

  @visibleForTesting
  Map<String, dynamic> handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      try {
        final body = jsonDecode(response.body);
        // The API wraps success payloads in an envelope:
        // {"status":"success","data":{...}}. Every consumer expects
        // response['data'] to be the inner payload, so unwrap it here. Fall
        // back to the raw body for any endpoint that doesn't use the envelope.
        dynamic payload = body;
        if (body is Map<String, dynamic> &&
            body['status'] == 'success' &&
            body.containsKey('data')) {
          payload = body['data'];
        }
        return {
          'status': StatusRequest.success,
          'data': payload,
        };
      } catch (_) {
        return {
          'status': StatusRequest.success,
          'data': null,
        };
      }
    }

    if (statusCode == 401) {
      onSessionExpired?.call();
      return {
        'status': StatusRequest.failure,
        'statusCode': 401,
        'message': 'session_expired_server'.tr,
      };
    }

    if (statusCode == 403) {
      final body = _tryDecode(response.body);
      return {
        'status': StatusRequest.failure,
        'statusCode': 403,
        'message': 'no_permission'.tr,
        'error_code': ?_errorCodeOf(body),
        'meta': ?_metaOf(body),
      };
    }

    if (statusCode == 404) {
      final body = _tryDecode(response.body);
      String message = 'data_not_found'.tr;
      if (body != null &&
          body['message'] is String &&
          (body['message'] as String).isNotEmpty) {
        message = body['message'] as String;
      }
      return {
        'status': StatusRequest.failure,
        'statusCode': 404,
        'message': message,
        'error_code': ?_errorCodeOf(body),
        'meta': ?_metaOf(body),
      };
    }

    if (statusCode == 422) {
      final body = _tryDecode(response.body);
      return {
        'status': StatusRequest.failure,
        'statusCode': 422,
        'message': (body?['message'] as String?) ?? 'invalid_data'.tr,
        'errors': ?body?['errors'],
        'error_code': ?_errorCodeOf(body),
        'meta': ?_metaOf(body),
      };
    }

    final body = _tryDecode(response.body);
    String message = 'error_try_again'.tr;
    if (body != null && body['message'] is String && (body['message'] as String).isNotEmpty) {
      message = body['message'] as String;
    }

    debugPrint('HTTP $statusCode: $message');

    return {
      'status': StatusRequest.serverFailure,
      'statusCode': statusCode,
      'message': message,
      'error_code': ?_errorCodeOf(body),
      'meta': ?_metaOf(body),
    };
  }

  /// Decodes a JSON body to a map, or null if it isn't a JSON object.
  static Map<String, dynamic>? _tryDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// The backend's machine-readable `error_code`, if present and non-empty.
  static String? _errorCodeOf(Map<String, dynamic>? body) {
    final code = body?['error_code'];
    return code is String && code.isNotEmpty ? code : null;
  }

  /// Optional structured values the client uses to fill a translated template.
  static Map<String, dynamic>? _metaOf(Map<String, dynamic>? body) {
    final meta = body?['meta'];
    return meta is Map<String, dynamic> && meta.isNotEmpty ? meta : null;
  }
}
