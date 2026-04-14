import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/app_colors.dart';
import '../../core/api/api_client.dart';
import '../../core/api/student_documents_api.dart';
import '../../l10n/app_strings.dart';

class RecruiterScreen extends StatefulWidget {
  const RecruiterScreen({super.key});
  @override
  State<RecruiterScreen> createState() => _RecruiterState();
}

class _RecruiterState extends State<RecruiterScreen>
    with SingleTickerProviderStateMixin {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final _shareApi = ApiClient();
  final _api = StudentDocumentsApi.instance;
  final _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  final _tokenCtrl = TextEditingController();
  late AnimationController _scanCtrl;
  _RecStep _step = _RecStep.idle;
  bool _valid = false;
  bool _autoScanLocked = false;
  String? _error;
  String _studentName = 'Etudiant';
  String _matricule = '-';
  Map<String, dynamic>? _previewDoc;
  Map<String, dynamic>? _verifiedShareData;

  @override
  void initState() {
    super.initState();
    _loadPreviewData();
    _scanCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  Future<void> _loadPreviewData() async {
    final storedName = await _storage.read(key: 'student_name');
    final storedMat = await _storage.read(key: 'matricule');
    try {
      final docs = await _api.fetchDocuments(pageSize: 1);
      if (!mounted) return;
      setState(() {
        _studentName = (storedName != null && storedName.trim().isNotEmpty)
            ? storedName
            : 'Etudiant';
        _matricule = (storedMat != null && storedMat.trim().isNotEmpty)
            ? storedMat
            : '-';
        _previewDoc = docs.isNotEmpty ? docs.first : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _studentName = (storedName != null && storedName.trim().isNotEmpty)
            ? storedName
            : 'Etudiant';
        _matricule = (storedMat != null && storedMat.trim().isNotEmpty)
            ? storedMat
            : '-';
      });
    }
  }

  @override
  void dispose() {
    _scannerCtrl.dispose();
    _tokenCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan([String? rawInput]) async {
    final token = _extractToken(rawInput ?? _tokenCtrl.text);
    if (token.isEmpty) {
      setState(() {
        _error = AppStrings.of(context).tr(
            'Entrez un token ou un lien de partage valide.',
            'Enter a valid token or share link.');
      });
      return;
    }

    setState(() {
      _step = _RecStep.scanning;
      _valid = false;
      _error = null;
      _verifiedShareData = null;
      _autoScanLocked = true;
    });

    try {
      setState(() => _step = _RecStep.checking);

      final previewRes = await _shareApi.dio.get('/shares/$token/preview');
      final preview = Map<String, dynamic>.from(previewRes.data as Map);

      final verificationMode =
          (preview['verification_mode'] ?? 'liveness').toString().toLowerCase();

      Map<String, dynamic> access;
      if (verificationMode == 'liveness') {
        final startRes = await _shareApi.dio
            .post('/liveness/start', queryParameters: {'share_token': token});
        final sessionId = (startRes.data['session_id'] ?? '').toString();
        if (sessionId.isEmpty) {
          throw Exception(AppStrings.of(context)
              .tr('Session liveness invalide', 'Invalid liveness session'));
        }

        final challenges =
            (startRes.data['challenges'] as List?)?.whereType<Map>().toList() ??
                const [];

        for (int i = 0; i < challenges.length; i++) {
          final challenge = Map<String, dynamic>.from(challenges[i]);
          final step = (challenge['step'] as num?)?.toInt() ?? (i + 1);
          final axis = (challenge['axis'] ?? 'y').toString();
          final direction = (challenge['direction'] ?? 'right').toString();
          final threshold = (challenge['threshold'] as num?)?.toDouble() ?? 0.6;
          final instruction = (challenge['instruction'] ??
                  AppStrings.of(context).tr('Effectuez le mouvement demande',
                      'Perform the requested movement'))
              .toString();

          final proceed = await _confirmChallenge(instruction);
          if (!proceed) {
            throw Exception(AppStrings.of(context)
                .tr('Verification annulee', 'Verification cancelled'));
          }

          final evidence = await _captureMotionEvidence(
            axis: axis,
            direction: direction,
            threshold: threshold,
          );

          await _shareApi.dio.post(
            '/liveness/$sessionId/challenge/$step',
            data: {
              'detected': evidence.detected,
              'sensor_variance': evidence.variance,
            },
          );

          if (!evidence.detected) {
            throw Exception(AppStrings.of(context).tr(
                'Mouvement non detecte au challenge $step',
                'Movement not detected at challenge $step'));
          }
        }

        final accessRes = await _shareApi.dio.get('/shares/$token/access',
            queryParameters: {'liveness_session_id': sessionId});
        access = Map<String, dynamic>.from(accessRes.data as Map);
      } else {
        final accessRes = await _shareApi.dio.get('/shares/$token/access');
        access = Map<String, dynamic>.from(accessRes.data as Map);
      }

      if (!mounted) return;
      setState(() {
        _step = _RecStep.result;
        _valid = true;
        _verifiedShareData = access;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _RecStep.result;
        _valid = false;
        _error =
            '${AppStrings.of(context).tr('Verification impossible', 'Verification failed')}: ${e.toString()}';
      });
    } finally {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() {
        _autoScanLocked = false;
      });
    }
  }

  Future<bool> _confirmChallenge(String instruction) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
            AppStrings.of(context)
                .tr('Challenge de presence', 'Liveness challenge'),
            style: GoogleFonts.dmSans()),
        content: Text(
          instruction,
          style: GoogleFonts.dmSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.of(context).tr('Annuler', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.of(context).tr('Commencer', 'Start')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<_MotionEvidence> _captureMotionEvidence({
    required String axis,
    required String direction,
    required double threshold,
    Duration duration = const Duration(milliseconds: 1500),
  }) async {
    final values = <double>[];
    StreamSubscription<GyroscopeEvent>? sub;

    sub = gyroscopeEventStream().listen((event) {
      final value = switch (axis.toLowerCase()) {
        'x' => event.x,
        'y' => event.y,
        'z' => event.z,
        _ => event.y,
      };
      values.add(value);
    });

    await Future.delayed(duration);
    await sub.cancel();

    if (values.isEmpty) {
      return const _MotionEvidence(detected: false, variance: 0);
    }

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            values.length;
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    final maxAbs = values.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);

    final detected = switch (direction.toLowerCase()) {
      'right' => max >= threshold,
      'down' => max >= threshold,
      'left' => min <= -threshold,
      _ => maxAbs >= threshold,
    };

    return _MotionEvidence(detected: detected, variance: variance);
  }

  Future<String?> _askToken() async {
    final ctrl = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            AppStrings.of(context)
                .tr('Entrer le token/lien', 'Enter token/link'),
            style: GoogleFonts.dmSans()),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: AppStrings.of(context).tr(
                'https://verify.diplomax.cm/s/<token>',
                'https://verify.diplomax.cm/s/<token>'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.of(context).tr('Annuler', 'Cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _extractToken(ctrl.text)),
            child: Text(AppStrings.of(context).tr('Verifier', 'Verify')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return token;
  }

  String _extractToken(String input) {
    final value = input.trim();
    if (value.isEmpty) return '';
    if (!value.contains('/')) return value;
    try {
      final uri = Uri.parse(value);
      final segs = uri.pathSegments;
      if (segs.isNotEmpty) return segs.last;
      return value;
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/home')),
        title: Text(
            AppStrings.of(context).tr('Espace Recruteur', 'Recruiter Space'),
            style: GoogleFonts.instrumentSerif(fontSize: 22)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.info.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business_rounded,
                      size: 16, color: AppColors.info),
                  const SizedBox(width: 8),
                  Text(
                      AppStrings.of(context).tr('Mode verification recruteur',
                          'Recruiter verification mode'),
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.info,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Scanner area
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: MobileScanner(
                      controller: _scannerCtrl,
                      onDetect: (capture) {
                        if (_step == _RecStep.checking || _autoScanLocked) {
                          return;
                        }
                        final raw = capture.barcodes
                            .map((b) => b.rawValue)
                            .whereType<String>()
                            .firstWhere(
                              (v) => v.trim().isNotEmpty,
                              orElse: () => '',
                            );
                        if (raw.isEmpty) return;
                        _tokenCtrl.text = raw;
                        _scan(raw);
                      },
                    ),
                  ),
                  if (_step == _RecStep.scanning)
                    AnimatedBuilder(
                      animation: _scanCtrl,
                      builder: (_, __) => Positioned(
                        top: _scanCtrl.value * 220,
                        left: 20,
                        right: 20,
                        child: Container(
                            height: 2,
                            decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: [
                              Colors.transparent,
                              AppColors.accent,
                              Colors.transparent
                            ]))),
                      ),
                    ),
                  Center(child: _scannerCenter()),
                  ..._corners(),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _tokenCtrl,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: AppStrings.of(context).tr(
                          'Token ou lien https://verify.../s/<token>',
                          'Token or link https://verify.../s/<token>'),
                    ),
                  ),
                  if (_error != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _error!,
                        style: GoogleFonts.dmSans(
                            fontSize: 10, color: AppColors.error),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Checks during verification
            if (_step == _RecStep.checking) _checkingCard(),

            // Result
            if (_step == _RecStep.result && _valid) ...[
              _resultCard(),
              const SizedBox(height: 16),
              _livenessCheck(),
            ],

            // Actions when idle
            if (_step == _RecStep.idle) ...[
              const SizedBox(height: 4),
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: Text(AppStrings.of(context).tr(
                    'Scanner le QR Code du candidat',
                    'Scan candidate QR code')),
                onPressed: () => _scan(_tokenCtrl.text),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.link_rounded, size: 18),
                label: Text(AppStrings.of(context).tr(
                    'Verifier via lien de partage', 'Verify via share link')),
                onPressed: () async {
                  final token = await _askToken();
                  if (token == null || token.isEmpty) return;
                  _tokenCtrl.text = token;
                  _scan(token);
                },
              ),
            ],

            if (_step == _RecStep.result && _valid) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(AppStrings.of(context)
                    .tr('Nouvelle verification', 'New verification')),
                onPressed: () => setState(() {
                  _step = _RecStep.idle;
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _scannerCenter() {
    switch (_step) {
      case _RecStep.idle:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.qr_code_2_rounded, color: Colors.white38, size: 52),
          const SizedBox(height: 10),
          Text(
              AppStrings.of(context).tr(
                  'Pointez vers le QR Code ou collez un lien',
                  'Point to the QR code or paste a link'),
              style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 12)),
        ]);
      case _RecStep.scanning:
        return Text(AppStrings.of(context).tr('Lecture...', 'Reading...'),
            style: GoogleFonts.dmSans(color: AppColors.accent, fontSize: 13));
      case _RecStep.checking:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(
              color: AppColors.accent, strokeWidth: 2),
          const SizedBox(height: 12),
          Text(
              AppStrings.of(context)
                  .tr('Verification serveur...', 'Server verification...'),
              style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12)),
        ]);
      case _RecStep.result:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(_valid ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 60, color: _valid ? AppColors.success : AppColors.error),
          const SizedBox(height: 8),
          Text(
              _valid
                  ? AppStrings.of(context)
                      .tr('Document authentique', 'Authentic document')
                  : AppStrings.of(context)
                      .tr('Document invalide', 'Invalid document'),
              style: GoogleFonts.dmSans(
                  color: _valid ? AppColors.success : AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          if (!_valid && _error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ]
        ]);
    }
  }

  Widget _checkingCard() {
    final checks = [
      AppStrings.of(context).tr('Lecture du QR Code', 'QR code reading'),
      AppStrings.of(context)
          .tr('Requete serveur universitaire', 'University server request'),
      AppStrings.of(context)
          .tr('Verification hash cryptographique', 'Cryptographic hash check'),
      AppStrings.of(context).tr('Controle liste noire', 'Blacklist check')
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(
        children: checks
            .asMap()
            .entries
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.primary
                                .withOpacity(0.4 + e.key * 0.2))),
                    const SizedBox(width: 12),
                    Text(e.value,
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  Widget _resultCard() {
    final doc = _verifiedShareData ?? _previewDoc;
    final title = doc?['title'] as String? ??
        AppStrings.of(context).tr('Document academique', 'Academic document');
    final university = (doc?['university'] ??
            doc?['university_name'] ??
            AppStrings.of(context).tr('Universite', 'University'))
        .toString();
    final mention = doc?['mention'] as String? ?? '-';
    final issueYear = _issueYear(doc?['issue_date'] as String?);
    final hash = doc?['hash_sha256'] as String? ?? '';
    final holder = (doc?['student_name'] as String?) ?? _studentName;
    final matricule = (doc?['matricule'] as String?) ?? _matricule;
    final shortHash = hash.isEmpty
        ? AppStrings.of(context).tr('Hash indisponible', 'Hash unavailable')
        : (hash.length > 44 ? '${hash.substring(0, 44)}...' : hash);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.verified_rounded,
                color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Text(
                AppStrings.of(context).tr('Document verifie en temps reel',
                    'Document verified in real time'),
                style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.success)),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          _infoRow(AppStrings.of(context).tr('Titulaire', 'Holder'), holder),
          _infoRow(
              AppStrings.of(context).tr('Matricule', 'Matricule'), matricule),
          _infoRow(AppStrings.of(context).tr('Diplome', 'Degree'), title),
          _infoRow(AppStrings.of(context).tr('Universite', 'University'),
              university),
          _infoRow(AppStrings.of(context).tr('Mention', 'Mention'), mention),
          _infoRow(AppStrings.of(context).tr('Annee', 'Year'), issueYear),
          _infoRow(
              AppStrings.of(context).tr('Statut', 'Status'),
              AppStrings.of(context)
                  .tr('Authentique - Non modifie', 'Authentic - Unmodified')),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.tag_rounded,
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(shortHash,
                      style: GoogleFonts.dmSans(
                          fontSize: 10, color: AppColors.textHint))),
            ]),
          ),
        ],
      ),
    );
  }

  String _issueYear(String? issueDate) {
    final parsed = DateTime.tryParse(issueDate ?? '');
    return parsed == null ? '-' : '${parsed.year}';
  }

  Widget _livenessCheck() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              AppStrings.of(context).tr('Verification biometrique candidat',
                  'Candidate biometric verification'),
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.warning)),
          const SizedBox(height: 8),
          Text(
              AppStrings.of(context).tr(
                  'Demandez au candidat de confirmer son identite via selfie video pour un controle biometrique complet.',
                  'Ask the candidate to confirm identity via selfie video for full biometric verification.'),
              style: GoogleFonts.dmSans(
                  fontSize: 12, color: AppColors.warning, height: 1.5)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.videocam_rounded, size: 16),
            label: Text(AppStrings.of(context).tr(
                'Lancer la verification de presence',
                'Start liveness verification')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warning,
              side: const BorderSide(color: AppColors.warning),
              minimumSize: const Size(double.infinity, 40),
            ),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
              width: 90,
              child: Text(k,
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w300))),
          Expanded(
              child: Text(v,
                  style: GoogleFonts.dmSans(
                      fontSize: 12, fontWeight: FontWeight.w500))),
        ]),
      );

  List<Widget> _corners() {
    const c = AppColors.accent;
    const s = 24.0;
    const t = 2.0;
    return [
      Positioned(top: 14, left: 14, child: _corner(c, s, t, true, true)),
      Positioned(top: 14, right: 14, child: _corner(c, s, t, true, false)),
      Positioned(bottom: 14, left: 14, child: _corner(c, s, t, false, true)),
      Positioned(bottom: 14, right: 14, child: _corner(c, s, t, false, false)),
    ];
  }

  Widget _corner(Color c, double s, double t, bool top, bool left) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
            border: Border(
          top: top ? BorderSide(color: c, width: t) : BorderSide.none,
          bottom: !top ? BorderSide(color: c, width: t) : BorderSide.none,
          left: left ? BorderSide(color: c, width: t) : BorderSide.none,
          right: !left ? BorderSide(color: c, width: t) : BorderSide.none,
        )),
      );
}

enum _RecStep { idle, scanning, checking, result }

class _MotionEvidence {
  final bool detected;
  final double variance;

  const _MotionEvidence({required this.detected, required this.variance});
}
