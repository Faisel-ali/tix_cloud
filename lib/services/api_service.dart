import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/ticket.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

// Helper to detect emulator
bool get isEmulator {
  return Platform.isAndroid &&
      (Platform.environment.containsKey('EMULATOR') ||
          File('/system/bin/qemu-props').existsSync());
}


class ApiService {
  //static const String baseUrl = 'https://glycr.onrender.com/api'';

  static String get baseUrl {
    if (kIsWeb) return 'https://glycr.onrender.com/api';
    if (Platform.isAndroid) {
      if (isEmulator) {
        return 'https://glycr.onrender.com/api';
      }


      else {
        // Use your Mac's actual IP address on the same Wi‑Fi
        return 'http://192.168.100.47:5040/api';
      }
    }
    if (Platform.isIOS) {
      return 'https://glycr.onrender.com/api';
    }
    return 'https://glycr.onrender.com/api';
  }

  final String? _token;
  ApiService([this._token]);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Uri _url(String path, [Map<String, String>? params]) {
    final uri = Uri.parse('$baseUrl$path');
    return params != null ? uri.replace(queryParameters: params) : uri;
  }





  // ── Auth ──────────────────────────────────────────────────

  Future<AppUser> loginOrganizer(String email, String password) async {
    final res = await http.post(
      _url('/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Login failed');
    }
    final user = body['user'] as Map<String, dynamic>;
    if (user['isOrganizer'] != true) {
      throw Exception('This account is not an organiser.');
    }
    return AppUser.fromJson({
      ...user,
      'role':             'organizer',
      'token':            body['token'],
      'assignedEventIds': [],
    });
  }

  Future<AppUser> loginStaffPin(String pin) async {
    final res = await http.post(
      _url('/staff/pin-login'),
      headers: _headers,
      body: jsonEncode({'pin': pin}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Invalid PIN');
    }
    return AppUser.fromJson({...body, 'token': body['token']});
  }

  // ── Events ────────────────────────────────────────────────

  Future<List<ScanEvent>> getOrganizerEvents() async {
    final res = await http.get(
      _url('/events', {'limit': '200'}),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to load events');
    final data = jsonDecode(res.body);
    final list = data is List ? data : (data['events'] as List? ?? []);
    return list
        .map((e) => ScanEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ScanEvent> getEvent(String eventId) async {
    final res = await http.get(
      _url('/events/$eventId'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Event not found');
    return ScanEvent.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ── Validation ────────────────────────────────────────────

  Future<TicketScanResult> validateTicket({
    required String ticketId,
    required String eventId,
    required String validatedByName,
    String method = 'scan',
  }) async {
    try {
      final res = await http.patch(
        _url('/tickets/$ticketId/validate'),
        headers: _headers,
        body: jsonEncode({
          'eventId':   eventId,
          'method':    method,
          'staffName': validatedByName,
        }),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 404) {
        return TicketScanResult.invalid(ticketId, 'Ticket not found.');
      }

      // The backend returns { result, message, ticket: { ticketType, ... } }
      // Merge the nested ticket fields up to the top level so
      // TicketScanResult.fromJson can read ticketType, buyerName etc directly
      final nested = body['ticket'] as Map<String, dynamic>? ?? {};

      final flat = <String, dynamic>{
        ...body,    // result, message
        ...nested,  // ticketType, buyerName, userEmail, etc — hoisted up
      };

      return TicketScanResult.fromJson(flat, ticketId);

    } catch (_) {
      return TicketScanResult.invalid(
          ticketId, 'Network error. Check connection.');
    }
  }

  // ── Stats ─────────────────────────────────────────────────

  Future<CheckinStats> getCheckinStats(
      String eventId, ScanEvent? cachedEvent) async {
    try {
      final res = await http.get(
        _url('/tickets/checkin-stats', {'eventId': eventId}),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final stats = CheckinStats.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        if (stats.byType.isNotEmpty) return stats;
      }
    } catch (_) {}

    try {
      final event = cachedEvent ?? await getEvent(eventId);
      if (event.ticketTypes.isNotEmpty) {
        return event.statsFromTicketTypes;
      }
    } catch (_) {}

    return CheckinStats.empty();
  }
}