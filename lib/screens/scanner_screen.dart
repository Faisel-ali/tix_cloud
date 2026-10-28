import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../models/user.dart';
import '../models/ticket.dart';
import '../services/api_service.dart';
import 'result_screen.dart';
import 'stats_screen.dart';
import 'login_screen.dart';

class ScannerScreen extends StatefulWidget {
  final AppUser user;
  const ScannerScreen({super.key, required this.user});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage:    false,
  );

  final _manualCtrl = TextEditingController();

  List<ScanEvent> _events        = [];
  String?         _selectedEventId;
  bool            _loadingEvents = false;
  bool            _validating    = false;
  bool            _torchOn       = false;

  // Camera permission state
  bool            _permissionGranted = false;
  bool            _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestCameraPermission();
    _loadEvents();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
      // Re-check permission when user returns from Settings
        _requestCameraPermission();
        _controller.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _controller.stop();
        break;
      default:
        break;
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _permissionGranted = status.isGranted;
        _permissionChecked = true;
      });
    }
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────
  Future<void> _loadEvents({bool silent = false}) async {
    if (!silent) setState(() => _loadingEvents = true);
    try {
      final api = ApiService(widget.user.token);
      List<ScanEvent> events = await api.getOrganizerEvents();

      if (!widget.user.isOrganizer) {
        events = events
            .where((e) => widget.user.assignedEventIds.contains(e.id))
            .toList();
      }

      if (mounted) {
        setState(() {
          _events = events;
          if (_selectedEventId == null ||
              !events.any((e) => e.id == _selectedEventId)) {
            _selectedEventId = events.isNotEmpty ? events.first.id : null;
          }
        });
      }
    } catch (_) {} finally {
      if (mounted && !silent) setState(() => _loadingEvents = false);
    }
  }

  // ── Validation ────────────────────────────────────────────
  Future<void> _validate(String ticketId) async {
    if (_validating) return;
    if (_selectedEventId == null) {
      _showSnack('Select an event first.');
      return;
    }

    setState(() => _validating = true);
    _controller.stop();
    HapticFeedback.mediumImpact();

    final result = await ApiService(widget.user.token).validateTicket(
      ticketId:        ticketId,
      eventId:         _selectedEventId!,
      validatedByName: widget.user.name,
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          result:     result,
          user:       widget.user,
          eventTitle: _currentEvent?.title,
        ),
      ),
    );

    await _loadEvents(silent: true);
    setState(() => _validating = false);
    _controller.start();
  }

  void _manualSearch() {
    final id = _manualCtrl.text.trim();
    if (id.isEmpty) return;
    FocusScope.of(context).unfocus();
    _validate(id);
  }

  ScanEvent? get _currentEvent {
    if (_selectedEventId == null || _events.isEmpty) return null;
    try {
      return _events.firstWhere((e) => e.id == _selectedEventId);
    } catch (_) {
      return _events.isNotEmpty ? _events.first : null;
    }
  }

  String get _roleBadge => switch (widget.user.role) {
    UserRole.organizer  => 'ORGANISER',
    UserRole.supervisor => 'SUPERVISOR',
    UserRole.scanner    => 'SCANNER',
  };

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: AppColors.bg3,
      behavior:        SnackBarBehavior.floating,
      duration:        const Duration(seconds: 2),
    ));
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('glycr_user');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildEventSelector(),
          Expanded(child: _buildViewfinder()),
          _buildManualBar(),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    final ev = _currentEvent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ev?.title ?? 'No event selected',
                style: const TextStyle(
                  color: AppColors.bright,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (ev != null && ev.subtitle.isNotEmpty)
                Text(ev.subtitle,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 11),
                    maxLines: 1),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Role badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.teal.withOpacity(0.1),
            border: Border.all(color: AppColors.teal.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(_roleBadge,
              style: const TextStyle(
                  color: AppColors.teal, fontSize: 9,
                  fontWeight: FontWeight.w600, letterSpacing: 0.6)),
        ),
        const SizedBox(width: 4),

        if (widget.user.canViewStats)
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded,
                color: AppColors.dim, size: 20),
            tooltip: 'Stats',
            onPressed: _selectedEventId == null || _events.isEmpty
                ? null
                : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StatsScreen(
                  user:           widget.user,
                  events:         _events,
                  initialEventId: _selectedEventId!,
                ),
              ),
            ),
          ),

        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.dim, size: 20),
          color: AppColors.bg3,
          onSelected: (v) {
            if (v == 'torch') {
              setState(() => _torchOn = !_torchOn);
              _controller.toggleTorch();
            } else if (v == 'refresh') {
              _loadEvents();
            } else if (v == 'logout') {
              _logout();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'torch',
              child: Row(children: [
                Icon(_torchOn ? Icons.flash_off : Icons.flash_on,
                    color: AppColors.dim, size: 16),
                const SizedBox(width: 8),
                Text(_torchOn ? 'Torch off' : 'Torch on',
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 13)),
              ]),
            ),
            const PopupMenuItem(
              value: 'refresh',
              child: Row(children: [
                Icon(Icons.refresh_rounded, color: AppColors.dim, size: 16),
                SizedBox(width: 8),
                Text('Refresh events',
                    style: TextStyle(color: AppColors.text, fontSize: 13)),
              ]),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(children: [
                Icon(Icons.logout, color: AppColors.coral, size: 16),
                SizedBox(width: 8),
                Text('Sign out',
                    style: TextStyle(color: AppColors.coral, fontSize: 13)),
              ]),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _buildEventSelector() {
    if (_loadingEvents) {
      return const LinearProgressIndicator(
        backgroundColor: AppColors.bg2,
        color: AppColors.teal,
        minHeight: 2,
      );
    }
    if (_events.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.bg2,
      child: DropdownButtonFormField<String>(
        value: _selectedEventId,
        dropdownColor: AppColors.bg3,
        style: const TextStyle(color: AppColors.text, fontSize: 13),
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.teal),
          ),
          filled: true,
          fillColor: AppColors.bg3,
        ),
        items: _events
            .map((e) => DropdownMenuItem(
          value: e.id,
          child: Text(e.title, overflow: TextOverflow.ellipsis),
        ))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() => _selectedEventId = v);
        },
      ),
    );
  }

  Widget _buildViewfinder() {
    // Still checking permission
    if (!_permissionChecked) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2),
      );
    }

    // Permission denied
    if (!_permissionGranted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.coral.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.coral.withOpacity(0.4), width: 1.5),
                ),
                child: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.coral, size: 32),
              ),
              const SizedBox(height: 20),
              const Text('Camera permission required',
                  style: TextStyle(
                      color: AppColors.bright,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Glycr Scanner needs camera access to scan ticket QR codes.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _requestCameraPermission,
                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                label: const Text('Grant Permission'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _openAppSettings,
                child: const Text('Open App Settings',
                    style: TextStyle(color: AppColors.teal, fontSize: 13)),
              ),
            ],
          ),
        ),
      );
    }

    // No event selected
    if (_selectedEventId == null && !_loadingEvents) {
      return const Center(
        child: Text('Select an event above to start scanning.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
            textAlign: TextAlign.center),
      );
    }

    return Stack(children: [
      MobileScanner(
        controller: _controller,
        onDetect: (BarcodeCapture capture) {
          if (_validating) return;
          final raw = capture.barcodes
              .where((b) => b.rawValue != null && b.rawValue!.isNotEmpty)
              .firstOrNull
              ?.rawValue;
          if (raw != null) _validate(raw);
        },
      ),

      // Corner frame
      Center(
        child: SizedBox(
          width: 220, height: 220,
          child: CustomPaint(painter: _CornerPainter()),
        ),
      ),

      // Hint
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          color: AppColors.bg.withOpacity(0.7),
          child: const Text('Point camera at QR code',
              style: TextStyle(color: AppColors.dim, fontSize: 12),
              textAlign: TextAlign.center),
        ),
      ),

      // Validating overlay
      if (_validating)
        Container(
          color: Colors.black54,
          child: const Center(
              child: CircularProgressIndicator(color: AppColors.teal)),
        ),
    ]);
  }

  Widget _buildManualBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _manualCtrl,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Ticket ID or email…',
              isDense: true,
              contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onSubmitted: (_) => _manualSearch(),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _manualSearch,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(70, 40),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Search', style: TextStyle(fontSize: 13)),
        ),
      ]),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = const Color(0xFF2dd4bf)
      ..strokeWidth = 3
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    const len = 24.0;
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(0, len), Offset.zero, paint);
    canvas.drawLine(Offset.zero, Offset(len, 0), paint);
    canvas.drawLine(Offset(w - len, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    canvas.drawLine(Offset(0, h - len), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    canvas.drawLine(Offset(w - len, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h - len), Offset(w, h), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}