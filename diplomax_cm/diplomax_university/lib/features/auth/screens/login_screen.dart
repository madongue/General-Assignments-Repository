import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../l10n/app_strings.dart';
import '../../../l10n/language_toggle.dart';

const _green = Color(0xFF0F6E56);
const _bg = Color(0xFFF7F6F2);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE0DDD5);
const _textPri = Color(0xFF1A1A1A);
const _textSec = Color(0xFF6B6B6B);
const _textHint = Color(0xFFAAAAAA);
const _red = Color(0xFFA32D2D);
const _redLight = Color(0xFFFCEBEB);
const _kApiBase = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://diplomax-backend.onrender.com/v1');

class UniversityLoginScreen extends ConsumerStatefulWidget {
  const UniversityLoginScreen({super.key});
  @override
  ConsumerState<UniversityLoginScreen> createState() => _S();
}

class _S extends ConsumerState<UniversityLoginScreen> {
  final _em = TextEditingController();
  final _pw = TextEditingController();
  bool _loading = false, _obs = true;
  String? _err;
  final _st = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));

  @override
  void dispose() {
    _em.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final strings = AppStrings.of(context);
    if (_em.text.trim().isEmpty || _pw.text.isEmpty) {
      setState(() => _err = strings.enterEmailAndPassword);
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await Dio(BaseOptions(baseUrl: _kApiBase)).post(
          '/auth/login/university',
          data: {'username': _em.text.trim(), 'password': _pw.text},
          options: Options(contentType: 'application/x-www-form-urlencoded'));
      await _st.write(
          key: 'access_token', value: r.data['access_token'] as String);
      await _st.write(
          key: 'refresh_token', value: r.data['refresh_token'] as String);
      await _st.write(
          key: 'staff_name', value: (r.data['full_name'] as String?) ?? '');
      if (mounted) context.go('/dashboard');
    } on DioException catch (e) {
      setState(() => _err = e.response?.statusCode == 401
          ? strings.invalidEmailOrPassword
          : strings.connectionFailedNetwork);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  Row(children: [
                    Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.school_rounded,
                            color: Colors.white, size: 26)),
                    const SizedBox(width: 14),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Diplomax CM',
                              style: GoogleFonts.instrumentSerif(
                                  fontSize: 20, color: _textPri)),
                          Text(strings.universityPortal,
                              style: GoogleFonts.dmSans(
                                  fontSize: 12, color: _textSec)),
                        ]),
                    const Spacer(),
                    const LanguageToggleButton(compact: true),
                  ]),
                  const SizedBox(height: 48),
                  Text(strings.signIn,
                      style: GoogleFonts.instrumentSerif(
                          fontSize: 32, color: _textPri)),
                  const SizedBox(height: 6),
                  Text(strings.signInSubtitle,
                      style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: _textSec,
                          fontWeight: FontWeight.w300)),
                  const SizedBox(height: 32),
                  _lbl(strings.emailAddress),
                  TextField(
                      controller: _em,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: GoogleFonts.dmSans(fontSize: 14),
                      decoration:
                          _dec(strings.emailHint, Icons.email_outlined)),
                  const SizedBox(height: 16),
                  _lbl(strings.password),
                  TextField(
                      controller: _pw,
                      obscureText: _obs,
                      onSubmitted: (_) => _login(),
                      style: GoogleFonts.dmSans(fontSize: 14),
                      decoration:
                          _dec(strings.yourPassword, Icons.lock_outline_rounded)
                              .copyWith(
                                  suffixIcon: IconButton(
                                      icon: Icon(
                                          _obs
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                          size: 18,
                                          color: _textHint),
                                      onPressed: () =>
                                          setState(() => _obs = !_obs)))),
                  const SizedBox(height: 24),
                  if (_err != null) ...[
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: _redLight,
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              color: _red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_err!,
                                  style: GoogleFonts.dmSans(
                                      color: _red, fontSize: 13)))
                        ])),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0),
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Text(strings.signIn,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500)))),
                  const SizedBox(height: 20),
                  Center(
                      child: TextButton(
                          onPressed: () => context.go('/register'),
                          child: Text(strings.newInstitutionRegisterHere,
                              style: GoogleFonts.dmSans(
                                  fontSize: 13, color: _green)))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lbl(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t,
          style: GoogleFonts.dmSans(
              fontSize: 12, fontWeight: FontWeight.w500, color: _textSec)));
  InputDecoration _dec(String h, IconData i) => InputDecoration(
      hintText: h,
      hintStyle: GoogleFonts.dmSans(fontSize: 13, color: _textHint),
      prefixIcon: Icon(i, size: 18, color: _textHint),
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _green, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14));
}
