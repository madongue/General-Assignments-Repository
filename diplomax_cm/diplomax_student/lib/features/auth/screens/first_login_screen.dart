// ═══════════════════════════════════════════════════════════════════════════
// DIPLOMAX CM — First Login Flow (REAL — complete implementation)
// Steps: 1) Change temp password  2) Capture reference selfie  3) Enable biometrics
// ═══════════════════════════════════════════════════════════════════════════
import "dart:convert";
import "dart:io";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:google_fonts/google_fonts.dart";
import "package:camera/camera.dart";
import "package:dio/dio.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:local_auth/local_auth.dart";
import '../../../l10n/app_strings.dart';

const _G = Color(0xFF0F6E56);
const _GL = Color(0xFFE1F5EE);
const _B = Color(0xFF185FA5);
const _BL = Color(0xFFE6F1FB);
const _A = Color(0xFFBA7517);
const _AL = Color(0xFFFAEEDA);
const _BG = Color(0xFFF7F6F2);
const _SUR = Color(0xFFFFFFFF);
const _BD = Color(0xFFE0DDD5);
const _T1 = Color(0xFF1A1A1A);
const _T2 = Color(0xFF6B6B6B);
const _TH = Color(0xFFAAAAAA);
const _R = Color(0xFFA32D2D);
const _RL = Color(0xFFFCEBEB);

const _API = String.fromEnvironment("API_BASE_URL",
    defaultValue: "https://diplomax-backend.onrender.com/v1");
const _sto = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device));

class FirstLoginScreen extends ConsumerStatefulWidget {
  const FirstLoginScreen({super.key});
  @override
  ConsumerState<FirstLoginScreen> createState() => _FLS();
}

class _FLS extends ConsumerState<FirstLoginScreen> {
  int _step = 0;
  // Step 1
  final _np = TextEditingController(), _cp = TextEditingController();
  bool _on = true, _oc = true, _s1load = false;
  String? _s1err;
  // Step 2
  CameraController? _cam;
  bool _camReady = false, _s2load = false;
  String? _s2err;
  bool _photoDone = false;
  // Step 3
  bool _bioAvail = false;

  @override
  void initState() {
    super.initState();
    _checkBio();
  }

  @override
  void dispose() {
    _np.dispose();
    _cp.dispose();
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _checkBio() async {
    final a = LocalAuthentication();
    final av = await a.canCheckBiometrics.catchError((_) => false);
    setState(() => _bioAvail = av);
  }

  // ── Step 1: Change password ───────────────────────────────────────────────
  Future<void> _changePass() async {
    final strings = AppStrings.of(context);
    final n = _np.text, c = _cp.text;
    if (n.length < 8) {
      setState(() =>
          _s1err = strings.tr('Minimum 8 caracteres', 'Minimum 8 characters'));
      return;
    }
    if (!n.contains(RegExp(r"[A-Z]"))) {
      setState(() => _s1err =
          strings.tr('Une majuscule requise', 'Need one uppercase letter'));
      return;
    }
    if (!n.contains(RegExp(r"[0-9]"))) {
      setState(
          () => _s1err = strings.tr('Un chiffre requis', 'Need one digit'));
      return;
    }
    if (n != c) {
      setState(() => _s1err = strings.tr(
          'Les mots de passe ne correspondent pas', 'Passwords do not match'));
      return;
    }
    setState(() {
      _s1load = true;
      _s1err = null;
    });
    try {
      final tok = await _sto.read(key: "access_token");
      await Dio(BaseOptions(
              baseUrl: _API, headers: {"Authorization": "Bearer $tok"}))
          .post("/auth/change-password", data: {"new_password": n});
      setState(() {
        _step = 1;
        _s1load = false;
      });
      _initCam();
    } on DioException catch (e) {
      setState(() {
        _s1err = (e.response?.data as Map?)?["detail"]?.toString() ??
            strings.tr('Echec. Reessayez.', 'Failed. Try again.');
        _s1load = false;
      });
    }
  }

  // ── Step 2: Reference selfie ──────────────────────────────────────────────
  Future<void> _initCam() async {
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cams.first);
      _cam =
          CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await _cam!.initialize();
      if (mounted) setState(() => _camReady = true);
    } catch (_) {
      if (mounted) setState(() => _step = 2);
    }
  }

  Future<void> _snap() async {
    final strings = AppStrings.of(context);
    if (_cam == null || !_camReady) return;
    setState(() {
      _s2load = true;
      _s2err = null;
    });
    try {
      final photo = await _cam!.takePicture();
      final b64 = base64Encode(await File(photo.path).readAsBytes());
      final tok = await _sto.read(key: "access_token");
      await Dio(BaseOptions(
              baseUrl: _API, headers: {"Authorization": "Bearer $tok"}))
          .post("/students/me/reference-photo",
              data: {"photo_base64": b64, "mime_type": "image/jpeg"});
      await _cam!.dispose();
      setState(() {
        _photoDone = true;
        _s2load = false;
        _step = 2;
      });
    } on DioException catch (e) {
      setState(() {
        _s2err = (e.response?.data as Map?)?["detail"]?.toString() ??
            strings.tr('Echec de televersement. Reessayez plus tard.',
                'Upload failed. You can retry later.');
        _s2load = false;
      });
    }
  }

  void _skipPhoto() {
    _cam?.dispose();
    setState(() => _step = 2);
  }

  // ── Step 3: Biometrics ────────────────────────────────────────────────────
  Future<void> _enableBio() async {
    await _sto.write(key: "biometric_enabled", value: "true");
    _done();
  }

  void _done() {
    _sto.write(key: "is_first_login", value: "false");
    context.go("/home");
  }

  // ── Progress bar ──────────────────────────────────────────────────────────
  Widget _bar() => Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
                children: List.generate(
                    3,
                    (i) => Expanded(
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: 4,
                            margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                            decoration: BoxDecoration(
                                color: i <= _step ? _G : _BD,
                                borderRadius: BorderRadius.circular(2))))))),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Step ${_step + 1} of 3",
                      style: GoogleFonts.dmSans(fontSize: 11, color: _T2)),
                  Text(
                      [
                        AppStrings.of(context)
                            .tr('Definir le mot de passe', 'Set password'),
                        AppStrings.of(context)
                            .tr('Televerser la photo', 'Upload photo'),
                        AppStrings.of(context)
                            .tr('Activer la biometrie', 'Enable biometrics')
                      ][_step],
                      style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _G)),
                ])),
        const SizedBox(height: 4),
      ]);

  @override
  Widget build(BuildContext ctx) => Scaffold(
      backgroundColor: _BG,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: Text(
              AppStrings.of(ctx).tr('Configuration du compte', 'Account setup'),
              style: GoogleFonts.instrumentSerif(fontSize: 20, color: _T1))),
      body: Column(children: [
        _bar(),
        Expanded(
            child: _step == 0
                ? _s1()
                : _step == 1
                    ? _s2()
                    : _s3())
      ]));

  // Step 1 UI
  Widget _s1() => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            AppStrings.of(context)
                .tr('Creez votre mot de passe', 'Create your password'),
            style: GoogleFonts.instrumentSerif(fontSize: 26, color: _T1)),
        const SizedBox(height: 8),
        Text(
            AppStrings.of(context).tr(
                'Votre universite a defini un mot de passe temporaire. Creez-en un personnel : min 8 caracteres, une majuscule, un chiffre.',
                'Your university set a temporary password. Create a personal one: min 8 chars, one uppercase letter, one digit.'),
            style: GoogleFonts.dmSans(
                fontSize: 13,
                color: _T2,
                fontWeight: FontWeight.w300,
                height: 1.6)),
        const SizedBox(height: 28),
        _lbl(AppStrings.of(context).tr('Nouveau mot de passe', 'New password')),
        TextField(
            controller: _np,
            obscureText: _on,
            style: GoogleFonts.dmSans(fontSize: 14),
            decoration: _d(
                    AppStrings.of(context)
                        .tr('Minimum 8 caracteres', 'Minimum 8 characters'),
                    Icons.lock_rounded)
                .copyWith(
                    suffixIcon: IconButton(
                        icon: Icon(
                            _on
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            size: 18,
                            color: _TH),
                        onPressed: () => setState(() => _on = !_on)))),
        const SizedBox(height: 14),
        _lbl(AppStrings.of(context)
            .tr('Confirmez le nouveau mot de passe', 'Confirm new password')),
        TextField(
            controller: _cp,
            obscureText: _oc,
            onSubmitted: (_) => _changePass(),
            style: GoogleFonts.dmSans(fontSize: 14),
            decoration: _d(
                    AppStrings.of(context).tr(
                        'Repetez votre mot de passe', 'Repeat your password'),
                    Icons.lock_rounded)
                .copyWith(
                    suffixIcon: IconButton(
                        icon: Icon(
                            _oc
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            size: 18,
                            color: _TH),
                        onPressed: () => setState(() => _oc = !_oc)))),
        const SizedBox(height: 20),
        if (_s1err != null) ...[
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _RL,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _R.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: _R, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_s1err!,
                        style: GoogleFonts.dmSans(fontSize: 13, color: _R)))
              ])),
          const SizedBox(height: 16)
        ],
        ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _G,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            onPressed: _s1load ? null : _changePass,
            child: _s1load
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(AppStrings.of(context).tr(
                    'Definir le mot de passe et continuer',
                    'Set password and continue'))),
      ]));

  // Step 2 UI
  Widget _s2() => Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  AppStrings.of(context).tr('Prenez une photo de reference',
                      'Take a reference photo'),
                  style: GoogleFonts.instrumentSerif(fontSize: 24, color: _T1)),
              const SizedBox(height: 8),
              Text(
                  AppStrings.of(context).tr(
                      'Cette photo est stockee de maniere securisee et utilisee UNIQUEMENT pour verifier votre identite lors du partage de documents. Jamais affichee publiquement.',
                      'This photo is stored securely and used ONLY to verify your identity during document sharing. Never shown publicly.'),
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: _T2,
                      fontWeight: FontWeight.w300,
                      height: 1.5)),
              const SizedBox(height: 4),
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: _BL,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _B.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.security_rounded, color: _B, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            AppStrings.of(context).tr(
                                'Votre photo est chiffree. Le personnel Diplomax ne peut pas la voir.',
                                'Your photo is encrypted. Diplomax staff cannot view it.'),
                            style: GoogleFonts.dmSans(fontSize: 11, color: _B)))
                  ])),
            ])),
        Expanded(
            child: _camReady && _cam != null
                ? CameraPreview(_cam!)
                : Container(
                    color: Colors.black,
                    child: const Center(
                        child: CircularProgressIndicator(color: _G)))),
        Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              if (_s2err != null) ...[
                Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: _RL, borderRadius: BorderRadius.circular(8)),
                    child: Text(_s2err!,
                        style: GoogleFonts.dmSans(color: _R, fontSize: 12))),
              ],
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: _T2,
                            side: const BorderSide(color: _BD),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        onPressed: _skipPhoto,
                        child: Text(
                            AppStrings.of(context)
                                .tr('Ignorer pour l\'instant', 'Skip for now'),
                            style: GoogleFonts.dmSans(fontSize: 13)))),
                const SizedBox(width: 12),
                Expanded(
                    child: ElevatedButton.icon(
                        icon: _s2load
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.camera_alt_rounded, size: 18),
                        label: Text(_s2load
                            ? AppStrings.of(context)
                                .tr('Televersement…', 'Uploading…')
                            : AppStrings.of(context)
                                .tr('Prendre une photo', 'Take photo')),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _G,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0),
                        onPressed: _s2load ? null : _snap)),
              ]),
            ])),
      ]);

  // Step 3 UI
  Widget _s3() => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(color: _GL, shape: BoxShape.circle),
            child: const Icon(Icons.fingerprint_rounded, color: _G, size: 50)),
        const SizedBox(height: 24),
        Text(
            AppStrings.of(context)
                .tr('Activer la biometrie', 'Enable biometrics'),
            style: GoogleFonts.instrumentSerif(fontSize: 26, color: _T1),
            textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text(
            AppStrings.of(context).tr(
                'Apres cela, vous vous connecterez avec votre empreinte ou Face ID au lieu de saisir votre mot de passe a chaque fois.',
                'After this, you log in with your fingerprint or Face ID instead of typing your password every time.'),
            style: GoogleFonts.dmSans(
                fontSize: 13,
                color: _T2,
                fontWeight: FontWeight.w300,
                height: 1.6),
            textAlign: TextAlign.center),
        const SizedBox(height: 32),
        if (!_bioAvail)
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _AL,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _A.withOpacity(0.25))),
              child: Row(children: [
                const Icon(Icons.info_rounded, color: _A, size: 16),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        AppStrings.of(context).tr(
                            'La biometrie n\'est pas disponible sur cet appareil. Vous pourrez l\'activer plus tard dans les parametres.',
                            'Biometrics not available on this device. You can enable it later in Settings.'),
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: _A, height: 1.4)))
              ])),
        const SizedBox(height: 24),
        ElevatedButton.icon(
            icon: const Icon(Icons.fingerprint_rounded, size: 20),
            label: Text(_bioAvail
                ? AppStrings.of(context).tr('Activer empreinte / Face ID',
                    'Enable fingerprint / Face ID')
                : AppStrings.of(context).tr(
                    'Continuer sans biometrie', 'Continue without biometrics')),
            style: ElevatedButton.styleFrom(
                backgroundColor: _G,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            onPressed: _enableBio),
        const SizedBox(height: 12),
        TextButton(
            onPressed: _done,
            child: Text(
                AppStrings.of(context).tr('Ignorer et aller a mon coffre-fort',
                    'Skip and go to my vault'),
                style: GoogleFonts.dmSans(color: _T2, fontSize: 13))),
      ]));

  Widget _lbl(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t,
          style: GoogleFonts.dmSans(
              fontSize: 12, fontWeight: FontWeight.w500, color: _T2)));
  InputDecoration _d(String h, IconData i) => InputDecoration(
      hintText: h,
      hintStyle: GoogleFonts.dmSans(fontSize: 13, color: _TH),
      prefixIcon: Icon(i, size: 18, color: _TH),
      filled: true,
      fillColor: _SUR,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _BD)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _BD)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _G, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14));
}
