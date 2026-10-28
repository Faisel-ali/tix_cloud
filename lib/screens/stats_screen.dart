import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/user.dart';
import '../models/ticket.dart';
import '../services/api_service.dart';

class StatsScreen extends StatefulWidget {
  final AppUser user;
  // Now accepts a list of all events so the user can switch inside the screen
  final List<ScanEvent> events;
  final String initialEventId;

  const StatsScreen({
    super.key,
    required this.user,
    required this.events,
    required this.initialEventId,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late String _selectedEventId;
  CheckinStats _stats = CheckinStats.empty();
  bool _loading       = true;
  Timer? _refreshTimer;
  DateTime _lastRefresh = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedEventId = widget.initialEventId;
    _load();
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 20), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  ScanEvent get _currentEvent => widget.events.firstWhere(
        (e) => e.id == _selectedEventId,
    orElse: () => widget.events.first,
  );

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      // Pass the cached ScanEvent so the service can read ticketTypes
      // directly if the /checkin-stats endpoint returns empty byType —
      // mirrors the web app's parseTicketTypes() fallback.
      final cachedEvent = widget.events.firstWhere(
            (e) => e.id == _selectedEventId,
        orElse: () => widget.events.first,
      );
      final stats = await ApiService(widget.user.token)
          .getCheckinStats(_selectedEventId, cachedEvent);
      if (mounted) {
        setState(() {
          _stats       = stats;
          _lastRefresh = DateTime.now();
        });
      }
    } catch (_) {} finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _onEventChanged(String? id) {
    if (id == null || id == _selectedEventId) return;
    setState(() {
      _selectedEventId = id;
      _stats           = CheckinStats.empty();
    });
    _load();
  }

  String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        elevation: 0,
        leading: const BackButton(color: AppColors.dim),
        title: const Text('Check-in Stats',
            style: TextStyle(
                color: AppColors.bright,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.dim, size: 20),
            onPressed: _load,
            tooltip: 'Refresh now',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _loading
              ? const LinearProgressIndicator(
              color: AppColors.teal,
              backgroundColor: AppColors.bg2,
              minHeight: 2)
              : const SizedBox(height: 2),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.teal,
        backgroundColor: AppColors.bg2,
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEventPicker(),
              const SizedBox(height: 16),
              _buildEventMeta(),
              const SizedBox(height: 16),
              _buildKpiGrid(),
              const SizedBox(height: 16),
              _buildOverallBar(),
              const SizedBox(height: 20),
              _buildTypeSection(),
              const SizedBox(height: 20),
              _buildFooter(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Event picker dropdown ─────────────────────────────────
  Widget _buildEventPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedEventId,
          isExpanded: true,
          dropdownColor: AppColors.bg3,
          iconEnabledColor: AppColors.teal,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          items: widget.events.map((e) {
            return DropdownMenuItem(
              value: e.id,
              child: Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: e.id == _selectedEventId
                          ? AppColors.teal
                          : AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: e.id == _selectedEventId
                              ? AppColors.bright
                              : AppColors.text,
                          fontWeight: e.id == _selectedEventId
                              ? FontWeight.w600
                              : FontWeight.normal,
                        )),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: _onEventChanged,
        ),
      ),
    );
  }

  // ── Event meta row (date + venue) ─────────────────────────
  Widget _buildEventMeta() {
    final ev = _currentEvent;
    final date = ev.date;
    final dateStr =
        '${_weekday(date.weekday)} ${date.day} ${_month(date.month)} · '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Row(
      children: [
        const Icon(Icons.calendar_today_rounded,
            color: AppColors.muted, size: 13),
        const SizedBox(width: 6),
        Text(dateStr,
            style:
            const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(width: 12),
        if (ev.subtitle.isNotEmpty) ...[
          const Icon(Icons.location_on_rounded,
              color: AppColors.muted, size: 13),
          const SizedBox(width: 4),
          Expanded(
            child: Text(ev.subtitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 12)),
          ),
        ],
      ],
    );
  }

  // ── KPI grid ──────────────────────────────────────────────
  Widget _buildKpiGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _kpi('Total tickets', _stats.total.toString(), AppColors.teal,
            Icons.confirmation_number_rounded),
        _kpi('Checked in', _stats.used.toString(), AppColors.mint,
            Icons.check_circle_rounded),
        _kpi('Remaining', _stats.remaining.toString(), AppColors.text,
            Icons.hourglass_bottom_rounded),
        _kpi('Utilisation', '${(_stats.pct * 100).round()}%',
            AppColors.gold, Icons.pie_chart_rounded),
      ],
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.1)),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Overall progress bar ──────────────────────────────────
  Widget _buildOverallBar() {
    final pct = _stats.pct.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Overall progress'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bg3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_stats.used} checked in',
                      style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text('of ${_stats.total} total',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),
              Stack(children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.border2,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                AnimatedFractionallySizedBox(
                  widthFactor: pct,
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOut,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.tealD, AppColors.mint],
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_stats.remaining} remaining',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11)),
                  Text('${(pct * 100).round()}% utilisation',
                      style: const TextStyle(
                          color: AppColors.teal,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Ticket type breakdown ─────────────────────────────────
  Widget _buildTypeSection() {
    if (_stats.byType.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('By ticket type'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bg3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text('No ticket type data available.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
          ),
        ],
      );
    }

    // Sort: most sold first
    final sorted = _stats.byType.entries.toList()
      ..sort((a, b) => b.value.used.compareTo(a.value.used));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('By ticket type'),
        const SizedBox(height: 10),
        ...sorted.map((e) => _typeCard(e.key, e.value)),
      ],
    );
  }

  Widget _typeCard(String typeName, TypeStat stat) {
    // Assign colour by name, fall back to a palette rotation
    const palette = [
      AppColors.gold,
      AppColors.teal,
      AppColors.mint,
      AppColors.coral,
      AppColors.sky,
    ];
    final fixed = {
      'vip':     AppColors.gold,
      'vvip':    AppColors.coral,
      'regular': AppColors.teal,
      'free':    AppColors.mint,
      'table':   AppColors.sky,
    };
    final idx   = typeName.hashCode.abs() % palette.length;
    final color = fixed[typeName.toLowerCase()] ?? palette[idx];
    final pct   = stat.pct.clamp(0.0, 1.0);
    final remaining = stat.capacity - stat.used;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    typeName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(typeName.toUpperCase(),
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ),
              // Pct badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text('${(pct * 100).round()}%',
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          Stack(children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.border2,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            AnimatedFractionallySizedBox(
              widthFactor: pct,
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          // Stats row
          Row(
            children: [
              _statChip(Icons.check_rounded, '${stat.used} in',
                  AppColors.mint),
              const SizedBox(width: 8),
              _statChip(Icons.hourglass_bottom_rounded,
                  '$remaining left', AppColors.gold),
              const Spacer(),
              Text('Cap: ${stat.capacity}',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────
  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 6, height: 6,
          decoration: const BoxDecoration(
              color: AppColors.teal, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('Live · last updated ${_fmt(_lastRefresh)} · auto-refreshes every 20s',
            style:
            const TextStyle(color: AppColors.muted, fontSize: 10)),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w500));

  String _weekday(int d) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];

  String _month(int m) => [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ][m - 1];
}