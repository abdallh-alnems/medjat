import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart' as app_links_pkg;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../logic/controller/auth/auth_controller.dart';

/// Captures employee join deep links (`https://<domain>/join?token=...`) on cold
/// start and while running, then activates the account with the token. Both the
/// link and the QR encode the same URL, so this is the single place that turns
/// a join URL into a login.
class DeepLinkService extends GetxService {
  final app_links_pkg.AppLinks _appLinks = app_links_pkg.AppLinks();
  StreamSubscription<Uri>? _sub;

  // Tokens already handled this session. On cold start the same link can arrive
  // via both getInitialLink() and uriLinkStream; without this, the single-use
  // token would be sent twice — the second call 404s and flashes a spurious
  // "invalid link" error right after a successful login.
  final Set<String> _handledTokens = <String>{};

  Future<DeepLinkService> init() async {
    // Deep links are only wired for Android/iOS. Skip elsewhere so the
    // app_links platform channel is never touched where it has no
    // implementation (which would throw MissingPluginException).
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return this;
    }

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (_) {
      // Plugin not registered yet (e.g. needs a full rebuild) or unsupported.
    }

    try {
      _sub = _appLinks.uriLinkStream.listen(
        _handle,
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {
      // Stream activation failed; deep links simply won't work this run.
    }
    return this;
  }

  void _handle(Uri uri) {
    final token = extractJoinToken(uri);
    if (token == null) return;
    if (!_handledTokens.add(token)) return; // already processed this token

    // Defer until the navigator is mounted so activation can route to home.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Get.find<AuthController>();
      if (auth.isLoggedIn()) return; // Already on a device; ignore the link.
      auth.activateWithToken(token);
    });
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

/// Pulls the activation token out of a join link or a raw QR payload.
/// Accepts both `https://<domain>/join?token=<hex>` and a bare token string.
String? extractJoinToken(Uri uri) {
  final fromQuery = uri.queryParameters['token'];
  if (fromQuery != null && fromQuery.trim().isNotEmpty) {
    return fromQuery.trim();
  }
  return null;
}

/// Resolves a scanned QR value (a full URL, or just the token) into a token.
String? tokenFromScannedValue(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasQuery) {
    final t = extractJoinToken(uri);
    if (t != null) return t;
  }

  // Bare token: 16–64 hex chars.
  final hex = RegExp(r'^[a-fA-F0-9]{16,64}$');
  if (hex.hasMatch(value)) return value;

  return null;
}
