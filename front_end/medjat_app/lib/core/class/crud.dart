import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  Future<Map<String, String>> _headers({bool useStationToken = false}) async {
    final headers = _baseHeaders();
    if (useStationToken) {
      final stationToken = await TokenStorageService.getStationToken();
      if (stationToken != null && stationToken.isNotEmpty) {
        headers['X-Station-Token'] = stationToken;
      }
    } else {
      final token = await TokenStorageService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['X-Employee-Token'] = token;
      }
    }
    return headers;
  }

  bool _isStationTokenRequest({bool useStationToken = false}) {
    return useStationToken;
  }

  Future<StatusRequest> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final online = results.any((r) => r != ConnectivityResult.none);
    return online ? StatusRequest.none : StatusRequest.offline;
  }

  Future<Map<String, dynamic>> getData(String url,
      {Map<String, dynamic>? queryParameters, bool useStationToken = false}) async {
    final connectivity = await _checkConnectivity();
    if (connectivity == StatusRequest.offline) {
      return {'status': StatusRequest.offline};
    }

    try {
      final uri = Uri.parse(url);
      final headers = await _headers(useStationToken: useStationToken);
      final params = <String, String>{};
      if (queryParameters != null) {
        queryParameters.forEach((k, v) => params[k] = v.toString());
      }
      final response = await _client
          .get(uri.replace(queryParameters: params), headers: headers)
          .timeout(const Duration(seconds: 15));

      return handleResponse(response, useStationToken: useStationToken);
    } catch (e) {
      debugPrint('GET Error: $e');
      return {'status': StatusRequest.failure};
    }
  }

  Future<Map<String, dynamic>> getBytes(String url,
      {Map<String, dynamic>? queryParameters, bool useStationToken = false}) async {
    final connectivity = await _checkConnectivity();
    if (connectivity == StatusRequest.offline) {
      return {'status': StatusRequest.offline};
    }

    try {
      final uri = Uri.parse(url);
      final headers = await _headers(useStationToken: useStationToken);
      final params = <String, String>{};
      if (queryParameters != null) {
        queryParameters.forEach((k, v) => params[k] = v.toString());
      }
      final response = await _client
          .get(uri.replace(queryParameters: params), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'status': StatusRequest.success, 'bytes': response.bodyBytes};
      }
      return _errorFromStatus(response.statusCode);
    } catch (e) {
      debugPrint('GET BYTES Error: $e');
      return {'status': StatusRequest.failure};
    }
  }

  Future<Map<String, dynamic>> postData(String url, Map<String, dynamic> data,
      {bool auth = true, bool useStationToken = false}) async {
    final connectivity = await _checkConnectivity();
    if (connectivity == StatusRequest.offline) {
      return {'status': StatusRequest.offline};
    }

    try {
      final headers =
          auth ? await _headers(useStationToken: useStationToken) : _baseHeaders();
      final response = await _client
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      return handleResponse(response, useStationToken: useStationToken);
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
  Map<String, dynamic> handleResponse(http.Response response, {bool useStationToken = false}) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      try {
        final body = jsonDecode(response.body);
        return {
          'status': StatusRequest.success,
          'data': body,
        };
      } catch (_) {
        return {
          'status': StatusRequest.success,
          'data': null,
        };
      }
    }

    if (statusCode == 401) {
      if (!useStationToken) {
        onSessionExpired?.call();
      }
      return {
        'status': StatusRequest.failure,
        'statusCode': 401,
        'message': 'جلستك انتهت، يرجى تسجيل الدخول مجدداً',
      };
    }

    if (statusCode == 403) {
      return {
        'status': StatusRequest.failure,
        'statusCode': 403,
        'message': 'ليس لديك صلاحية',
      };
    }

    if (statusCode == 404) {
      String message = 'لم يتم العثور على البيانات';
      try {
        final body = jsonDecode(response.body);
        if (body is Map &&
            body['message'] is String &&
            (body['message'] as String).isNotEmpty) {
          message = body['message'] as String;
        }
      } catch (_) {}
      return {
        'status': StatusRequest.failure,
        'statusCode': 404,
        'message': message,
      };
    }

    if (statusCode == 422) {
      try {
        final body = jsonDecode(response.body);
        return {
          'status': StatusRequest.failure,
          'statusCode': 422,
          'message': body['message'] ?? 'البيانات غير صحيحة',
          'errors': body['errors'],
        };
      } catch (_) {
        return {
          'status': StatusRequest.failure,
          'statusCode': 422,
          'message': 'البيانات غير صحيحة',
        };
      }
    }

    String message = 'حدث خطأ، حاول مرة أخرى';
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        final msg = body['message'];
        if (msg is String && msg.isNotEmpty) {
          message = msg;
        }
      }
    } catch (_) {}

    debugPrint('HTTP $statusCode: $message');

    return {
      'status': StatusRequest.serverFailure,
      'statusCode': statusCode,
      'message': message,
    };
  }
}
