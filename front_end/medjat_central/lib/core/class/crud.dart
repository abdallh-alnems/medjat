import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'status_request.dart';

class CRUD {
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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final idToken = await user.getIdToken();
      if (idToken != null) {
        headers['X-Firebase-Token'] = idToken;
      }
    }
    return headers;
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
      final uri = Uri.parse(url);
      final headers = await _headers();
      final response = await http.get(uri.replace(queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      )), headers: headers).timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    } catch (e) {
      debugPrint('GET Error: $e');
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
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
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
      final response = await http
          .put(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
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
      final response = await http
          .delete(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    } catch (e) {
      debugPrint('DELETE Error: $e');
      return {'status': StatusRequest.failure};
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
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
      return {
        'status': StatusRequest.failure,
        'statusCode': 404,
        'message': 'لم يتم العثور على البيانات',
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

    return {
      'status': StatusRequest.serverFailure,
      'statusCode': statusCode,
      'message': 'حدث خطأ، حاول مرة أخرى',
    };
  }
}
