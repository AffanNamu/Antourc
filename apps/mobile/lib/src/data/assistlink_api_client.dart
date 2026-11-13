import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../features/calling/live_kit_call_session.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.code);

  final int statusCode;
  final String code;

  @override
  String toString() => code;
}

class AssistLinkApiClient {
  AssistLinkApiClient({
    String? baseUrl,
    http.Client? httpClient,
    FlutterSecureStorage? secureStorage,
  })  : baseUrl = (baseUrl ?? const String.fromEnvironment('ASSISTLINK_API_BASE_URL')).replaceFirst(RegExp(r'/+$'), ''),
        _http = httpClient ?? http.Client(),
        _storage = secureStorage ?? const FlutterSecureStorage();

  final String baseUrl;
  final http.Client _http;
  final FlutterSecureStorage _storage;

  static const _accessKey = 'assistlink.access_token';
  static const _refreshKey = 'assistlink.refresh_token';

  bool get isConfigured {
    final uri = Uri.tryParse(baseUrl);
    return uri != null && {'https', 'http'}.contains(uri.scheme) && uri.host.isNotEmpty;
  }

  Future<Map<String, dynamic>?> currentUser() async {
    final token = await _storage.read(key: _accessKey);
    if (token == null) return null;
    try {
      final response = await _request('GET', '/v1/auth/me');
      return response['user'] as Map<String, dynamic>;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _clearTokens();
        return null;
      }
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String displayName,
    required String password,
  }) async {
    await _request(
      'POST',
      '/v1/auth/register',
      body: {'email': email, 'displayName': displayName, 'password': password},
      authenticated: false,
    );
  }

  Future<void> verifyEmail({required String email, required String code}) async {
    await _request(
      'POST',
      '/v1/auth/verify-email',
      body: {'email': email, 'code': code},
      authenticated: false,
    );
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _request(
      'POST',
      '/v1/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    await _saveTokens(response);
    return response['user'] as Map<String, dynamic>;
  }

  Future<List<IncomingCall>> incomingCalls() async {
    final response = await _request('GET', '/v1/calls/incoming');
    final calls = response['calls'] as List<dynamic>? ?? const [];
    return calls
        .whereType<Map<String, dynamic>>()
        .map(IncomingCall.fromJson)
        .toList(growable: false);
  }

  Future<String> createCall(String calleeEmail) async {
    final response = await _request(
      'POST',
      '/v1/calls',
      body: {'calleeEmail': calleeEmail},
    );
    final call = response['call'] as Map<String, dynamic>;
    return call['id'] as String;
  }

  Future<void> acceptCall(String callId) async {
    await _request('POST', '/v1/calls/$callId/accept');
  }

  Future<void> rejectCall(String callId) async {
    await _request('POST', '/v1/calls/$callId/reject');
  }

  Future<String> callStatus(String callId) async {
    final response = await _request('GET', '/v1/calls/$callId');
    final call = response['call'] as Map<String, dynamic>;
    return call['status'] as String;
  }

  Future<LiveKitConnectionCredentials> callCredentials(String callId) async {
    final response = await _request('POST', '/v1/calls/$callId/token');
    return LiveKitConnectionCredentials(
      serverUrl: response['serverUrl'] as String,
      accessToken: response['accessToken'] as String,
    );
  }

  Future<void> endCall(String callId) async {
    await _request('POST', '/v1/calls/$callId/end');
  }

  Future<AssistanceSession> createAssistanceSession(String callId) async {
    final response = await _request('POST', '/v1/calls/$callId/assistance-sessions');
    return AssistanceSession.fromJson(response['session'] as Map<String, dynamic>);
  }

  Future<AssistanceSnapshot?> assistanceSessionForCall(String callId) async {
    final response = await _request('GET', '/v1/calls/$callId/assistance-sessions');
    final session = response['session'];
    if (session == null) return null;
    return AssistanceSnapshot.fromJson(
      session as Map<String, dynamic>,
      response['controlRequests'] as List<dynamic>? ?? const [],
    );
  }

  Future<AssistanceSnapshot> assistanceSession(String sessionId) async {
    final response = await _request('GET', '/v1/assistance-sessions/$sessionId');
    return AssistanceSnapshot.fromJson(
      response['session'] as Map<String, dynamic>,
      response['controlRequests'] as List<dynamic>? ?? const [],
    );
  }

  Future<ControlRequest> requestControl(String sessionId) async {
    final response = await _request(
      'POST',
      '/v1/assistance-sessions/$sessionId/control-requests',
      body: {'capabilities': ['tap', 'swipe']},
    );
    return ControlRequest.fromJson(response['controlRequest'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> approveControlRequest(String requestId) async {
    final response = await _request('POST', '/v1/control-requests/$requestId/approve');
    return response['controlGrant'] as Map<String, dynamic>;
  }

  Future<void> rejectControlRequest(String requestId) async {
    await _request('POST', '/v1/control-requests/$requestId/reject');
  }

  Future<void> revokeControlRequest(String requestId) async {
    await _request('POST', '/v1/control-requests/$requestId/revoke');
  }

  Future<void> endAssistanceSession(String sessionId) async {
    await _request('POST', '/v1/assistance-sessions/$sessionId/end');
  }

  Future<void> logout() async {
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh != null) {
      try {
        await _request(
          'POST',
          '/v1/auth/logout',
          body: {'refreshToken': refresh},
        );
      } finally {
        await _clearTokens();
      }
    } else {
      await _clearTokens();
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
    bool retryAfterRefresh = true,
  }) async {
    if (!isConfigured) throw const ApiException(0, 'api_base_url_not_configured');
    final accessToken = authenticated ? await _storage.read(key: _accessKey) : null;
    final response = await _sendRaw(method, path, body: body, accessToken: accessToken);

    if (response.statusCode == 401 && authenticated && retryAfterRefresh) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        return _request(
          method,
          path,
          body: body,
          authenticated: true,
          retryAfterRefresh: false,
        );
      }
      await _clearTokens();
    }

    final decoded = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        decoded['error'] as String? ?? 'request_failed',
      );
    }
    return decoded;
  }

  Future<http.Response> _sendRaw(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? accessToken,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['accept'] = 'application/json';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (accessToken != null) {
      request.headers['authorization'] = 'Bearer $accessToken';
    }
    return http.Response.fromStream(await _http.send(request));
  }

  Future<bool> _refreshAccessToken() async {
    final refreshToken = await _storage.read(key: _refreshKey);
    if (refreshToken == null) return false;
    try {
      final response = await _sendRaw(
        'POST',
        '/v1/auth/refresh',
        body: {'refreshToken': refreshToken},
      );
      if (response.statusCode != 200) return false;
      await _saveTokens(_decode(response.body));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> response) async {
    final access = response['accessToken'] as String?;
    final refresh = response['refreshToken'] as String?;
    if (access == null || refresh == null) {
      throw const ApiException(502, 'invalid_auth_response');
    }
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> _clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    final value = jsonDecode(body);
    if (value is Map<String, dynamic>) return value;
    return <String, dynamic>{};
  }
}

class IncomingCall {
  const IncomingCall({
    required this.id,
    required this.callerName,
    required this.status,
  });

  final String id;
  final String callerName;
  final String status;

  factory IncomingCall.fromJson(Map<String, dynamic> json) => IncomingCall(
        id: json['id'] as String,
        callerName: json['caller_name'] as String? ?? 'AssistLink user',
        status: json['status'] as String? ?? 'ringing',
      );
}


class AssistanceSession {
  const AssistanceSession({
    required this.id,
    required this.callId,
    required this.hostId,
    required this.helperId,
    required this.status,
  });

  final String id;
  final String callId;
  final String hostId;
  final String helperId;
  final String status;

  factory AssistanceSession.fromJson(Map<String, dynamic> json) => AssistanceSession(
        id: json['id'] as String,
        callId: json['call_id'] as String,
        hostId: json['host_id'] as String,
        helperId: json['helper_id'] as String,
        status: json['status'] as String,
      );
}

class ControlRequest {
  const ControlRequest({
    required this.id,
    required this.status,
    required this.capabilities,
    required this.expiresAt,
  });

  final String id;
  final String status;
  final List<String> capabilities;
  final DateTime expiresAt;

  factory ControlRequest.fromJson(Map<String, dynamic> json) => ControlRequest(
        id: json['id'] as String,
        status: json['status'] as String,
        capabilities: (json['capabilities'] as List<dynamic>? ?? const []).whereType<String>().toList(),
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}

class AssistanceSnapshot {
  const AssistanceSnapshot({
    required this.session,
    required this.controlRequests,
  });

  final AssistanceSession session;
  final List<ControlRequest> controlRequests;

  factory AssistanceSnapshot.fromJson(
    Map<String, dynamic> session,
    List<dynamic> requests,
  ) => AssistanceSnapshot(
        session: AssistanceSession.fromJson(session),
        controlRequests: requests
            .whereType<Map<String, dynamic>>()
            .map(ControlRequest.fromJson)
            .toList(growable: false),
      );
}
