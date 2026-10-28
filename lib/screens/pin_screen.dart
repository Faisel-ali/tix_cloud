import 'package:flutter/material.dart';
import '../main.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class PinScreen extends StatefulWidget {
  final Future<void> Function(AppUser user) onSuccess;

  const PinScreen({super.key, required this.onSuccess});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _pin     = StringBuffer();
  bool _loading  = false;
  String? _error;
  static const _maxLen = 8;

  void _press(String digit) {
    if (_pin.length >= _maxLen) return;
    setState(() {
      _pin.write(digit);
      _error = null;
    });
  }

  void _delete() {
    if (_pin.isEmpty) return;
    final s = _pin.toString();
    setState(() {
      _pin.clear();
      _pin.write(s.substring(0, s.length - 1));
    });
  }

  Future<void> _submit() async {
    if (_pin.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final user = await ApiService().loginStaffPin(_pin.toString());
      await widget.onSuccess(user);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _pin.clear();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _numKey(String label, {bool isDel = false, bool isGo = false}) {
    return GestureDetector(
      onTap: () {
        if (isDel) {
          _delete();
        } else if (isGo) {
          _submit();
        } else {
          _press(label);
        }
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isGo ? AppColors.tealD : AppColors.bg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: _loading && isGo
              ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : Text(
            label,
            style: TextStyle(
              fontSize: isDel ? 14 : 20,
              color: isDel
                  ? AppColors.muted
                  : isGo
                  ? Colors.white
                  : AppColors.bright,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinLen = _pin.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: const BackButton(color: AppColors.dim),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.teal.withOpacity(0.4)),
                ),
                child: const Icon(Icons.lock_outline,
                    color: AppColors.teal, size: 24),
              ),
              const SizedBox(height: 20),
              Text('Staff PIN entry',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.bright, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Enter your PIN assigned by your organiser.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),

              // Dot indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < pinLen;
                  return Container(
                    width: 14, height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.teal : Colors.transparent,
                      border: Border.all(
                        color: filled ? AppColors.teal : AppColors.border2,
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: AppColors.coral, fontSize: 12),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 28),

              // Numpad
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.5,
                children: [
                  ...'123456789'.split('').map((d) => _numKey(d)),
                  _numKey('⌫', isDel: true),
                  _numKey('0'),
                  _numKey('OK', isGo: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}