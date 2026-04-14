// ─── QR Scan Screen ──────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/app_colors.dart';
import '../../core/api/api_client.dart';
import '../../l10n/app_strings.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});
  @override
  State<QrScanScreen> createState() => _QrScanState();
}

class _QrScanState extends State<QrScanScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  final _tokenCtrl = TextEditingController();
  final _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  late AnimationController _scanCtrl;
  bool _scanned = false;
  bool _valid = false;
  bool _processing = false;
  bool _autoScanLocked = false;
  String? _error;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _access;

  @override
  void initState() {
    super.initState();
    _scanCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _scannerCtrl.dispose();
    _tokenCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyToken([String? rawInput]) async {
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
      _scanned = false;
      _valid = false;
      _processing = true;
      _error = null;
      _preview = null;
      _access = null;
      _autoScanLocked = true;
    });

    try {
      final previewRes = await _api.dio.get('/shares/$token/preview');
      final preview = previewRes.data as Map<String, dynamic>;

      final verificationMode =
          (preview['verification_mode'] ?? 'liveness').toString().toLowerCase();

      Map<String, dynamic> access;
      if (verificationMode == 'liveness') {
        final start = await _api.dio
            .post('/liveness/start', queryParameters: {'share_token': token});
        final sessionId = (start.data['session_id'] ?? '').toString();
        if (sessionId.isEmpty) {
          throw Exception(AppStrings.of(context)
              .tr('Session liveness invalide', 'Invalid liveness session'));
        }

        final challenges =
            (start.data['challenges'] as List?)?.whereType<Map>().toList() ??
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

          await _api.dio.post(
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

        final accessRes = await _api.dio.get('/shares/$token/access',
            queryParameters: {'liveness_session_id': sessionId});
        access = Map<String, dynamic>.from(accessRes.data as Map);
      } else {
        final accessRes = await _api.dio.get('/shares/$token/access');
        access = Map<String, dynamic>.from(accessRes.data as Map);
      }

      if (!mounted) return;
      setState(() {
        _preview = preview;
        _access = access;
        _scanned = true;
        _valid = true;
        _processing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanned = true;
        _valid = false;
        _processing = false;
        _error =
            '${AppStrings.of(context).tr('Verification impossible', 'Verification failed')}: ${e.toString()}';
      });
    } finally {
      if (!mounted) return;
      // Avoid immediate duplicate scans, then unlock auto-scan.
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: BackButton(
            onPressed: () => context.go('/home'), color: Colors.white),
        title: Text(
            AppStrings.of(context).tr('Scanner QR Code', 'Scan QR code'),
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 17)),
      ),
      body: Stack(
        children: [
          // Viewfinder
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Live camera scanner
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: MobileScanner(
                          controller: _scannerCtrl,
                          onDetect: (capture) {
                            if (_processing || _autoScanLocked) return;
                            final raw = capture.barcodes
                                .map((b) => b.rawValue)
                                .whereType<String>()
                                .firstWhere(
                                  (v) => v.trim().isNotEmpty,
                                  orElse: () => '',
                                );
                            if (raw.isEmpty) return;
                            _tokenCtrl.text = raw;
                            _verifyToken(raw);
                          },
                        ),
                      ),
                      // Scan line
                      if (!_scanned && !_processing)
                        AnimatedBuilder(
                          animation: _scanCtrl,
                          builder: (_, __) => Positioned(
                            top: _scanCtrl.value * 240,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 2,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Colors.transparent,
                                  AppColors.accent,
                                  Colors.transparent,
                                ]),
                              ),
                            ),
                          ),
                        ),
                      // Result overlay
                      if (_scanned || _processing)
                        Container(
                          decoration: BoxDecoration(
                            color: _processing
                                ? AppColors.info.withOpacity(0.2)
                                : (_valid ? AppColors.success : AppColors.error)
                                    .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Icon(
                              _processing
                                  ? Icons.hourglass_top_rounded
                                  : _valid
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                              size: 80,
                              color: _processing
                                  ? AppColors.info
                                  : _valid
                                      ? AppColors.success
                                      : AppColors.error,
                            ),
                          ),
                        ),
                      // Corners
                      ..._corners(),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  _processing
                      ? AppStrings.of(context).tr(
                          'Verification serveur en cours...',
                          'Server verification in progress...')
                      : _scanned
                          ? _valid
                              ? AppStrings.of(context).tr(
                                  '✓ Document authentique',
                                  '✓ Authentic document')
                              : AppStrings.of(context).tr(
                                  '✗ Document invalide', '✗ Invalid document')
                          : AppStrings.of(context).tr(
                              'Pointez vers un QR Code Diplomax',
                              'Point at a Diplomax QR code'),
                  style: GoogleFonts.dmSans(
                    color: _scanned
                        ? _valid
                            ? AppColors.accentLight
                            : AppColors.errorLight
                        : Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 300,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _tokenCtrl,
                        style: GoogleFonts.dmSans(
                            color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: AppStrings.of(context).tr(
                              'Token ou lien https://verify.../s/<token>',
                              'Token or link https://verify.../s/<token>'),
                          hintStyle: GoogleFonts.dmSans(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                      if (_error != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _error!,
                            style: GoogleFonts.dmSans(
                                color: AppColors.errorLight, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
              ),
              child: Column(
                children: [
                  if (_scanned && _valid) ...[
                    _resultCard(),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton(
                    onPressed: _processing ? null : _verifyToken,
                    child: Text(_scanned
                        ? AppStrings.of(context)
                            .tr('Verifier a nouveau', 'Verify again')
                        : AppStrings.of(context).tr('Verifier', 'Verify')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard() {
    final access = _access ?? const {};
    final preview = _preview ?? const {};
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Text(
                  AppStrings.of(context)
                      .tr('Document verifie', 'Verified document'),
                  style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          _row(AppStrings.of(context).tr('Titulaire', 'Holder'),
              (access['student_name'] ?? '-').toString()),
          _row(AppStrings.of(context).tr('Document', 'Document'),
              (access['title'] ?? preview['title'] ?? '-').toString()),
          _row(AppStrings.of(context).tr('Mention', 'Mention'),
              (access['mention'] ?? preview['mention'] ?? '-').toString()),
          _row(
              AppStrings.of(context).tr('Universite', 'University'),
              (access['university'] ?? preview['university'] ?? '-')
                  .toString()),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
                width: 90,
                child: Text(k,
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: AppColors.textSecondary))),
            Expanded(
                child: Text(v,
                    style: GoogleFonts.dmSans(
                        fontSize: 11, fontWeight: FontWeight.w500))),
          ],
        ),
      );

  List<Widget> _corners() {
    const c = AppColors.accent;
    const s = 24.0;
    const t = 3.0;
    return [
      Positioned(top: 0, left: 0, child: _corner(c, s, t, true, true)),
      Positioned(top: 0, right: 0, child: _corner(c, s, t, true, false)),
      Positioned(bottom: 0, left: 0, child: _corner(c, s, t, false, true)),
      Positioned(bottom: 0, right: 0, child: _corner(c, s, t, false, false)),
    ];
  }

  Widget _corner(Color c, double s, double t, bool top, bool left) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: c, width: t) : BorderSide.none,
          bottom: !top ? BorderSide(color: c, width: t) : BorderSide.none,
          left: left ? BorderSide(color: c, width: t) : BorderSide.none,
          right: !left ? BorderSide(color: c, width: t) : BorderSide.none,
        ),
      ),
    );
  }
}

class _MotionEvidence {
  final bool detected;
  final double variance;

  const _MotionEvidence({required this.detected, required this.variance});
}
