// ═══════════════════════════════════════════════════════════════════════════
// DIPLOMAX CM — Recruiter App (complete rewrite with all features)
// GREEN = Authentic & Valid | YELLOW = Revoked/Expired | RED = Fake/Tampered
// ═══════════════════════════════════════════════════════════════════════════
import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:google_fonts/google_fonts.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "package:dio/dio.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:url_launcher/url_launcher.dart";

import 'l10n/app_locale_controller.dart';
import 'l10n/app_strings.dart';
import 'l10n/language_toggle.dart';

const _G = Color(0xFF0F6E56);
const _GL = Color(0xFFE1F5EE);
const _B = Color(0xFF185FA5);
const _BL = Color(0xFFE6F1FB);
const _R = Color(0xFFA32D2D);
const _RL = Color(0xFFFCEBEB);
const _Y = Color(0xFFBA7517);
const _YL = Color(0xFFFAEEDA);
const _BG = Color(0xFFF7F6F2);
const _SUR = Color(0xFFFFFFFF);
const _BD = Color(0xFFE0DDD5);
const _T1 = Color(0xFF1A1A1A);
const _T2 = Color(0xFF6B6B6B);
const _TH = Color(0xFFAAAAAA);

const _API = String.fromEnvironment("API_BASE_URL",
    defaultValue: "https://diplomax-backend.onrender.com/v1");
const _sto = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true));

Dio _dio() => Dio(BaseOptions(baseUrl: _API))
  ..interceptors.add(InterceptorsWrapper(onRequest: (opts, h) async {
    final t = await _sto.read(key: "access_token");
    if (t != null) opts.headers["Authorization"] = "Bearer $t";
    h.next(opts);
  }));

enum VStatus { green, yellow, red }

extension VSX on VStatus {
  Color get c => this == VStatus.green
      ? _G
      : this == VStatus.yellow
          ? _Y
          : _R;
  Color get bg => this == VStatus.green
      ? _GL
      : this == VStatus.yellow
          ? _YL
          : _RL;
  IconData get icon => this == VStatus.green
      ? Icons.check_circle_rounded
      : this == VStatus.yellow
          ? Icons.warning_amber_rounded
          : Icons.cancel_rounded;

  String label(BuildContext context) => this == VStatus.green
      ? AppStrings.of(context).tr('AUTHENTIQUE & VALIDE', 'AUTHENTIC & VALID')
      : this == VStatus.yellow
          ? AppStrings.of(context).tr('REVOQUE / EXPIRE', 'REVOKED / EXPIRED')
          : AppStrings.of(context).tr('FAUX OU ALTERE', 'FAKE OR TAMPERED');

  String desc(BuildContext context) => this == VStatus.green
      ? AppStrings.of(context).tr(
          'Le hash correspond a la blockchain. Le document est authentique.',
          'Hash matches blockchain. Document is authentic.')
      : this == VStatus.yellow
          ? AppStrings.of(context).tr(
              'Ce document a ete revoque. Ne pas accepter.',
              'This document has been revoked. Do not accept.')
          : AppStrings.of(context).tr(
              'Incoherence du hash. Possible falsification ou alteration.',
              'Hash mismatch. Possible forgery or tampering.');
}

final _router = GoRouter(initialLocation: "/login", routes: [
  GoRoute(path: "/login", builder: (_, __) => const LoginScreen()),
  GoRoute(path: "/register", builder: (_, __) => const RegisterScreen()),
  GoRoute(path: "/dashboard", builder: (_, __) => const DashboardScreen()),
  GoRoute(path: "/scan", builder: (_, __) => const ScanScreen()),
  GoRoute(
      path: "/verify/:token",
      builder: (_, s) => VerifyScreen(token: s.pathParameters["token"]!)),
  GoRoute(
      path: "/subscription", builder: (_, __) => const SubscriptionScreen()),
]);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = AppLocaleController();
  await localeController.load();
  runApp(ProviderScope(
    overrides: [
      appLocaleControllerProvider.overrideWith((ref) => localeController)
    ],
    child: const RecruiterApp(),
  ));
}

class RecruiterApp extends ConsumerWidget {
  const RecruiterApp({super.key});
  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final controller = ref.watch(appLocaleControllerProvider);
    return MaterialApp.router(
        onGenerateTitle: (context) => AppStrings.of(context).appName,
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        locale: controller.locale,
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: AppStrings.localizationsDelegates,
        theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: _G),
            textTheme: GoogleFonts.dmSansTextTheme(),
            elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _G,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0))));
  }
}

// LOGIN
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LS();
}

class _LS extends State<LoginScreen> {
  final _em = TextEditingController(), _pw = TextEditingController();
  bool _load = false, _obs = true;
  String? _err;
  @override
  void dispose() {
    _em.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _load = true);
    try {
      final r = await Dio(BaseOptions(baseUrl: _API)).post(
          "/auth/login/recruiter",
          data: {"username": _em.text.trim(), "password": _pw.text},
          options: Options(contentType: "application/x-www-form-urlencoded"));
      await _sto.write(
          key: "access_token", value: r.data["access_token"] as String);
      await _sto.write(
          key: "refresh_token", value: r.data["refresh_token"] as String);
      if (mounted) context.go("/dashboard");
    } on DioException catch (e) {
      setState(() => _err = e.response?.statusCode == 401
          ? "invalid_credentials"
          : "connection_failed");
    } finally {
      setState(() => _load = false);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final strings = AppStrings.of(ctx);
    final errorText = _err == null
        ? null
        : _err == 'invalid_credentials'
            ? strings.invalidCredentials
            : strings.connectionFailed;
    return Scaffold(
        backgroundColor: _BG,
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                        color: _G,
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: const Icon(
                                        Icons.business_center_rounded,
                                        color: Colors.white,
                                        size: 24)),
                                const SizedBox(width: 12),
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(AppStrings.of(ctx).appName,
                                          style: GoogleFonts.instrumentSerif(
                                              fontSize: 18)),
                                      Text(strings.recruiterPortal,
                                          style: GoogleFonts.dmSans(
                                              fontSize: 11, color: _T2))
                                    ]),
                                const Spacer(),
                                const LanguageToggleButton(compact: true)
                              ]),
                              const SizedBox(height: 40),
                              Text(strings.signIn,
                                  style: GoogleFonts.instrumentSerif(
                                      fontSize: 30, color: _T1)),
                              const SizedBox(height: 28),
                              TextField(
                                  controller: _em,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _d(strings.companyEmail,
                                      Icons.email_outlined)),
                              const SizedBox(height: 14),
                              TextField(
                                  controller: _pw,
                                  obscureText: _obs,
                                  onSubmitted: (_) => _login(),
                                  decoration: _d(strings.password,
                                          Icons.lock_outline_rounded)
                                      .copyWith(
                                          suffixIcon: IconButton(
                                              icon: Icon(
                                                  _obs
                                                      ? Icons.visibility_rounded
                                                      : Icons
                                                          .visibility_off_rounded,
                                                  size: 18,
                                                  color: _TH),
                                              onPressed: () => setState(
                                                  () => _obs = !_obs)))),
                              if (_err != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                        color: _RL,
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Text(errorText!,
                                        style: GoogleFonts.dmSans(
                                            color: _R, fontSize: 12)))
                              ],
                              const SizedBox(height: 20),
                              ElevatedButton(
                                  onPressed: _load ? null : _login,
                                  child: _load
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2))
                                      : Text(strings.signIn)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(strings.newRecruiter,
                                      style: GoogleFonts.dmSans(
                                          fontSize: 12, color: _T2)),
                                  TextButton(
                                      onPressed: () => context.go("/register"),
                                      child: Text(strings.createAccount,
                                          style: GoogleFonts.dmSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _G))),
                                ],
                              )
                            ]))))));
  }

  InputDecoration _d(String h, IconData i) => InputDecoration(
      hintText: h,
      hintStyle: const TextStyle(color: _TH, fontSize: 13),
      prefixIcon: Icon(i, size: 18, color: _TH),
      filled: true,
      fillColor: _SUR,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _BD)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _BD)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _G, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12));
}

// REGISTER
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RS();
}

class _RS extends State<RegisterScreen> {
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  bool _obs1 = true;
  bool _obs2 = true;
  String? _error;

  @override
  void dispose() {
    _company.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final company = _company.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    final password = _password.text;
    final confirm = _confirm.text;

    if (company.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = "Company, email and password are required");
      return;
    }
    if (password.length < 8) {
      setState(() => _error = "Password must be at least 8 characters");
      return;
    }
    if (password != confirm) {
      setState(() => _error = "Passwords do not match");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final r = await Dio(BaseOptions(baseUrl: _API)).post(
        "/auth/register/recruiter",
        data: {
          "company_name": company,
          "email": email,
          "phone": phone.isEmpty ? null : phone,
          "password": password,
        },
      );

      await _sto.write(
          key: "access_token", value: r.data["access_token"] as String);
      await _sto.write(
          key: "refresh_token", value: r.data["refresh_token"] as String);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Account created. You now have 5 free verifications/month.",
                style: GoogleFonts.dmSans()),
            backgroundColor: _G),
      );
      context.go("/dashboard");
    } on DioException catch (e) {
      setState(() {
        _error = (e.response?.data as Map?)?["detail"]?.toString() ??
            "Registration failed";
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _d(String h, IconData i) => InputDecoration(
      hintText: h,
      hintStyle: const TextStyle(color: _TH, fontSize: 13),
      prefixIcon: Icon(i, size: 18, color: _TH),
      filled: true,
      fillColor: _SUR,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _BD)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _BD)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _G, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12));

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: _BG,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: BackButton(onPressed: () => context.go("/login")),
          title: Text(AppStrings.of(context).createRecruiterAccount,
              style: GoogleFonts.instrumentSerif(fontSize: 20))),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: _GL,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: _G.withOpacity(0.25))),
                                child: Text(AppStrings.of(context).freeTierInfo,
                                    style: GoogleFonts.dmSans(
                                        fontSize: 12, color: _G, height: 1.4))),
                            const SizedBox(height: 18),
                            TextField(
                                controller: _company,
                                decoration: _d(
                                    AppStrings.of(context).companyName,
                                    Icons.business_rounded)),
                            const SizedBox(height: 12),
                            TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _d(
                                    AppStrings.of(context).companyEmail,
                                    Icons.email_outlined)),
                            const SizedBox(height: 12),
                            TextField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                decoration: _d(
                                    AppStrings.of(context).phoneOptional,
                                    Icons.phone_rounded)),
                            const SizedBox(height: 12),
                            TextField(
                                controller: _password,
                                obscureText: _obs1,
                                decoration: _d(AppStrings.of(context).password,
                                        Icons.lock_rounded)
                                    .copyWith(
                                        suffixIcon: IconButton(
                                            onPressed: () =>
                                                setState(() => _obs1 = !_obs1),
                                            icon: Icon(
                                                _obs1
                                                    ? Icons.visibility_rounded
                                                    : Icons
                                                        .visibility_off_rounded,
                                                size: 18)))),
                            const SizedBox(height: 12),
                            TextField(
                                controller: _confirm,
                                obscureText: _obs2,
                                onSubmitted: (_) => _register(),
                                decoration: _d(
                                        AppStrings.of(context).confirmPassword,
                                        Icons.lock)
                                    .copyWith(
                                        suffixIcon: IconButton(
                                            onPressed: () =>
                                                setState(() => _obs2 = !_obs2),
                                            icon: Icon(
                                                _obs2
                                                    ? Icons.visibility_rounded
                                                    : Icons
                                                        .visibility_off_rounded,
                                                size: 18)))),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: _RL,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(_error!,
                                      style: GoogleFonts.dmSans(
                                          color: _R, fontSize: 12))),
                            ],
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                                icon: const Icon(Icons.person_add_alt_1_rounded,
                                    size: 18),
                                onPressed: _loading ? null : _register,
                                label: _loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : Text(
                                        AppStrings.of(context).createAccount)),
                          ]))))));
}

// DASHBOARD
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DS();
}

class _DS extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _load = true;
  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _load = true);
    try {
      final r = await _dio().get("/recruiter/dashboard");
      setState(() {
        _data = r.data as Map<String, dynamic>;
        _load = false;
      });
    } catch (_) {
      setState(() => _load = false);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final strings = AppStrings.of(ctx);
    return Scaffold(
        backgroundColor: _BG,
        appBar: AppBar(
            backgroundColor: _SUR,
            elevation: 0,
            title: Row(children: [
              Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: _G, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.school_rounded,
                      color: Colors.white, size: 16)),
              const SizedBox(width: 8),
              Text(AppStrings.of(ctx).appName,
                  style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.w500))
            ]),
            actions: [
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: LanguageToggleButton(compact: true),
              ),
              TextButton.icon(
                  icon: const Icon(Icons.qr_code_scanner_rounded,
                      size: 18, color: _G),
                  label: Text(AppStrings.of(ctx).scan,
                      style: GoogleFonts.dmSans(color: _G, fontSize: 13)),
                  onPressed: () => ctx.go("/scan")),
              TextButton(
                  onPressed: () async {
                    await _sto.deleteAll();
                    if (mounted) ctx.go("/login");
                  },
                  child: Text(AppStrings.of(ctx).logout,
                      style: GoogleFonts.dmSans(color: _T2, fontSize: 13)))
            ]),
        body: _load
            ? const Center(child: CircularProgressIndicator(color: _G))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.of(ctx).dashboard,
                          style: GoogleFonts.instrumentSerif(
                              fontSize: 26, color: _T1)),
                      const SizedBox(height: 20),
                      Row(children: [
                        _st("${_data?["total_verifications"] ?? 0}",
                            AppStrings.of(ctx).total, _G, _GL),
                        const SizedBox(width: 12),
                        _st("${_data?["successful"] ?? 0}",
                            AppStrings.of(ctx).authentic, _G, _GL),
                        const SizedBox(width: 12),
                        _st("${_data?["failed"] ?? 0}",
                            AppStrings.of(ctx).failed, _R, _RL)
                      ]),
                      const SizedBox(height: 12),
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: _SUR,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _BD)),
                          child: Row(children: [
                            Icon(Icons.card_membership_rounded,
                                color: (_data?["subscription_active"] == true)
                                    ? _G
                                    : _Y,
                                size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(
                                    (_data?["subscription_active"] == true)
                                        ? strings.tr(
                                            'Forfait payant actif : verifications illimitees + export PDF',
                                            'Paid plan active: unlimited verifications + PDF exports',
                                          )
                                        : strings.tr(
                                            'Forfait gratuit : ${_data?["free_remaining"] ?? 0}/${_data?["free_monthly_limit"] ?? 5} verifications restantes ce mois-ci',
                                            'Free plan: ${_data?["free_remaining"] ?? 0}/${_data?["free_monthly_limit"] ?? 5} verifications left this month',
                                          ),
                                    style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        color: _T2,
                                        height: 1.4))),
                          ])),
                      const SizedBox(height: 24),
                      GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.8,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _act(
                                Icons.qr_code_scanner_rounded,
                                strings.tr(
                                    'Scanner le code QR', 'Scan QR Code'),
                                _G,
                                () => ctx.go("/scan")),
                            _act(
                                Icons.nfc_rounded,
                                strings.tr('Lire la puce NFC', 'Read NFC chip'),
                                const Color(0xFF534AB7),
                                () {}),
                            _act(
                                Icons.link_rounded,
                                strings.tr(
                                    'Verifier par lien', 'Verify by link'),
                                _B,
                                () {}),
                            _act(
                                Icons.card_membership_rounded,
                                strings.tr('Abonnement', 'Subscription'),
                                _Y,
                                () => ctx.go("/subscription")),
                          ]),
                      const SizedBox(height: 24),
                      Text(
                          strings.tr(
                              'Verifications recentes', 'Recent verifications'),
                          style: GoogleFonts.dmSans(
                              fontSize: 15, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      ...((_data?["recent_logs"] as List?) ?? [])
                          .cast<Map>()
                          .map((l) {
                        final ok = l["result"] == true;
                        return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: _SUR,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _BD)),
                            child: Row(children: [
                              Icon(
                                  ok
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  color: ok ? _G : _R,
                                  size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                        strings.tr('Methode', 'Method') +
                                            ": ${l["method"] ?? ""}",
                                        style: GoogleFonts.dmSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    Text(l["verified_at"]?.toString() ?? "",
                                        style: GoogleFonts.dmSans(
                                            fontSize: 11, color: _T2))
                                  ])),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: ok ? _GL : _RL,
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                      ok ? strings.authentic : strings.failed,
                                      style: GoogleFonts.dmSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: ok ? _G : _R)))
                            ]));
                      }),
                    ])));
  }

  Widget _st(String v, String l, Color c, Color bg) => Expanded(
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.withOpacity(0.3))),
          child: Column(children: [
            Text(v, style: GoogleFonts.instrumentSerif(fontSize: 26, color: c)),
            Text(l, style: GoogleFonts.dmSans(fontSize: 11, color: c))
          ])));
  Widget _act(IconData icon, String label, Color c, VoidCallback onTap) =>
      GestureDetector(
          onTap: onTap,
          child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _SUR,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _BD)),
              child: Row(children: [
                Icon(icon, color: c, size: 24),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(label,
                        style: GoogleFonts.dmSans(
                            fontSize: 12, fontWeight: FontWeight.w500),
                        maxLines: 2))
              ])));
}

// SCAN
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScS();
}

class _ScS extends State<ScanScreen> {
  final _ctrl = MobileScannerController();
  bool _done = false;
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    final strings = AppStrings.of(ctx);
    return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: BackButton(
                color: Colors.white, onPressed: () => ctx.go("/dashboard")),
            title: Text(strings.tr('Scanner le code QR', 'Scan QR Code'),
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16))),
        body: Stack(children: [
          MobileScanner(
              controller: _ctrl,
              onDetect: (capture) {
                if (_done) return;
                final raw = capture.barcodes.firstOrNull?.rawValue;
                if (raw == null) return;

                String? token;
                if (raw.contains("/s/")) {
                  token = raw.split("/s/").last.split("?").first;
                }

                if (token == null || token.isEmpty || token.length > 128) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                        content: Text(strings.tr(
                            'Format QR non pris en charge. Scannez un QR de partage Diplomax.',
                            'Unsupported QR format. Scan a Diplomax share URL QR.'))),
                  );
                  return;
                }

                setState(() => _done = true);
                _ctrl.stop();
                ctx.go("/verify/$token");
              }),
          Center(
              child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Stack(children: [
                    _c(true, true),
                    _c(true, false),
                    _c(false, true),
                    _c(false, false),
                    Center(
                        child: Text(
                            strings.tr(
                                'Pointez vers le code QR', 'Point at QR Code'),
                            style: GoogleFonts.dmSans(
                                color: Colors.white38, fontSize: 13)))
                  ]))),
        ]));
  }

  Widget _c(bool top, bool left) {
    const c = _G;
    const s = 28.0, t = 2.5;
    return Positioned(
        top: top ? 14 : null,
        bottom: top ? null : 14,
        left: left ? 14 : null,
        right: left ? null : 14,
        child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
                border: Border(
                    top: top
                        ? const BorderSide(color: c, width: t)
                        : BorderSide.none,
                    bottom: !top
                        ? const BorderSide(color: c, width: t)
                        : BorderSide.none,
                    left: left
                        ? const BorderSide(color: c, width: t)
                        : BorderSide.none,
                    right: !left
                        ? const BorderSide(color: c, width: t)
                        : BorderSide.none))));
  }
}

// VERIFY
class VerifyScreen extends StatefulWidget {
  final String token;
  const VerifyScreen({super.key, required this.token});
  @override
  State<VerifyScreen> createState() => _VS();
}

enum _P { loading, liveness_req, liveness_chal, result }

class _VS extends State<VerifyScreen> {
  _P _ph = _P.loading;
  Map<String, dynamic>? _prev, _res, _lv;
  Map<String, dynamic>? _dash;
  String? _sid, _err;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final dash = await _dio().get("/recruiter/dashboard");
      _dash = dash.data as Map<String, dynamic>;
      if (_dash?["can_verify"] == false) {
        setState(() {
          _err =
              "Free monthly verification quota reached. Subscribe to continue.";
          _ph = _P.result;
        });
        return;
      }

      final r = await _dio().get("/shares/${widget.token}/preview");
      _prev = r.data as Map<String, dynamic>;
      final mode = _prev!["verification_mode"] as String? ?? "none";
      setState(() => _ph = mode == "liveness" ? _P.liveness_req : _P.result);
      if (_ph == _P.result) _loadResult();
    } catch (e) {
      setState(() {
        _err = e.toString();
        _ph = _P.result;
      });
    }
  }

  Future<void> _startLiveness() async {
    final r = await _dio().post("/liveness/start",
        queryParameters: {"share_token": widget.token});
    setState(() {
      _lv = r.data as Map<String, dynamic>;
      _sid = _lv!["session_id"] as String?;
      _ph = _P.liveness_chal;
      _step = 0;
    });
  }

  Future<void> _submit(bool ok) async {
    if (_sid == null) return;
    final r = await _dio()
        .post("/liveness/$_sid/challenge/${_step + 1}", data: {"detected": ok});
    if (r.data["liveness_complete"] == true) {
      setState(() => _ph = _P.loading);
      await _loadResult(sid: _sid);
    } else if (r.data["passed"] == true) {
      setState(() => _step++);
    } else {
      setState(() => _err = "Movement not detected. Try again.");
    }
  }

  Future<void> _loadResult({String? sid}) async {
    try {
      final r = await _dio().get("/shares/${widget.token}/access",
          queryParameters: sid != null ? {"liveness_session_id": sid} : {});
      setState(() {
        _res = r.data as Map<String, dynamic>;
        _ph = _P.result;
      });
    } catch (e) {
      setState(() {
        _err = e.toString();
        _ph = _P.result;
      });
    }
  }

  VStatus get _status {
    if (_res == null) return VStatus.red;
    if (_res!["is_revoked"] == true) return VStatus.yellow;
    if (_res!["is_verified"] == true) return VStatus.green;
    return VStatus.red;
  }

  @override
  Widget build(BuildContext ctx) {
    final strings = AppStrings.of(ctx);
    return Scaffold(
        backgroundColor: _BG,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading:
                BackButton(color: _T1, onPressed: () => ctx.go("/dashboard")),
            title: Text(strings.tr('Verification', 'Verification'),
                style: GoogleFonts.instrumentSerif(fontSize: 20, color: _T1))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _body(ctx, strings)))));
  }

  Widget _body(BuildContext ctx, AppStrings strings) {
    switch (_ph) {
      case _P.loading:
        return const Center(child: CircularProgressIndicator(color: _G));
      case _P.liveness_req:
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 80,
              height: 80,
              decoration:
                  const BoxDecoration(color: _GL, shape: BoxShape.circle),
              child: const Icon(Icons.videocam_rounded, color: _G, size: 40)),
          const SizedBox(height: 24),
          Text(
              strings.tr('Verification d\'identite requise',
                  'Identity check required'),
              style: GoogleFonts.instrumentSerif(fontSize: 24, color: _T1)),
          const SizedBox(height: 10),
          Text(
              strings.tr(
                'Donnez le telephone au candidat. Il va effectuer une verification en 3 etapes.',
                'Hand the phone to the candidate. They will complete a 3-step identity check.',
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: _T2,
                  height: 1.6,
                  fontWeight: FontWeight.w300)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(strings.tr(
                  'Demarrer le test de vivacite', 'Start liveness check')),
              onPressed: _startLiveness),
        ]);
      case _P.liveness_chal:
        final chs = (_lv?["challenges"] as List?) ?? [];
        final cur =
            _step < chs.length ? chs[_step] as Map<String, dynamic> : null;
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(cur?["instruction"] ?? "",
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSerif(fontSize: 24, color: _T1)),
          const SizedBox(height: 32),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  chs.length,
                  (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: i == _step ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: i < _step
                              ? _G
                              : i == _step
                                  ? _G
                                  : _BD,
                          borderRadius: BorderRadius.circular(4))))),
          const SizedBox(height: 40),
          if (_err != null) ...[
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: _RL, borderRadius: BorderRadius.circular(8)),
                child: Text(_err!,
                    style: GoogleFonts.dmSans(color: _R, fontSize: 12))),
            const SizedBox(height: 16)
          ],
          Text(
              strings.tr(
                  'Appuyez sur CONFIRMER quand le candidat termine le mouvement.',
                  'Press CONFIRM when candidate completes the movement.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 12, color: _T2)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: () => _submit(false),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: _R,
                        side: const BorderSide(color: _R),
                        minimumSize: const Size(0, 48)),
                    child: Text(strings.tr('Non detecte', 'Not detected')))),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton(
                    onPressed: () => _submit(true),
                    child: Text(strings.tr('Confirmer ✓', 'Confirm ✓')))),
          ]),
        ]);
      case _P.result:
        final st = _status;
        return Column(children: [
          // ── BIG STATUS — GREEN / YELLOW / RED ──
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: st.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: st.c, width: 2.5)),
              child: Column(children: [
                Icon(st.icon, color: st.c, size: 52),
                const SizedBox(height: 12),
                Text(st.label(context),
                    style: GoogleFonts.dmSans(
                        fontSize: 18, fontWeight: FontWeight.w700, color: st.c),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(st.desc(context),
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: st.c, height: 1.5),
                    textAlign: TextAlign.center)
              ])),
          const SizedBox(height: 16),
          if (_res != null) ...[
            _tbl(_res!),
            const SizedBox(height: 16),
            // ── PDF CERTIFIED COPY ──
            if (st == VStatus.green && (_dash?["can_export_pdf"] == true))
              ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(strings.tr('Telecharger la copie certifiee (PDF)',
                      'Download Certified True Copy (PDF)')),
                  onPressed: () async {
                    final docId = _res!["document_id"] as String? ?? "";
                    if (docId.isEmpty) return;
                    final url = "$_API/documents/$docId/certified-pdf";
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url),
                          mode: LaunchMode.externalApplication);
                    }
                  }),
            if (st == VStatus.green && (_dash?["can_export_pdf"] == true))
              const SizedBox(height: 10),
            if (st == VStatus.green && (_dash?["can_export_pdf"] != true))
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      color: _YL, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                      strings.tr(
                        'L\'export PDF est reserve aux abonnements payants.',
                        'PDF export is available on paid subscriptions only.',
                      ),
                      style: GoogleFonts.dmSans(fontSize: 12, color: _Y))),
          ],
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _T2,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0),
              onPressed: () => ctx.go("/dashboard"),
              child: Text(strings.tr(
                  'Retour au tableau de bord', 'Back to dashboard'))),
        ]);
    }
  }

  Widget _tbl(Map r) {
    final strings = AppStrings.of(context);
    final rows = [
      [strings.tr('Etudiant', 'Student'), r["student_name"] ?? "—"],
      [strings.tr('Matricule', 'Matricule'), r["matricule"] ?? "—"],
      [strings.tr('Document', 'Document'), r["title"] ?? "—"],
      [strings.tr('Diplome', 'Degree'), r["degree"] ?? "—"],
      [strings.tr('Mention', 'Mention'), r["mention"] ?? "—"],
      [strings.tr('Universite', 'University'), r["university"] ?? "—"],
      [strings.tr('Date d\'emission', 'Issue date'), r["issue_date"] ?? "—"],
      ["SHA-256", (r["hash_sha256"] as String?)?.substring(0, 16) ?? "—"]
    ];
    return Container(
        decoration: BoxDecoration(
            color: _SUR,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _BD)),
        child: Column(
            children: rows
                .asMap()
                .entries
                .map((e) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        color: e.key % 2 == 0
                            ? const Color(0xFFF9F9F7)
                            : Colors.transparent,
                        borderRadius: e.key == 0
                            ? const BorderRadius.vertical(
                                top: Radius.circular(12))
                            : e.key == rows.length - 1
                                ? const BorderRadius.vertical(
                                    bottom: Radius.circular(12))
                                : BorderRadius.zero),
                    child: Row(children: [
                      SizedBox(
                          width: 100,
                          child: Text(e.value[0],
                              style: GoogleFonts.dmSans(
                                  fontSize: 12, color: _T2))),
                      Expanded(
                          child: Text(e.value[1],
                              style: GoogleFonts.dmSans(
                                  fontSize: 12, fontWeight: FontWeight.w500)))
                    ])))
                .toList()));
  }
}

// SUBSCRIPTION
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});
  @override
  Widget build(BuildContext ctx) {
    final strings = AppStrings.of(ctx);
    return Scaffold(
        backgroundColor: _BG,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading:
                BackButton(color: _T1, onPressed: () => ctx.go("/dashboard")),
            title: Text(strings.tr('Abonnement', 'Subscription'),
                style: GoogleFonts.instrumentSerif(fontSize: 20))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              strings.tr('Choisissez votre forfait',
                                  'Choose your plan'),
                              style: GoogleFonts.instrumentSerif(
                                  fontSize: 26, color: _T1)),
                          const SizedBox(height: 8),
                          Text(
                              strings.tr('Payez avec MTN MoMo ou Orange Money.',
                                  'Pay with MTN MoMo or Orange Money.'),
                              style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: _T2,
                                  fontWeight: FontWeight.w300)),
                          const SizedBox(height: 24),
                          _p(
                              strings.tr('Gratuit', 'Free'),
                              strings.tr('0 FCFA / mois', '0 FCFA / month'),
                              strings.tr('Jusqu\'a 5 verifications/mois',
                                  'Up to 5 verifications/month'),
                              false,
                              ctx),
                          const SizedBox(height: 12),
                          _p(
                              strings.tr('Mensuel', 'Monthly'),
                              strings.tr(
                                  '15,000 FCFA / mois', '15,000 FCFA / month'),
                              strings.tr(
                                  'Illimite · Exports PDF · Support prioritaire',
                                  'Unlimited · PDF exports · Priority support'),
                              true,
                              ctx),
                          const SizedBox(height: 12),
                          _p(
                              strings.tr('Annuel', 'Annual'),
                              strings.tr(
                                  '120,000 FCFA / an', '120,000 FCFA / year'),
                              strings.tr(
                                  'Illimite · Prioritaire · 2 mois offerts',
                                  'Unlimited · Priority · 2 months free'),
                              false,
                              ctx),
                        ])))));
  }

  Widget _p(String name, String price, String desc, bool featured,
          BuildContext ctx) =>
      Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: featured ? _GL : _SUR,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: featured ? _G : _BD, width: featured ? 2 : 0.5)),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  if (featured)
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                            color: _G, borderRadius: BorderRadius.circular(4)),
                        child: Text(
                            AppStrings.of(ctx)
                                .tr('Le plus populaire', 'Most popular'),
                            style: GoogleFonts.dmSans(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w500))),
                  Text(name,
                      style: GoogleFonts.dmSans(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  Text(price,
                      style:
                          GoogleFonts.instrumentSerif(fontSize: 18, color: _G)),
                  Text(desc,
                      style: GoogleFonts.dmSans(fontSize: 12, color: _T2))
                ])),
            ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 20)),
                child: Text(AppStrings.of(ctx).tr('Choisir', 'Select')))
          ]));
}
