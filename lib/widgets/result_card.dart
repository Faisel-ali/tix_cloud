import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/user.dart';
import '../models/ticket.dart';

class ResultScreen extends StatefulWidget {
  final TicketScanResult result;
  final AppUser user;
  final String? eventTitle;

  const ResultScreen({
    super.key,
    required this.result,
    required this.user,
    this.eventTitle,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
    _triggerFeedback();
  }

  void _triggerFeedback() {
    switch (widget.result.result) {
      case ScanResult.valid:
        HapticFeedback.heavyImpact();
      case ScanResult.alreadyUsed:
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 120),
            HapticFeedback.mediumImpact);
      case ScanResult.invalid:
        HapticFeedback.vibrate();
        Future.delayed(
            const Duration(milliseconds: 100), HapticFeedback.vibrate);
        Future.delayed(
            const Duration(milliseconds: 200), HapticFeedback.vibrate);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // ── Theming per result ────────────────────────────────────
  Color get _accentColor => switch (widget.result.result) {
    ScanResult.valid       => AppColors.mint,
    ScanResult.alreadyUsed => AppColors.gold,
    ScanResult.invalid     => const Color(0xFFf09595),
  };

  Color get _ringColor => switch (widget.result.result) {
    ScanResult.valid       => const Color(0xFF1d9e75),
    ScanResult.alreadyUsed => AppColors.gold,
    ScanResult.invalid     => const Color(0xFFe24b4a),
  };

  Color get _cardBorder => switch (widget.result.result) {
    ScanResult.valid       => const Color(0xFF1d9e75),
    ScanResult.alreadyUsed => AppColors.gold,
    ScanResult.invalid     => const Color(0xFFe24b4a),
  };

  String get _headline => switch (widget.result.result) {
    ScanResult.valid       => 'Valid',
    ScanResult.alreadyUsed => 'Already used',
    ScanResult.invalid     => 'Invalid',
  };

  String get _subline => switch (widget.result.result) {
    ScanResult.valid       => 'Ticket checked in',
    ScanResult.alreadyUsed => 'This ticket was already checked in',
    ScanResult.invalid     => 'Ticket not found or not for this event',
  };

  IconData get _icon => switch (widget.result.result) {
    ScanResult.valid       => Icons.check_rounded,
    ScanResult.alreadyUsed => Icons.warning_amber_rounded,
    ScanResult.invalid     => Icons.close_rounded,
  };

  Color get _bgTint => switch (widget.result.result) {
    ScanResult.valid       => const Color(0xFF0d1117),
    ScanResult.alreadyUsed => const Color(0xFF0f0e08),
    ScanResult.invalid     => const Color(0xFF100808),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTint,
      body: SafeArea(
        child: Column(
          children: [
            // Top indicator bar
            Container(
              height: 4,
              color: _ringColor.withOpacity(0.6),
            ),
            Expanded(
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    Expanded(child: _buildTop()),
                    _buildTicketCard(),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTop() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _ringColor.withOpacity(0.1),
                border: Border.all(color: _ringColor, width: 2.5),
              ),
              child: Icon(_icon, color: _accentColor, size: 38),
            ),
          ),
          const SizedBox(height: 16),
          Text(_headline,
              style: TextStyle(
                  color: _accentColor, fontSize: 26,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_subline,
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTicketCard() {
    final r = widget.result;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          if (r.result == ScanResult.valid || r.result == ScanResult.alreadyUsed) ...[
            _row('Attendee', r.attendeeName ?? r.attendeeEmail ?? '—'),
            _divider(),
            _row('Ticket ID', r.ticketId,
                mono: true, color: AppColors.teal),
            _divider(),
            _row('Type', null, badge: r.ticketType),
            if (r.result == ScanResult.alreadyUsed && r.firstUsedAt != null) ...[
              _divider(),
              _row('First used',
                  _formatTime(r.firstUsedAt!),
                  color: AppColors.gold),
              if (r.firstUsedBy != null)
                _row('By', r.firstUsedBy!, color: AppColors.gold),
            ],
          ] else ...[
            _row('Scanned code', r.ticketId,
                mono: true, color: const Color(0xFFf09595)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1a0808),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                r.message ??
                    'Possible reasons: wrong event, cancelled ticket, or forged QR code.',
                style: const TextStyle(
                    color: Color(0xFFf09595), fontSize: 12, height: 1.5),
              ),
            ),
          ],
          _divider(),
          _row('Validated by',
              '${widget.user.name} · ${_formatTime(DateTime.now())}',
              color: AppColors.dim, small: true),
        ],
      ),
    );
  }

  Widget _row(String key, String? value,
      {bool mono = false, Color? color, String? badge, bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(key,
              style: TextStyle(
                  color: AppColors.muted,
                  fontSize: small ? 11 : 12)),
          const Spacer(),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _ringColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(badge.toUpperCase(),
                  style: TextStyle(
                      color: _accentColor,
                      fontSize: 10, fontWeight: FontWeight.w500,
                      letterSpacing: 0.4)),
            )
          else
            Flexible(
              child: Text(
                value ?? '—',
                style: TextStyle(
                  color: color ?? AppColors.text,
                  fontSize: small ? 11 : 12,
                  fontWeight: mono ? FontWeight.w400 : FontWeight.w500,
                  fontFamily: mono ? 'monospace' : null,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(color: AppColors.border, height: 12);

  Widget _buildActions() {
    final r = widget.result;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: r.result == ScanResult.invalid
                    ? AppColors.redDark
                    : r.result == ScanResult.alreadyUsed
                    ? AppColors.bg3
                    : AppColors.tealD,
                foregroundColor: r.result == ScanResult.alreadyUsed
                    ? AppColors.gold
                    : Colors.white,
                side: r.result == ScanResult.alreadyUsed
                    ? const BorderSide(color: AppColors.gold)
                    : BorderSide.none,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                  r.result == ScanResult.alreadyUsed ? 'Dismiss' : 'Scan next',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dim,
                side: const BorderSide(color: AppColors.border2),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}