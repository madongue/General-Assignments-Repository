import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Real accelerometer-based anti-fraud and liveness detection service.
///
/// Uses [sensors_plus] to read actual hardware sensor data from:
/// - Accelerometer: linear acceleration (m/s²) — detects gravity + movement
/// - Gyroscope: angular velocity (rad/s) — detects rotation
/// - UserAccelerometer: linear acceleration without gravity component
///
/// Algorithm:
/// 1. Sample 60 readings over ~2 seconds
/// 2. Compute variance of the magnitude vector across samples
/// 3. Real humans holding a phone exhibit micro-tremors (variance 0.05–3.0)
/// 4. Emulators produce perfect zeros (variance ≈ 0.0)
/// 5. A phone lying completely still on a table shows gravity-only (low variance)
/// 6. Robots/automated scripts: abnormal patterns above threshold
class AntiFraudSensorService {
  static const _sampleCount = 60;
  static const _sampleDurationMs = 2000;
  static const _humanMinVariance = 0.03;
  static const _humanMaxVariance = 15.0;
  static const _suspiciousVariance = 25.0;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  final List<double> _accelMagnitudes = [];
  final List<double> _gyroMagnitudes = [];

  bool _isCollecting = false;

  // ── Main Analysis ──────────────────────────────────────────────────────────

  /// Performs a full anti-fraud analysis using real sensor hardware.
  /// Returns a [SensorAnalysisResult] with findings.
  Future<SensorAnalysisResult> analyze() async {
    _accelMagnitudes.clear();
    _gyroMagnitudes.clear();
    _isCollecting = true;

    // Subscribe to REAL hardware accelerometer events
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((event) {
      if (!_isCollecting) return;
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      _accelMagnitudes.add(magnitude);
    });

    // Subscribe to REAL hardware gyroscope events
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((event) {
      if (!_isCollecting) return;
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      _gyroMagnitudes.add(magnitude);
    });

    // Collect for the full sample duration
    await Future.delayed(const Duration(milliseconds: _sampleDurationMs));
    _isCollecting = false;
    await _accelSub?.cancel();
    await _gyroSub?.cancel();

    return _computeResult();
  }

  SensorAnalysisResult _computeResult() {
    if (_accelMagnitudes.length < 10) {
      // Not enough samples — sensor might be unavailable (emulator)
      return SensorAnalysisResult(
        isHuman: false,
        isPossibleEmulator: true,
        confidence: 0.0,
        accelVariance: 0.0,
        gyroVariance: 0.0,
        sampleCount: _accelMagnitudes.length,
        reason: 'Insufficient sensor data — possible emulator',
      );
    }

    final accelVariance = _variance(_accelMagnitudes);
    final gyroVariance = _variance(_gyroMagnitudes);

    // Emulator detection: perfect zeros or near-zero variance
    if (accelVariance < 0.001 && gyroVariance < 0.001) {
      return SensorAnalysisResult(
        isHuman: false,
        isPossibleEmulator: true,
        confidence: 0.0,
        accelVariance: accelVariance,
        gyroVariance: gyroVariance,
        sampleCount: _accelMagnitudes.length,
        reason: 'Sensor values are suspiciously constant — emulator detected',
      );
    }

    // Abnormal high movement (robot or shaking device)
    if (accelVariance > _suspiciousVariance) {
      return SensorAnalysisResult(
        isHuman: false,
        isPossibleEmulator: false,
        confidence: 0.2,
        accelVariance: accelVariance,
        gyroVariance: gyroVariance,
        sampleCount: _accelMagnitudes.length,
        reason: 'Abnormally high movement detected',
      );
    }

    // Human micro-tremor range
    final isHuman = accelVariance >= _humanMinVariance &&
        accelVariance <= _humanMaxVariance;

    // Confidence score: how centred is the variance in the human range
    final confidence = isHuman
        ? _clamp(
            1.0 -
                (accelVariance - 0.5).abs() /
                    (_humanMaxVariance - _humanMinVariance),
            0.5,
            0.99,
          )
        : 0.0;

    return SensorAnalysisResult(
      isHuman: isHuman,
      isPossibleEmulator: false,
      confidence: confidence,
      accelVariance: accelVariance,
      gyroVariance: gyroVariance,
      sampleCount: _accelMagnitudes.length,
      reason: isHuman
          ? 'Natural human micro-movement detected'
          : 'No human movement pattern detected',
    );
  }

  // ── Real-time Stream ───────────────────────────────────────────────────────

  /// Provides a continuous stream of accelerometer magnitude values
  /// for real-time UI feedback during liveness checks.
  Stream<double> get accelMagnitudeStream => accelerometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).map(
        (e) => sqrt(e.x * e.x + e.y * e.y + e.z * e.z),
      );

  /// Provides a continuous stream of gyroscope magnitude values.
  Stream<double> get gyroMagnitudeStream => gyroscopeEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).map(
        (e) => sqrt(e.x * e.x + e.y * e.y + e.z * e.z),
      );

  // ── Liveness Movement Detection ────────────────────────────────────────────

  /// Detects whether the user performed a specific movement.
  /// Used in the multi-step liveness check (turn left, turn right, blink, etc.).
  ///
  /// [expectedAxis]: 'x' for left/right, 'y' for up/down, 'z' for rotation
  /// [threshold]: minimum angular velocity (rad/s) to count as movement
  Future<bool> detectMovement({
    required String expectedAxis,
    double threshold = 0.8,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final completer = Completer<bool>();
    StreamSubscription<GyroscopeEvent>? sub;
    Timer? timer;

    timer = Timer(timeout, () {
      sub?.cancel();
      if (!completer.isCompleted) completer.complete(false);
    });

    sub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.fastestInterval,
    ).listen((event) {
      double value;
      switch (expectedAxis) {
        case 'x': value = event.x.abs(); break;
        case 'y': value = event.y.abs(); break;
        case 'z': value = event.z.abs(); break;
        default:  value = 0.0;
      }
      if (value >= threshold) {
        timer?.cancel();
        sub?.cancel();
        if (!completer.isCompleted) completer.complete(true);
      }
    });

    return completer.future;
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  double _variance(List<double> data) {
    if (data.length < 2) return 0.0;
    final mean = data.reduce((a, b) => a + b) / data.length;
    final squaredDiffs = data.map((x) => pow(x - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / data.length;
  }

  double _clamp(double value, double min, double max) =>
      value.clamp(min, max).toDouble();

  void dispose() {
    _isCollecting = false;
    _accelSub?.cancel();
    _gyroSub?.cancel();
  }
}

// ── Result ────────────────────────────────────────────────────────────────────

class SensorAnalysisResult {
  final bool isHuman;
  final bool isPossibleEmulator;
  final double confidence;
  final double accelVariance;
  final double gyroVariance;
  final int sampleCount;
  final String reason;

  const SensorAnalysisResult({
    required this.isHuman,
    required this.isPossibleEmulator,
    required this.confidence,
    required this.accelVariance,
    required this.gyroVariance,
    required this.sampleCount,
    required this.reason,
  });

  bool get isHighConfidence => confidence >= 0.75;
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
}
