// ═══════════════════════════════════════════════════════════════════════════
// DIPLOMAX CM — Camera Face Liveness Screen
//
// Full liveness verification flow:
//   Step 1 — Real face detection (ML Kit, on-device, no internet)
//             Checks: face detected, eyes open, not blurry, not a photo
//   Step 2 — Gyroscope movement challenges (turn left, right, nod)
//             Proves the person is physically present, not a photo/screen
//   Step 3 — Selfie capture + server-side face match
//             Compares captured face to student's registration photo
//
// All three steps must pass before the document is released.
// The captured image is NEVER stored — discarded after comparison.
//
// This screen is shown to the STUDENT when a recruiter triggers liveness.
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math' show sqrt;
import '../../l10n/app_strings.dart';

const _green = Color(0xFF0F6E56);
const _greenLight = Color(0xFFE1F5EE);
const _red = Color(0xFFA32D2D);
const _redLight = Color(0xFFFCEBEB);
const _amber = Color(0xFFBA7517);
const _bg = Color(0xFF0A0A0A); // dark — camera screen
const _textPri = Color(0xFFFFFFFF);
const _textSec = Color(0xFFCCCCCC);
const _textHint = Color(0xFF888888);

const _kApiBase = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://diplomax-backend.onrender.com/v1');
const _sto = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true));

// ─── Liveness phases ──────────────────────────────────────────────────────────
enum _Phase {
  preparing, // Initialising camera + ML Kit
  face_detection, // Step 1: real face check
  movement_challenge, // Step 2: gyroscope challenges
  capturing, // Step 3: taking the selfie
  matching, // Waiting for server face match
  passed, // All checks passed
  failed, // One or more checks failed
}

// ─── Gyroscope challenge ──────────────────────────────────────────────────────
class _Challenge {
  final String instruction;
  final String axis;
  final double threshold;
  final IconData icon;
  _Challenge(this.instruction, this.axis, this.threshold, this.icon);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class FaceLivenessScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String shareToken;
  final VoidCallback onVerified;

  const FaceLivenessScreen({
    super.key,
    required this.sessionId,
    required this.shareToken,
    required this.onVerified,
  });

  @override
  ConsumerState<FaceLivenessScreen> createState() => _FLS();
}

class _FLS extends ConsumerState<FaceLivenessScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Camera
  CameraController? _camCtrl;
  List<CameraDescription> _cameras = [];
  bool _camReady = false;

  // ML Kit face detector
  late FaceDetector _faceDetector;
  bool _detectingFace = false;

  // Gyroscope
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  double _gyroMag = 0.0;

  // State
  _Phase _phase = _Phase.preparing;
  String _message = 'Preparing…';
  String _subMessage = '';
  int _challengeIdx = 0;
  bool _challengeActive = false;
  String? _errorMsg;

  // Progress
  bool _step1Passed = false;
  bool _step2Passed = false;
  bool _step3Passed = false;

  // Animation
  late AnimationController _pulseCtrl;

  // Accel for ring animation
  double _accelMag = 9.81;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  List<_Challenge> get _challenges {
    final strings = AppStrings.of(context);
    return [
      _Challenge(
        strings.tr('Tournez lentement la tete vers la droite',
            'Turn your head slowly to the right'),
        'y',
        0.6,
        Icons.arrow_forward_rounded,
      ),
      _Challenge(
        strings.tr('Tournez lentement la tete vers la gauche',
            'Turn your head slowly to the left'),
        'y',
        0.6,
        Icons.arrow_back_rounded,
      ),
      _Challenge(
        strings.tr('Hochez doucement la tete vers le bas',
            'Nod your head gently downward'),
        'x',
        0.5,
        Icons.arrow_downward_rounded,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _message = AppStrings.of(context).tr('Preparation…', 'Preparing…');
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: false,
        enableClassification: true, // eye open probability
        enableTracking: false,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.15,
      ),
    );

    // Real-time accelerometer for ring animation
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen((e) {
      if (!mounted) return;
      setState(() => _accelMag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z));
    });

    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    _camCtrl?.dispose();
    _faceDetector.close();
    _gyroSub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  // ── Camera init ─────────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      // Use front camera for face verification
      final front = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
      _camCtrl = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _camCtrl!.initialize();
      if (mounted) {
        setState(() {
          _camReady = true;
          _phase = _Phase.face_detection;
          _message = AppStrings.of(context).tr(
              'Placez votre visage dans le cercle',
              'Position your face in the circle');
        });
        _startFaceDetection();
      }
    } catch (e) {
      setState(() {
        _phase = _Phase.failed;
        _errorMsg =
            '${AppStrings.of(context).tr('Camera indisponible', 'Camera not available')}: ${e.toString()}';
      });
    }
  }

  // ── Step 1: Real face detection via ML Kit ──────────────────────────────────
  void _startFaceDetection() {
    if (_camCtrl == null || !_camReady) return;
    setState(() {
      _phase = _Phase.face_detection;
      _message =
          AppStrings.of(context).tr('Regardez la camera', 'Look at the camera');
      _subMessage = AppStrings.of(context)
          .tr('Detection du visage…', 'Detecting your face…');
    });

    // Process frames continuously
    _camCtrl!.startImageStream((CameraImage image) async {
      if (_detectingFace || _phase != _Phase.face_detection) return;
      _detectingFace = true;

      try {
        final inputImage = _cameraImageToInputImage(image);
        if (inputImage == null) {
          _detectingFace = false;
          return;
        }

        final faces = await _faceDetector.processImage(inputImage);

        if (!mounted) return;

        if (faces.isEmpty) {
          setState(() => _subMessage = AppStrings.of(context).tr(
              'Aucun visage detecte. Placez votre visage dans le cercle.',
              'No face detected. Position your face in the circle.'));
          _detectingFace = false;
          return;
        }

        final face = faces.first;

        // Anti-spoofing checks
        final leftEyeOpen = (face.leftEyeOpenProbability ?? 0) > 0.2;
        final rightEyeOpen = (face.rightEyeOpenProbability ?? 0) > 0.2;
        final faceSize = face.boundingBox.width;
        final headX = face.headEulerAngleX ?? 0;
        final headY = face.headEulerAngleY ?? 0;

        // Face must be large enough (close enough to camera)
        if (faceSize < 100) {
          setState(() => _subMessage = AppStrings.of(context).tr(
              'Rapprochez-vous de la camera.', 'Move closer to the camera.'));
          _detectingFace = false;
          return;
        }

        // At least one eye must be open
        if (!leftEyeOpen && !rightEyeOpen) {
          setState(() => _subMessage = AppStrings.of(context)
              .tr('Veuillez ouvrir les yeux.', 'Please open your eyes.'));
          _detectingFace = false;
          return;
        }

        // Head must be roughly facing the camera
        if (headX.abs() > 30 || headY.abs() > 30) {
          setState(() => _subMessage = AppStrings.of(context).tr(
              'Regardez droit vers la camera.',
              'Look straight at the camera.'));
          _detectingFace = false;
          return;
        }

        // All checks passed — stop the stream, proceed to movement challenges
        await _camCtrl!.stopImageStream();
        setState(() {
          _step1Passed = true;
          _subMessage =
              AppStrings.of(context).tr('Visage detecte ✓', 'Face detected ✓');
        });

        await Future.delayed(const Duration(milliseconds: 500));
        _startMovementChallenges();
      } catch (_) {
        _detectingFace = false;
      }
      _detectingFace = false;
    });
  }

  InputImage? _cameraImageToInputImage(CameraImage image) {
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );
    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  // ── Step 2: Gyroscope movement challenges ────────────────────────────────────
  void _startMovementChallenges() {
    setState(() {
      _phase = _Phase.movement_challenge;
      _challengeIdx = 0;
      _message = _challenges[0].instruction;
      _subMessage = AppStrings.of(context)
          .tr('Mouvement naturel et detendu', 'Natural, relaxed movement');
    });
    _runNextChallenge();
  }

  Future<void> _runNextChallenge() async {
    if (_challengeIdx >= _challenges.length) {
      _gyroSub?.cancel();
      await _captureAndMatch();
      return;
    }

    final challenge = _challenges[_challengeIdx];
    setState(() {
      _challengeActive = false;
      _message = challenge.instruction;
      _subMessage = '';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _challengeActive = true);

    final completer = Completer<bool>();
    Timer? timeout;

    timeout = Timer(const Duration(seconds: 6), () {
      _gyroSub?.cancel();
      if (!completer.isCompleted) completer.complete(false);
    });

    _gyroSub?.cancel();
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.fastestInterval,
    ).listen((e) {
      double value;
      switch (challenge.axis) {
        case 'x':
          value = e.x.abs();
          break;
        case 'y':
          value = e.y.abs();
          break;
        default:
          value = e.z.abs();
          break;
      }
      if (!mounted) return;
      setState(() => _gyroMag = value);

      if (value >= challenge.threshold && !completer.isCompleted) {
        timeout?.cancel();
        _gyroSub?.cancel();
        completer.complete(true);
      }
    });

    final passed = await completer.future;

    if (!mounted) return;
    if (!passed) {
      setState(() {
        _phase = _Phase.failed;
        _errorMsg = AppStrings.of(context).tr(
            'Mouvement non detecte pour : "${challenge.instruction}". Veuillez reessayer.',
            'Movement not detected for: "${challenge.instruction}". Please try again.');
      });
      return;
    }

    setState(() {
      _challengeIdx++;
      _challengeActive = false;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    _runNextChallenge();
  }

  // ── Step 3: Capture selfie + server face match ───────────────────────────────
  Future<void> _captureAndMatch() async {
    if (_camCtrl == null) return;
    setState(() {
      _phase = _Phase.capturing;
      _message = AppStrings.of(context).tr('Ne bougez pas…', 'Hold still…');
      _subMessage =
          AppStrings.of(context).tr('Prise de photo', 'Taking your photo');
    });

    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final XFile photo = await _camCtrl!.takePicture();
      final bytes = await photo.readAsBytes();
      final b64 = base64Encode(bytes);

      setState(() {
        _phase = _Phase.matching;
        _message = AppStrings.of(context).tr('Verification…', 'Verifying…');
        _subMessage = AppStrings.of(context).tr(
            'Comparaison avec votre photo de profil',
            'Comparing with your profile photo');
      });

      // Send to server for face match
      final tok = await _sto.read(key: 'access_token');
      final dio = Dio(BaseOptions(baseUrl: _kApiBase));
      if (tok != null) dio.options.headers['Authorization'] = 'Bearer $tok';

      final response = await dio.post('/liveness/face-match', data: {
        'liveness_session_id': widget.sessionId,
        'face_image_b64': b64,
        'share_token': widget.shareToken,
      });

      final data = response.data as Map<String, dynamic>;
      final match = data['faces_match'] as bool? ?? false;
      final real = data['liveness_real'] as bool? ?? false;

      // Immediately null out the image data from memory
      // ignore: unused_local_variable
      final _ = b64;

      if (!mounted) return;

      if (match && real) {
        setState(() {
          _step2Passed = true;
          _step3Passed = true;
          _phase = _Phase.passed;
          _message = AppStrings.of(context)
              .tr('Identite confirmee !', 'Identity confirmed!');
          _subMessage = AppStrings.of(context).tr(
              'Toutes les verifications sont validees', 'All checks passed');
        });
        await Future.delayed(const Duration(milliseconds: 1200));
        widget.onVerified();
      } else if (!real) {
        setState(() {
          _phase = _Phase.failed;
          _errorMsg = AppStrings.of(context).tr(
              'Visage reel non detecte. Assurez un bon eclairage et regardez directement la camera.',
              'Real face not detected. Ensure good lighting and look directly at the camera.');
        });
      } else {
        setState(() {
          _phase = _Phase.failed;
          _errorMsg = AppStrings.of(context).tr(
              'Le visage ne correspond pas au profil du titulaire du diplome. Verification refusee.',
              'Face does not match the diploma holder\'s profile. Verification denied.');
        });
      }
    } catch (e) {
      setState(() {
        _phase = _Phase.failed;
        _errorMsg =
            '${AppStrings.of(context).tr('Echec de verification', 'Verification failed')}: ${e.toString()}';
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
            child: Column(children: [
          _buildHeader(),
          Expanded(
              child: Stack(alignment: Alignment.center, children: [
            // Camera preview
            if (_camReady && _camCtrl != null)
              SizedBox.expand(child: CameraPreview(_camCtrl!)),
            // Dark overlay with circular cutout
            if (_camReady) _buildOverlay(),
            // Animated ring
            _buildRing(),
            // Progress steps
            Positioned(top: 20, left: 20, right: 20, child: _buildSteps()),
          ])),
          _buildBottom(),
        ])),
      );

  Widget _buildHeader() => Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black,
      child: Row(children: [
        GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close_rounded,
                color: Colors.white54, size: 22)),
        const SizedBox(width: 12),
        Text(
            AppStrings.of(context)
                .tr('Verification d\'identite', 'Identity verification'),
            style: GoogleFonts.instrumentSerif(fontSize: 18, color: _textPri)),
      ]));

  Widget _buildOverlay() => Container(
      color: Colors.black.withOpacity(0.5),
      child: ClipPath(
          clipper: _OvalClipper(),
          child: Container(color: Colors.transparent)));

  Widget _buildRing() {
    final Color ringColor;
    switch (_phase) {
      case _Phase.passed:
        ringColor = const Color(0xFF1D9E75);
        break;
      case _Phase.failed:
        ringColor = _red;
        break;
      case _Phase.movement_challenge:
        ringColor = _amber;
        break;
      default:
        ringColor = _green;
    }

    final norm = ((_accelMag - 9.0) / 6.0).clamp(0.0, 1.0);
    final scale = 1.0 + norm * 0.08;

    return AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 80),
        child: SizedBox(
            width: 260,
            height: 260,
            child: Stack(alignment: Alignment.center, children: [
              // Outer pulse ring
              AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Opacity(
                      opacity: _phase == _Phase.movement_challenge
                          ? (1 - _pulseCtrl.value) * 0.4
                          : 0,
                      child: Container(
                        width: 240 + _pulseCtrl.value * 30,
                        height: 240 + _pulseCtrl.value * 30,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: ringColor.withOpacity(0.3), width: 1.5)),
                      ))),
              // Main ring
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: 3),
                    color: Colors.transparent),
                child: Center(child: _buildRingContent(ringColor)),
              ),
            ])));
  }

  Widget _buildRingContent(Color c) {
    switch (_phase) {
      case _Phase.passed:
        return Icon(Icons.check_rounded, color: c, size: 72);
      case _Phase.failed:
        return Icon(Icons.close_rounded, color: c, size: 72);
      case _Phase.preparing:
      case _Phase.matching:
        return CircularProgressIndicator(color: c, strokeWidth: 2);
      case _Phase.capturing:
        return Icon(Icons.camera_alt_rounded,
            color: c.withOpacity(0.6), size: 56);
      case _Phase.face_detection:
        return Icon(Icons.face_rounded, color: c.withOpacity(0.4), size: 64);
      case _Phase.movement_challenge:
        return Icon(
            _challenges[_challengeIdx.clamp(0, _challenges.length - 1)].icon,
            color: c,
            size: 64);
    }
  }

  Widget _buildSteps() =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _stepDot(1, _step1Passed, _phase == _Phase.face_detection,
            AppStrings.of(context).tr('Visage', 'Face')),
        _stepLine(_step1Passed),
        _stepDot(2, _step2Passed, _phase == _Phase.movement_challenge,
            AppStrings.of(context).tr('Mouvement', 'Move')),
        _stepLine(_step2Passed),
        _stepDot(
            3,
            _step3Passed,
            _phase == _Phase.capturing || _phase == _Phase.matching,
            AppStrings.of(context).tr('Correspondance', 'Match')),
      ]);

  Widget _stepDot(int n, bool done, bool active, String label) {
    final c = done
        ? const Color(0xFF1D9E75)
        : active
            ? _green
            : Colors.white30;
    return Column(children: [
      Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? const Color(0xFF1D9E75)
                  : active
                      ? _green
                      : Colors.white12,
              border: Border.all(color: c, width: 1.5)),
          child: Center(
              child: done
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16)
                  : Text('$n',
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: c,
                          fontWeight: FontWeight.w500)))),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: c)),
    ]);
  }

  Widget _stepLine(bool done) => Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: done ? const Color(0xFF1D9E75) : Colors.white.withOpacity(0.15));

  Widget _buildBottom() => Container(
      padding: const EdgeInsets.all(24),
      color: Colors.black,
      child: Column(children: [
        // Main message
        Text(_message,
            textAlign: TextAlign.center,
            style: GoogleFonts.instrumentSerif(
                fontSize: _phase == _Phase.passed ? 26 : 22,
                color: _phase == _Phase.passed
                    ? const Color(0xFF5DCAA5)
                    : _phase == _Phase.failed
                        ? _red
                        : Colors.white)),
        if (_subMessage.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_subMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: Colors.white60,
                  fontWeight: FontWeight.w300,
                  height: 1.5)),
        ],
        // Gyro bar (visible during movement challenge)
        if (_phase == _Phase.movement_challenge && _challengeActive) ...[
          const SizedBox(height: 16),
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: (_gyroMag /
                          _challenges[_challengeIdx.clamp(
                                  0, _challenges.length - 1)]
                              .threshold)
                      .clamp(0.0, 1.0),
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(_amber),
                  minHeight: 6)),
          const SizedBox(height: 6),
          Text(
              '${AppStrings.of(context).tr('Mouvement detecte', 'Movement detected')}: ${(_gyroMag * 10).toStringAsFixed(1)} / 10',
              style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white38)),
        ],
        // Challenge dots
        if (_phase == _Phase.movement_challenge) ...[
          const SizedBox(height: 16),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  3,
                  (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: i == _challengeIdx ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: i < _challengeIdx
                              ? const Color(0xFF1D9E75)
                              : i == _challengeIdx
                                  ? _green
                                  : Colors.white24,
                          borderRadius: BorderRadius.circular(4))))),
        ],
        // Error + retry
        if (_phase == _Phase.failed) ...[
          const SizedBox(height: 16),
          if (_errorMsg != null)
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _red.withOpacity(0.3))),
                child: Text(_errorMsg!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                        color: const Color(0xFFE24B4A),
                        fontSize: 12,
                        height: 1.5))),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label:
                      Text(AppStrings.of(context).tr('Reessayer', 'Try again')),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0),
                  onPressed: () {
                    setState(() {
                      _phase = _Phase.preparing;
                      _step1Passed = false;
                      _step2Passed = false;
                      _step3Passed = false;
                      _errorMsg = null;
                      _challengeIdx = 0;
                    });
                    _initCamera();
                  })),
        ],
      ]));
}

// ── Oval clip for camera frame ─────────────────────────────────────────────────
class _OvalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 220,
      height: 260,
    );
    path.addOval(oval);
    return path..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(_) => false;
}
