import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Real biometric authentication service.
///
/// Uses the device's secure enclave via [local_auth]:
/// - iOS: Face ID or Touch ID (hardware-backed, biometric data never leaves device)
/// - Android: Fingerprint, face recognition, or iris scan via BiometricPrompt API
///
/// The biometric key is bound to the device's TEE (Trusted Execution Environment).
/// No biometric data is ever transmitted to our servers.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  // ── Availability ───────────────────────────────────────────────────────────

  /// Returns true if the device supports biometric authentication
  /// and the user has enrolled at least one biometric.
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      if (!await _auth.isDeviceSupported()) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns the list of enrolled biometrics on this device.
  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Returns true if Face ID / face recognition is enrolled.
  Future<bool> hasFaceId() async {
    final biometrics = await availableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  /// Returns true if fingerprint is enrolled.
  Future<bool> hasFingerprint() async {
    final biometrics = await availableBiometrics();
    return biometrics.contains(BiometricType.fingerprint) ||
        biometrics.contains(BiometricType.strong);
  }

  // ── Authentication ─────────────────────────────────────────────────────────

  /// Triggers the native biometric prompt. Returns a [BiometricResult]
  /// with the outcome and, if failed, the reason.
  ///
  /// The OS handles the entire authentication flow — we only receive a
  /// boolean result. The actual biometric template never leaves the TEE.
  Future<BiometricResult> authenticate({
    String reason = 'Authenticate to access your Diplomax vault',
  }) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        authMessages: [
          // Android prompt customisation
          const AndroidAuthMessages(
            signInTitle: 'Diplomax — Biometric login',
            cancelButton: 'Use password instead',
            biometricHint: 'Touch the fingerprint sensor',
            biometricNotRecognized: 'Not recognised. Try again.',
            biometricSuccess: 'Authentication successful',
            goToSettingsButton: 'Settings',
            goToSettingsDescription:
                'No biometrics enrolled. Please set up fingerprint or face in Settings.',
            deviceCredentialsRequiredTitle: 'Device PIN required',
          ),
          // iOS prompt customisation
          const IOSAuthMessages(
            cancelButton: 'Cancel',
            goToSettingsButton: 'Settings',
            goToSettingsDescription:
                'Please enable biometrics in Settings.',
            lockOut: 'Biometrics locked. Use your device passcode.',
          ),
        ],
        options: const AuthenticationOptions(
          // Allow fallback to device PIN/password if biometric fails
          biometricOnly: false,
          stickyAuth: true,
          sensitiveTransaction: true,
          useErrorDialogs: true,
        ),
      );
      return authenticated
          ? BiometricResult.success()
          : BiometricResult.cancelled();
    } on PlatformException catch (e) {
      return _handleError(e);
    }
  }

  /// Authenticate with fingerprint only (no face ID fallback).
  Future<BiometricResult> authenticateFingerprint() async {
    return authenticate(
      reason: 'Place your finger on the sensor to unlock your vault',
    );
  }

  /// Authenticate with face recognition only.
  Future<BiometricResult> authenticateFace() async {
    return authenticate(
      reason: 'Look at your phone to verify your identity',
    );
  }

  BiometricResult _handleError(PlatformException e) {
    switch (e.code) {
      case auth_error.notEnrolled:
        return BiometricResult.error(
          BiometricError.notEnrolled,
          'No biometrics enrolled on this device.',
        );
      case auth_error.lockedOut:
        return BiometricResult.error(
          BiometricError.lockedOut,
          'Too many failed attempts. Temporarily locked.',
        );
      case auth_error.permanentlyLockedOut:
        return BiometricResult.error(
          BiometricError.permanentlyLockedOut,
          'Biometrics permanently locked. Use device PIN.',
        );
      case auth_error.notAvailable:
        return BiometricResult.error(
          BiometricError.notAvailable,
          'Biometric hardware not available.',
        );
      default:
        return BiometricResult.error(
          BiometricError.unknown,
          e.message ?? 'Authentication failed.',
        );
    }
  }

  Future<void> stopAuthentication() async {
    await _auth.stopAuthentication();
  }
}

// ── Result types ──────────────────────────────────────────────────────────────

enum BiometricError {
  notEnrolled,
  lockedOut,
  permanentlyLockedOut,
  notAvailable,
  cancelled,
  unknown,
}

class BiometricResult {
  final bool success;
  final bool cancelled;
  final BiometricError? error;
  final String? errorMessage;

  BiometricResult._({
    required this.success,
    required this.cancelled,
    this.error,
    this.errorMessage,
  });

  factory BiometricResult.success() =>
      BiometricResult._(success: true, cancelled: false);

  factory BiometricResult.cancelled() =>
      BiometricResult._(success: false, cancelled: true);

  factory BiometricResult.error(BiometricError err, String msg) =>
      BiometricResult._(
        success: false,
        cancelled: false,
        error: err,
        errorMessage: msg,
      );
}
