enum ScanResult { valid, alreadyUsed, invalid }

class TicketScanResult {
  final ScanResult result;
  final String ticketId;
  final String? attendeeName;
  final String? attendeeEmail;
  final String? ticketType;
  final String? eventTitle;
  final DateTime? firstUsedAt;
  final String? firstUsedBy;
  final String? message;

  const TicketScanResult({
    required this.result,
    required this.ticketId,
    this.attendeeName,
    this.attendeeEmail,
    this.ticketType,
    this.eventTitle,
    this.firstUsedAt,
    this.firstUsedBy,
    this.message,
  });

  factory TicketScanResult.fromJson(Map<String, dynamic> j, String ticketId) {
    final raw = j['result'] as String? ?? '';
    final result = switch (raw) {
      'valid'        => ScanResult.valid,
      'already_used' => ScanResult.alreadyUsed,
      _              => ScanResult.invalid,
    };
    return TicketScanResult(
      result:        result,
      ticketId:      ticketId,
      attendeeName:  j['buyerName']  as String?,
      attendeeEmail: j['buyerEmail'] as String?,
      ticketType:    j['ticketType'] as String?,
      eventTitle:    j['eventTitle'] as String?,
      firstUsedAt:   j['firstUsedAt'] != null
          ? DateTime.tryParse(j['firstUsedAt'] as String)
          : null,
      firstUsedBy:   j['firstUsedBy'] as String?,
      message:       j['message']    as String?,
    );
  }

  factory TicketScanResult.invalid(String ticketId, [String? msg]) =>
      TicketScanResult(
        result:   ScanResult.invalid,
        ticketId: ticketId,
        message:  msg ?? 'Ticket not found or not for this event.',
      );
}