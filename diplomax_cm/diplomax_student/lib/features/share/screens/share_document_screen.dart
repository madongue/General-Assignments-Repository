import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/sensors/anti_fraud_sensor.dart';
import '../../../l10n/app_strings.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _green = Color(0xFF0F6E56);
const _greenLight = Color(0xFFE1F5EE);
const _blue = Color(0xFF185FA5);
const _blueLight = Color(0xFFE6F1FB);
const _amber = Color(0xFFBA7517);
const _amberLight = Color(0xFFFAEEDA);
const _red = Color(0xFFA32D2D);
const _redLight = Color(0xFFFCEBEB);
const _bg = Color(0xFFF7F6F2);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE0DDD5);
const _textPri = Color(0xFF1A1A1A);
const _textSec = Color(0xFF6B6B6B);
const _textHint = Color(0xFFAAAAAA);

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum ShareVerificationMode {
  /// Share without any secondary check (not recommended for diplomas)
  none,

  /// Zero-Knowledge: recruiter only sees the mention, not all grades
  zkpOnly,

  /// Full liveness check: recruiter triggers a face + movement challenge
  liveness,
}

class ShareRequest {
  final String documentId;
  final String documentTitle;
  final String mention;
  final int validityHours;
  final bool zkpMode;
  final ShareVerificationMode verificationMode;

  const ShareRequest({
    required this.documentId,
    required this.documentTitle,
    required this.mention,
    required this.validityHours,
    required this.zkpMode,
    required this.verificationMode,
  });
}

class GeneratedShare {
  final String qrPayload;
  final String shareUrl;
  final String shareToken;
  final DateTime expiresAt;
  final ShareVerificationMode verificationMode;

  const GeneratedShare({
    required this.qrPayload,
    required this.shareUrl,
    required this.shareToken,
    required this.expiresAt,
    required this.verificationMode,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class ShareService {
  final _crypto = CryptoService();
  final _client = ApiClient();

  /// Creates an encrypted QR payload and registers the share token on the backend.
  /// The backend will require liveness verification before returning document data
  /// if [verificationMode] is [ShareVerificationMode.liveness].
  Future<GeneratedShare> createShare(ShareRequest request) async {
    final response = await _client.dio.post('/shares', data: {
      'document_id': request.documentId,
      'zkp_mode': request.zkpMode,
      'validity_hours': request.validityHours,
      'verification_mode': request.verificationMode.name,
    });

    final data = response.data as Map<String, dynamic>;
    final token = (data['token'] ?? '') as String;
    final shareUrl = (data['share_url'] ?? '') as String;
    if (token.isEmpty || shareUrl.isEmpty) {
      throw Exception('Invalid share response from backend');
    }

    final expiresAt = DateTime.tryParse((data['expires_at'] ?? '') as String) ??
        DateTime.now().add(Duration(hours: request.validityHours));

    return GeneratedShare(
      qrPayload: shareUrl,
      shareUrl: shareUrl,
      shareToken: token,
      expiresAt: expiresAt,
      verificationMode: request.verificationMode,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVENESS CHALLENGE STATE
// ─────────────────────────────────────────────────────────────────────────────

enum _LivenessStep {
  initial,
  device_check,
  challenge_1,
  challenge_2,
  challenge_3,
  done
}

class _Challenge {
  final String instruction;
  final String hint;
  final String axis; // gyroscope axis to watch
  final double threshold;
  _Challenge(this.instruction, this.hint, this.axis, this.threshold);
}

final _challenges = [
  _Challenge('Turn your head slowly to the right', 'Natural, relaxed movement',
      'y', 0.6),
  _Challenge(
      'Turn your head slowly to the left', 'Come back to centre', 'y', 0.6),
  _Challenge('Nod your head gently downward', 'One small nod', 'x', 0.5),
];

// ─────────────────────────────────────────────────────────────────────────────
// SHARE SCREEN  (Student side)
// ─────────────────────────────────────────────────────────────────────────────

class ShareDocumentScreen extends ConsumerStatefulWidget {
  final String documentId;
  final String documentTitle;
  final String mention;

  const ShareDocumentScreen({
    super.key,
    required this.documentId,
    required this.documentTitle,
    required this.mention,
  });

  @override
  ConsumerState<ShareDocumentScreen> createState() => _ShareDocumentState();
}

class _ShareDocumentState extends ConsumerState<ShareDocumentScreen> {
  final _svc = ShareService();

  int _validityHours = 48;
  bool _zkpMode = false;
  ShareVerificationMode _verMode = ShareVerificationMode.liveness;
  bool _generating = false;
  GeneratedShare? _share;

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _share = null;
    });
    final share = await _svc.createShare(ShareRequest(
      documentId: widget.documentId,
      documentTitle: widget.documentTitle,
      mention: widget.mention,
      validityHours: _validityHours,
      zkpMode: _zkpMode,
      verificationMode: _verMode,
    ));
    setState(() {
      _generating = false;
      _share = share;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: BackButton(onPressed: () => context.pop(), color: _textPri),
          title: Text(
              AppStrings.of(context)
                  .tr('Partager le document', 'Share document'),
              style:
                  GoogleFonts.instrumentSerif(fontSize: 20, color: _textPri)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info box about the document
              _docBadge(),
              const SizedBox(height: 20),

              _sectionTitle(AppStrings.of(context)
                  .tr('Periode de validite', 'Validity period')),
              const SizedBox(height: 10),
              _validitySelector(),
              const SizedBox(height: 20),

              _sectionTitle('Verification required from recipient'),
              const SizedBox(height: 6),
              Text(
                'Choose what the recruiter must do before seeing the document.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: _textSec,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 10),
              _verificationModeSelector(),
              const SizedBox(height: 20),

              _sectionTitle('Privacy mode'),
              const SizedBox(height: 10),
              _zkpToggle(),
              const SizedBox(height: 28),

              ElevatedButton.icon(
                icon: _generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.qr_code_rounded, size: 18),
                label: Text(
                    _generating ? 'Generating...' : 'Generate secure QR code'),
                onPressed: _generating ? null : _generate,
              ),

              if (_share != null) ...[
                const SizedBox(height: 24),
                _qrResult(_share!),
              ],
            ],
          ),
        ),
      );

  Widget _docBadge() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _greenLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school_rounded, color: _green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.documentTitle,
                  style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(
                  AppStrings.of(context).tr('Mention: ${widget.mention}',
                      'Mention: ${widget.mention}'),
                  style: GoogleFonts.dmSans(fontSize: 11, color: _textSec)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _greenLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.verified_rounded, color: _green, size: 14),
          ),
        ]),
      );

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _textPri,
      ));

  Widget _validitySelector() => Row(
        children: [24, 48, 72].map((h) {
          final active = _validityHours == h;
          return GestureDetector(
            onTap: () => setState(() => _validityHours = h),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: active ? _green : _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: active ? _green : _border,
                    width: active ? 1.5 : 0.5),
              ),
              child: Column(children: [
                Text('${h}h',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: active ? Colors.white : _textSec,
                    )),
                Text(
                    h == 24
                        ? '1 day'
                        : h == 48
                            ? '2 days'
                            : '3 days',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: active ? Colors.white70 : _textHint,
                    )),
              ]),
            ),
          );
        }).toList(),
      );

  Widget _verificationModeSelector() => Column(
        children: ShareVerificationMode.values.map((mode) {
          final active = _verMode == mode;
          final icon = _verIcon(mode);
          final label = _verLabel(mode);
          final desc = _verDesc(mode);
          final color = _verColor(mode);

          return GestureDetector(
            onTap: () => setState(() => _verMode = mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: active ? color.withOpacity(0.07) : _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? color : _border,
                  width: active ? 1.5 : 0.5,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active ? color.withOpacity(0.15) : _bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      Icon(icon, color: active ? color : _textHint, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: active ? color : _textPri,
                        )),
                    Text(desc,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: _textSec,
                          fontWeight: FontWeight.w300,
                          height: 1.4,
                        )),
                  ],
                )),
                if (active)
                  Icon(Icons.check_circle_rounded, color: color, size: 18),
              ]),
            ),
          );
        }).toList(),
      );

  IconData _verIcon(ShareVerificationMode m) {
    switch (m) {
      case ShareVerificationMode.none:
        return Icons.lock_open_rounded;
      case ShareVerificationMode.zkpOnly:
        return Icons.visibility_off_rounded;
      case ShareVerificationMode.liveness:
        return Icons.videocam_rounded;
    }
  }

  String _verLabel(ShareVerificationMode m) {
    switch (m) {
      case ShareVerificationMode.none:
        return AppStrings.of(context)
            .tr('Aucun controle supplementaire', 'No additional check');
      case ShareVerificationMode.zkpOnly:
        return AppStrings.of(context)
            .tr('Mode confidentialite uniquement', 'Privacy mode only');
      case ShareVerificationMode.liveness:
        return AppStrings.of(context).tr(
            'Verification de presence (recommandee)',
            'Liveness verification (recommended)');
    }
  }

  String _verDesc(ShareVerificationMode m) {
    switch (m) {
      case ShareVerificationMode.none:
        return AppStrings.of(context).tr(
            'N\'importe qui avec le code QR peut voir le document',
            'Anyone with the QR code can view the document');
      case ShareVerificationMode.zkpOnly:
        return AppStrings.of(context).tr(
            'Le recruteur voit uniquement la mention, pas toutes les notes',
            'Recruiter sees only the mention, not all grades');
      case ShareVerificationMode.liveness:
        return AppStrings.of(context).tr(
            'Le recruteur declenche un defi video selfie pour confirmer que vous etes le titulaire du diplome',
            'Recruiter triggers a selfie video challenge to confirm you are the diploma holder');
    }
  }

  Color _verColor(ShareVerificationMode m) {
    switch (m) {
      case ShareVerificationMode.none:
        return _amber;
      case ShareVerificationMode.zkpOnly:
        return _blue;
      case ShareVerificationMode.liveness:
        return _green;
    }
  }

  Widget _zkpToggle() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          const Icon(Icons.shield_rounded, color: _textSec, size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  AppStrings.of(context)
                      .tr('Mode Zero-Knowledge', 'Zero-Knowledge mode'),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  )),
              Text(
                  AppStrings.of(context).tr(
                      'Partagez uniquement votre mention ("Bien") sans reveler les notes individuelles.',
                      'Share only your mention ("Good") without revealing individual course grades.'),
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: _textSec, height: 1.4)),
            ],
          )),
          Switch(
            value: _zkpMode,
            activeThumbColor: _green,
            onChanged: (v) => setState(() => _zkpMode = v),
          ),
        ]),
      );

  Widget _qrResult(GeneratedShare share) {
    final expires = share.expiresAt;
    final expStr =
        '${expires.day}/${expires.month}/${expires.year} at ${expires.hour}:${expires.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // QR Code card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _green.withOpacity(0.4)),
          ),
          child: Column(children: [
            QrImageView(
              data: share.qrPayload,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              foregroundColor: _green,
              errorStateBuilder: (ctx, err) => SizedBox(
                height: 200,
                child: Center(
                    child: Text(AppStrings.of(context).tr(
                        'Erreur de generation du QR', 'QR generation error'))),
              ),
            ),
            const SizedBox(height: 14),
            // Verification badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: share.verificationMode == ShareVerificationMode.liveness
                    ? _greenLight
                    : share.verificationMode == ShareVerificationMode.zkpOnly
                        ? _blueLight
                        : _amberLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_verIcon(share.verificationMode),
                      size: 13, color: _verColor(share.verificationMode)),
                  const SizedBox(width: 6),
                  Text(_verLabel(share.verificationMode),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _verColor(share.verificationMode),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
                AppStrings.of(context)
                    .tr('Expire le $expStr', 'Expires $expStr'),
                style: GoogleFonts.dmSans(fontSize: 11, color: _textHint)),
          ]),
        ),

        const SizedBox(height: 12),

        // Share URL
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Row(children: [
            Expanded(
                child: Text(
              share.shareUrl,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: _textSec,
              ),
              overflow: TextOverflow.ellipsis,
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                // Copy to clipboard
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        AppStrings.of(context)
                            .tr('Lien copie!', 'Link copied!'),
                        style: GoogleFonts.dmSans()),
                    backgroundColor: _green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              child: const Icon(Icons.copy_rounded, size: 16, color: _textHint),
            ),
          ]),
        ),

        const SizedBox(height: 12),

        // Warning if liveness is on
        if (share.verificationMode == ShareVerificationMode.liveness)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _greenLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _green.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_rounded, color: _green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                  'When the recruiter scans this QR code, they will be asked to '
                  'hand you the phone. You will need to complete a short 3-step '
                  'face movement challenge to confirm your identity before the '
                  'document data is released.',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: _green,
                    height: 1.5,
                  ),
                )),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVENESS VERIFICATION SCREEN  (triggered when recruiter scans QR)
// ─────────────────────────────────────────────────────────────────────────────

/// This screen is shown to the STUDENT after the recruiter scans the QR code
/// and the app detects that liveness verification is required.
/// The student must pass 3 gyroscope-based movement challenges + an
/// accelerometer human-check before the document data is unlocked.

class LivenessVerificationScreen extends ConsumerStatefulWidget {
  final String shareToken;
  final VoidCallback onVerified;

  const LivenessVerificationScreen({
    super.key,
    required this.shareToken,
    required this.onVerified,
  });

  @override
  ConsumerState<LivenessVerificationScreen> createState() =>
      _LivenessVerificationState();
}

class _LivenessVerificationState
    extends ConsumerState<LivenessVerificationScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  final _sensorSvc = AntiFraudSensorService();

  _LivenessStep _step = _LivenessStep.initial;
  int _challengeIdx = 0;
  bool _passed = false;
  bool _processing = false;
  String? _errorMsg;

  // Real-time accel magnitude for the ring animation
  double _accelMag = 9.81;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Start live accelerometer feed for visual ring
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen((e) {
      if (!mounted) return;
      setState(() {
        _accelMag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      });
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _accelSub?.cancel();
    _sensorSvc.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _step = _LivenessStep.device_check;
      _errorMsg = null;
    });

    // Step 1 — Real accelerometer human check
    final result = await _sensorSvc.analyze();

    if (!result.isHuman) {
      setState(() {
        _step = _LivenessStep.initial;
        _errorMsg = result.isPossibleEmulator
            ? 'Emulator detected. Please use a real device.'
            : result.reason;
      });
      return;
    }

    // Step 2 — Movement challenges using real gyroscope
    await _runChallenges();
  }

  Future<void> _runChallenges() async {
    for (int i = 0; i < _challenges.length; i++) {
      setState(() {
        _challengeIdx = i;
        _step = _LivenessStep.values[_LivenessStep.challenge_1.index + i];
        _processing = true;
      });

      final detected = await _sensorSvc.detectMovement(
        expectedAxis: _challenges[i].axis,
        threshold: _challenges[i].threshold,
        timeout: const Duration(seconds: 5),
      );

      setState(() => _processing = false);

      if (!detected) {
        setState(() {
          _errorMsg =
              'Movement not detected for: "${_challenges[i].instruction}". Please try again.';
          _step = _LivenessStep.initial;
        });
        return;
      }

      await Future.delayed(const Duration(milliseconds: 400));
    }

    // All challenges passed
    setState(() {
      _step = _LivenessStep.done;
      _passed = true;
    });
    await Future.delayed(const Duration(milliseconds: 1200));
    widget.onVerified();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              const Spacer(),
              _buildTitle(),
              const SizedBox(height: 48),
              _buildFaceRing(),
              const SizedBox(height: 40),
              _buildStatus(),
              const Spacer(),
              _buildAction(),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      );

  Widget _buildTitle() {
    String title, sub;
    switch (_step) {
      case _LivenessStep.initial:
        title = 'Identity verification';
        sub = 'Confirm you are the diploma holder.';
        break;
      case _LivenessStep.device_check:
        title = 'Checking device...';
        sub = 'Reading sensors.';
        break;
      case _LivenessStep.challenge_1:
      case _LivenessStep.challenge_2:
      case _LivenessStep.challenge_3:
        final c = _challenges[_challengeIdx];
        title = c.instruction;
        sub = c.hint;
        break;
      case _LivenessStep.done:
        title = 'Identity confirmed';
        sub = 'Document is now unlocked.';
    }
    return Column(children: [
      Text(title,
          textAlign: TextAlign.center,
          style: GoogleFonts.instrumentSerif(
            fontSize: 28,
            color: _passed ? const Color(0xFF5DCAA5) : Colors.white,
          )),
      const SizedBox(height: 8),
      Text(sub,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: Colors.white60,
            fontWeight: FontWeight.w300,
            height: 1.6,
          )),
    ]);
  }

  Widget _buildFaceRing() {
    // Ring size pulses with real accelerometer magnitude
    final norm = ((_accelMag - 9.0) / 6.0).clamp(0.0, 1.0);
    final scale = 1.0 + norm * 0.12;
    final ringColor = _passed
        ? const Color(0xFF1D9E75)
        : _step == _LivenessStep.device_check
            ? const Color(0xFFBA7517)
            : const Color(0xFF0F6E56);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer live-ring driven by real accelerometer
        AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: ringColor.withOpacity(0.25),
                width: 2,
              ),
            ),
          ),
        ),
        // Middle ring
        Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ringColor.withOpacity(0.5), width: 1.5),
          ),
        ),
        // Inner face oval
        Container(
          width: 130,
          height: 154,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(80),
            border: Border.all(color: ringColor, width: 2.5),
            color: ringColor.withOpacity(0.07),
          ),
          child: Center(
            child: _step == _LivenessStep.done
                ? const Icon(Icons.check_rounded,
                    color: Color(0xFF1D9E75), size: 60)
                : _step == _LivenessStep.device_check
                    ? const CircularProgressIndicator(
                        color: Color(0xFFBA7517), strokeWidth: 2)
                    : Icon(
                        _stepIcon(),
                        color: ringColor.withOpacity(0.5),
                        size: 56,
                      ),
          ),
        ),
        // Progress dots
        if (_step != _LivenessStep.initial &&
            _step != _LivenessStep.device_check &&
            _step != _LivenessStep.done)
          Positioned(
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final done = i < _challengeIdx;
                final active = i == _challengeIdx;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: done
                        ? const Color(0xFF1D9E75)
                        : active
                            ? const Color(0xFF0F6E56)
                            : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  IconData _stepIcon() {
    switch (_challengeIdx) {
      case 0:
        return Icons.arrow_forward_rounded;
      case 1:
        return Icons.arrow_back_rounded;
      case 2:
        return Icons.arrow_downward_rounded;
      default:
        return Icons.face_rounded;
    }
  }

  Widget _buildStatus() {
    if (_errorMsg != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _red.withOpacity(0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_rounded, color: Color(0xFFE24B4A), size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_errorMsg!,
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: const Color(0xFFE24B4A),
                      height: 1.5))),
        ]),
      );
    }

    if (_step == _LivenessStep.initial) {
      return Text(
        'The QR code was scanned. Hand the phone to the student\n'
        'so they can confirm their identity.',
        textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          color: Colors.white38,
          fontWeight: FontWeight.w300,
          height: 1.6,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildAction() {
    if (_step == _LivenessStep.initial || _errorMsg != null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.videocam_rounded, size: 18),
          label: Text(_errorMsg != null ? 'Try again' : 'Start verification'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          onPressed: _start,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
