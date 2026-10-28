import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../main.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'pin_screen.dart';
import 'scanner_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading    = false;
  bool _obscure    = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('glycr_user');
    if (raw == null) return;
    try {
      final user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (!mounted) return;
      _navigate(user);
    } catch (_) {}
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Email and password are required.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final user = await ApiService().loginOrganizer(email, pass);
      await _saveUser(user);
      if (mounted) _navigate(user);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('glycr_user', jsonEncode(user.toJson()));
  }

  void _navigate(AppUser user) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ScannerScreen(user: user)),
    );
  }

  void _goPinEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PinScreen(onSuccess: (user) async {
        await _saveUser(user);
        if (mounted) _navigate(user);
      })),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              // Logo mark
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppColors.tealD,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('G',
                      style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800,
                        color: Colors.white,
                      )),
                ),
              ),
              const SizedBox(height: 20),
              Text('Glycr Scanner',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.bright, fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 6),
              Text('Sign in as an organiser to validate tickets',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 36),

              // Email
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Email',
                    style: TextStyle(
                      color: AppColors.muted, fontSize: 11,
                      letterSpacing: 0.8, fontWeight: FontWeight.w500,
                    )),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.text, fontSize: 14),
                decoration: const InputDecoration(hintText: 'you@email.com'),
              ),
              const SizedBox(height: 14),

              // Password
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Password',
                    style: TextStyle(
                      color: AppColors.muted, fontSize: 11,
                      letterSpacing: 0.8, fontWeight: FontWeight.w500,
                    )),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.muted, size: 18,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _login(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withOpacity(0.1),
                    border: Border.all(color: AppColors.coral.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.coral, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.coral, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Text('Sign in as organiser'),
              ),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ),
                Expanded(child: Divider(color: AppColors.border)),
              ]),
              const SizedBox(height: 16),

              OutlinedButton(
                onPressed: _goPinEntry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.sky,
                  side: const BorderSide(color: AppColors.border2),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Enter staff PIN →'),
              ),
              const SizedBox(height: 32),
              Text('Staff log in with the PIN provided by their organiser.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}