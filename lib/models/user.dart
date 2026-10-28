import 'dart:convert';

enum UserRole { organizer, supervisor, scanner }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String token;
  final List<String> assignedEventIds;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
    required this.assignedEventIds,
  });

  bool get canViewStats =>
      role == UserRole.organizer || role == UserRole.supervisor;

  bool get isOrganizer => role == UserRole.organizer;

  factory AppUser.fromJson(Map<String, dynamic> j) {
    final roleStr = j['role'] as String? ?? 'scanner';
    final role = switch (roleStr) {
      'organizer'  => UserRole.organizer,
      'supervisor' => UserRole.supervisor,
      _            => UserRole.scanner,
    };
    return AppUser(
      id:               j['id'] as String,
      name:             j['name'] as String,
      email:            j['email'] as String? ?? '',
      role:             role,
      token:            j['token'] as String,
      assignedEventIds: List<String>.from(j['assignedEventIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':               id,
    'name':             name,
    'email':            email,
    'role':             role.name,
    'token':            token,
    'assignedEventIds': assignedEventIds,
  };
}

// ── Ticket type data stored on the event ─────────────────────
class EventTicketType {
  final String name;
  final double price;
  final int capacity;
  final int sold;
  final double? earlyBirdPrice;
  final DateTime? earlyBirdEnd;

  const EventTicketType({
    required this.name,
    required this.price,
    required this.capacity,
    required this.sold,
    this.earlyBirdPrice,
    this.earlyBirdEnd,
  });

  int get remaining => capacity - sold;
  double get pct    => capacity > 0 ? sold / capacity : 0;

  bool get isEarlyBird {
    if (earlyBirdEnd == null || earlyBirdPrice == null) return false;
    return DateTime.now().isBefore(earlyBirdEnd!);
  }

  double get effectivePrice => isEarlyBird ? earlyBirdPrice! : price;

  factory EventTicketType.fromMapEntry(String key, dynamic raw) {
    final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return EventTicketType(
      name:           key,
      price:          (m['price'] as num?)?.toDouble() ?? 0,
      capacity:       (m['capacity'] as num?)?.toInt() ?? 0,
      sold:           (m['sold'] as num?)?.toInt() ?? 0,
      earlyBirdPrice: (m['earlyBirdPrice'] as num?)?.toDouble(),
      earlyBirdEnd:   m['earlyBirdEnd'] != null
          ? DateTime.tryParse(m['earlyBirdEnd'] as String)
          : null,
    );
  }
}

class ScanEvent {
  final String id;
  final String title;
  final String venue;
  final String location;
  final DateTime date;
  // Raw ticketTypes map from backend — same shape as web app's parseTicketTypes()
  final Map<String, EventTicketType> ticketTypes;

  const ScanEvent({
    required this.id,
    required this.title,
    required this.venue,
    required this.location,
    required this.date,
    required this.ticketTypes,
  });

  String get subtitle => venue.isNotEmpty ? venue : location;

  /// Build a CheckinStats purely from the event's ticketTypes.
  /// Used as a fallback when the /checkin-stats endpoint fails,
  /// mirroring the web app's parseTicketTypes() + sold/capacity logic.
  CheckinStats get statsFromTicketTypes {
    int total = 0, used = 0;
    final byType = <String, TypeStat>{};
    ticketTypes.forEach((name, tt) {
      total += tt.capacity;
      used  += tt.sold;
      byType[name] = TypeStat(capacity: tt.capacity, used: tt.sold);
    });
    return CheckinStats(
      total:     total,
      used:      used,
      remaining: total - used,
      byType:    byType,
    );
  }

  factory ScanEvent.fromJson(Map<String, dynamic> j) {
    // Parse ticketTypes — may arrive as JSON string or already a Map
    Map<String, dynamic> rawTT = {};
    final ttRaw = j['ticketTypes'];
    if (ttRaw is String && ttRaw.isNotEmpty) {
      try { rawTT = Map<String, dynamic>.from(jsonDecode(ttRaw)); } catch (_) {}
    } else if (ttRaw is Map) {
      rawTT = Map<String, dynamic>.from(ttRaw);
    }

    final ticketTypes = <String, EventTicketType>{};
    rawTT.forEach((key, value) {
      ticketTypes[key] = EventTicketType.fromMapEntry(key, value);
    });

    return ScanEvent(
      id:          j['_id'] as String,
      title:       j['title'] as String,
      venue:       j['venue'] as String? ?? '',
      location:    j['location'] as String? ?? '',
      date:        DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
      ticketTypes: ticketTypes,
    );
  }
}

// ── Keep ticket/stats models here so user.dart is self-contained ──

class CheckinStats {
  final int total;
  final int used;
  final int remaining;
  final Map<String, TypeStat> byType;

  const CheckinStats({
    required this.total,
    required this.used,
    required this.remaining,
    required this.byType,
  });

  double get pct => total > 0 ? used / total : 0;

  factory CheckinStats.fromJson(Map<String, dynamic> j) {
    final byType = <String, TypeStat>{};
    final raw = j['byType'] as Map<String, dynamic>? ?? {};
    for (final e in raw.entries) {
      byType[e.key] = TypeStat.fromJson(e.value as Map<String, dynamic>);
    }
    // Also support flat shape: { vip: { capacity, used }, regular: { ... } }
    if (byType.isEmpty) {
      for (final e in j.entries) {
        if (e.value is Map) {
          final m = Map<String, dynamic>.from(e.value as Map);
          if (m.containsKey('capacity') || m.containsKey('used')) {
            byType[e.key] = TypeStat.fromJson(m);
          }
        }
      }
    }
    return CheckinStats(
      total:     (j['total'] as num?)?.toInt() ?? 0,
      used:      (j['used'] as num?)?.toInt() ?? 0,
      remaining: (j['remaining'] as num?)?.toInt() ?? 0,
      byType:    byType,
    );
  }

  factory CheckinStats.empty() =>
      const CheckinStats(total: 0, used: 0, remaining: 0, byType: {});
}

class TypeStat {
  final int capacity;
  final int used;

  const TypeStat({required this.capacity, required this.used});

  double get pct => capacity > 0 ? used / capacity : 0;
  int get remaining => capacity - used;

  factory TypeStat.fromJson(Map<String, dynamic> j) => TypeStat(
    capacity: (j['capacity'] as num?)?.toInt() ?? 0,
    used:     (j['used'] as num?)?.toInt() ?? 0,
  );
}