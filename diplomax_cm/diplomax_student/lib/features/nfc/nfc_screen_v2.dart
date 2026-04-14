// ═══════════════════════════════════════════════════════════════════════════
// DIPLOMAX CM — Real NFC Screen
// Uses nfc_manager to read NDEF NFC tags on real devices
// Also handles NFC chip writing for the university app
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:dio/dio.dart';
import '../../l10n/app_strings.dart';

const _green = Color(0xFF0F6E56);
const _greenLight = Color(0xFFE1F5EE);
const _red = Color(0xFFA32D2D);
const _redLight = Color(0xFFFCEBEB);
const _bg = Color(0xFFF7F6F2);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE0DDD5);
const _textPri = Color(0xFF1A1A1A);
const _textSec = Color(0xFF6B6B6B);

// ─── NFC Service ─────────────────────────────────────────────────────────────

class NfcService {
  static const _nfcPrefix = 'diplomax://doc/';

  /// Returns true if the device supports NFC and it is enabled.
  Future<bool> isAvailable() => NfcManager.instance.isAvailable();

  /// Starts reading an NFC tag. The callback fires when a tag is detected.
  /// Reads the NDEF message payload and extracts the document ID + hash.
  Future<void> startReading({
    required void Function(NfcReadResult) onResult,
    required void Function(String) onError,
  }) async {
    final available = await isAvailable();
    if (!available) {
      onError(
          'Le NFC n\'est pas disponible sur cet appareil ou est desactive.');
      return;
    }

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            onResult(
                NfcReadResult.error('Le tag ne contient pas de donnees NDEF'));
            return;
          }

          final message = ndef.cachedMessage;
          if (message == null || message.records.isEmpty) {
            onResult(NfcReadResult.error('Le tag NFC est vide'));
            return;
          }

          // Read the first NDEF text record
          final record = message.records.first;
          final payload = _decodeNdefPayload(record);

          if (!payload.startsWith(_nfcPrefix)) {
            onResult(NfcReadResult.error(
                'Le tag ne contient pas un justificatif Diplomax'));
            return;
          }

          // Format: diplomax://doc/{documentId}?hash={sha256}
          final content = payload.substring(_nfcPrefix.length);
          final parts = content.split('?hash=');
          final docId = parts[0];
          final hash = parts.length > 1 ? parts[1] : null;

          // Read NFC UID
          final uid = _extractUid(tag);

          onResult(NfcReadResult.success(
            documentId: docId,
            hashSha256: hash,
            nfcUid: uid,
          ));
        } catch (e) {
          onResult(NfcReadResult.error('Erreur de lecture : ${e.toString()}'));
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );
  }

  /// Writes a Diplomax NDEF record to an NFC chip.
  /// Used by the university app when embedding a hash into a physical diploma.
  Future<NfcWriteResult> writeToTag({
    required String documentId,
    required String hashSha256,
  }) async {
    final available = await isAvailable();
    if (!available) {
      return NfcWriteResult(success: false, error: 'NFC indisponible');
    }

    final completer = _Completer<NfcWriteResult>();

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            completer.complete(NfcWriteResult(
                success: false, error: 'Le tag ne prend pas en charge NDEF'));
            return;
          }
          if (!ndef.isWritable) {
            completer.complete(NfcWriteResult(
                success: false, error: 'Le tag est en lecture seule'));
            return;
          }

          final payload = '$_nfcPrefix$documentId?hash=$hashSha256';
          final message = NdefMessage([
            NdefRecord.createText(payload),
          ]);

          await ndef.write(message);

          final uid = _extractUid(tag);
          completer.complete(NfcWriteResult(
            success: true,
            nfcUid: uid,
            message: 'Puce NFC ecrite avec succes',
          ));
        } catch (e) {
          completer.complete(NfcWriteResult(
            success: false,
            error: 'Ecriture echouee : ${e.toString()}',
          ));
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );

    return completer.future;
  }

  Future<void> stopSession() => NfcManager.instance.stopSession();

  String _decodeNdefPayload(NdefRecord record) {
    // Text record: payload[0] = language code length, rest = text
    final payload = record.payload;
    if (payload.isEmpty) return '';
    // Skip status byte and language code
    final langLen = payload[0] & 0x3F;
    final textBytes = payload.sublist(1 + langLen);
    return utf8.decode(textBytes);
  }

  String _extractUid(NfcTag tag) {
    final data = tag.data;
    if (data.containsKey('nfca')) {
      final identifier = data['nfca']['identifier'] as Uint8List?;
      return identifier
              ?.map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(':') ??
          '';
    }
    if (data.containsKey('nfcb')) {
      final identifier = data['nfcb']['applicationData'] as Uint8List?;
      return identifier
              ?.map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(':') ??
          '';
    }
    return 'unknown';
  }
}

class _Completer<T> {
  T? _value;
  void Function(T)? _resolve;
  void complete(T value) {
    _value = value;
    _resolve?.call(value);
  }

  Future<T> get future => Future(() async {
        while (_value == null) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
        return _value as T;
      });
}

// ─── Result types ─────────────────────────────────────────────────────────────

class NfcReadResult {
  final bool success;
  final String? documentId;
  final String? hashSha256;
  final String? nfcUid;
  final String? error;

  NfcReadResult._(
      {required this.success,
      this.documentId,
      this.hashSha256,
      this.nfcUid,
      this.error});

  factory NfcReadResult.success({
    required String documentId,
    String? hashSha256,
    String? nfcUid,
  }) =>
      NfcReadResult._(
          success: true,
          documentId: documentId,
          hashSha256: hashSha256,
          nfcUid: nfcUid);

  factory NfcReadResult.error(String msg) =>
      NfcReadResult._(success: false, error: msg);
}

class NfcWriteResult {
  final bool success;
  final String? nfcUid;
  final String? message;
  final String? error;
  NfcWriteResult(
      {required this.success, this.nfcUid, this.message, this.error});
}

// ─── NFC Read Screen (Student App) ───────────────────────────────────────────

class NfcScreen extends ConsumerStatefulWidget {
  const NfcScreen({super.key});
  @override
  ConsumerState<NfcScreen> createState() => _NfcScreenState();
}

class _NfcScreenState extends ConsumerState<NfcScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  final _nfc = NfcService();

  _NfcPhase _phase = _NfcPhase.idle;
  NfcReadResult? _readResult;
  Map<String, dynamic>? _verifyData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulse =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _nfc.stopSession();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _phase = _NfcPhase.scanning;
      _error = null;
      _readResult = null;
      _verifyData = null;
    });

    await _nfc.startReading(
      onResult: (result) async {
        setState(() => _readResult = result);
        if (result.success && result.documentId != null) {
          await _verifyOnBackend(result.documentId!, result.hashSha256);
        } else {
          setState(() {
            _phase = _NfcPhase.error;
            _error = result.error;
          });
        }
      },
      onError: (err) => setState(() {
        _phase = _NfcPhase.error;
        _error = err;
      }),
    );
  }

  Future<void> _verifyOnBackend(String documentId, String? hash) async {
    setState(() => _phase = _NfcPhase.verifying);
    try {
      final dio = Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('API_BASE_URL',
              defaultValue: 'https://diplomax-backend.onrender.com/v1')));
      final r = await dio.get('/nfc/verify/${_readResult!.nfcUid}');
      setState(() {
        _verifyData = r.data as Map<String, dynamic>;
        _phase = _NfcPhase.done;
      });
    } catch (e) {
      setState(() {
        _phase = _NfcPhase.error;
        _error =
            '${AppStrings.of(context).tr('Verification echouee', 'Verification failed')}: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black87,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: BackButton(
              color: Colors.white, onPressed: () => context.go('/home')),
          title: Text(
              AppStrings.of(context).tr('Verification NFC', 'NFC verification'),
              style: GoogleFonts.instrumentSerif(
                  fontSize: 20, color: Colors.white)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            const Spacer(),
            _buildTitle(),
            const SizedBox(height: 48),
            _buildNfcRing(),
            const SizedBox(height: 40),
            _buildStatus(),
            const Spacer(),
            _buildAction(),
            const SizedBox(height: 20),
          ]),
        ),
      );

  Widget _buildTitle() {
    String t, s;
    switch (_phase) {
      case _NfcPhase.idle:
        t = AppStrings.of(context)
            .tr('Approchez le diplome du telephone', 'Tap diploma to phone');
        s = AppStrings.of(context).tr(
            'Maintenez le diplome physique contre l\'arriere du telephone.',
            'Hold the physical diploma against the back of your phone.');
        break;
      case _NfcPhase.scanning:
        t = AppStrings.of(context).tr('Pret a scanner', 'Ready to scan');
        s = AppStrings.of(context).tr(
            'Approchez la puce NFC du diplome du telephone.',
            'Bring the NFC chip on the diploma close to the phone.');
        break;
      case _NfcPhase.verifying:
        t = AppStrings.of(context)
            .tr('Verification sur blockchain...', 'Verifying on blockchain...');
        s = AppStrings.of(context).tr(
            'Verification croisee avec Hyperledger Fabric.',
            'Cross-checking with Hyperledger Fabric.');
        break;
      case _NfcPhase.done:
        t = AppStrings.of(context)
            .tr('Diplome authentifie', 'Diploma authenticated');
        s = AppStrings.of(context).tr(
            'Puce NFC verifiee. Document authentique.',
            'NFC chip verified. Document is authentic.');
        break;
      case _NfcPhase.error:
        t = AppStrings.of(context)
            .tr('Verification echouee', 'Verification failed');
        s = _error ??
            AppStrings.of(context)
                .tr('Une erreur est survenue.', 'An error occurred.');
        break;
    }
    final c = _phase == _NfcPhase.done
        ? const Color(0xFF5DCAA5)
        : _phase == _NfcPhase.error
            ? Colors.redAccent
            : Colors.white;
    return Column(children: [
      Text(t,
          textAlign: TextAlign.center,
          style: GoogleFonts.instrumentSerif(fontSize: 28, color: c)),
      const SizedBox(height: 8),
      Text(s,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
              fontSize: 13,
              color: Colors.white60,
              fontWeight: FontWeight.w300,
              height: 1.6)),
    ]);
  }

  Widget _buildNfcRing() {
    final color = _phase == _NfcPhase.done
        ? const Color(0xFF1D9E75)
        : _phase == _NfcPhase.error
            ? Colors.redAccent
            : _phase == _NfcPhase.scanning
                ? const Color(0xFF0F6E56)
                : Colors.white30;
    return SizedBox(
        width: 200,
        height: 200,
        child: Stack(alignment: Alignment.center, children: [
          // Animated outer ring (only during scanning)
          if (_phase == _NfcPhase.scanning)
            AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Opacity(
                    opacity: (1 - _pulse.value) * 0.5,
                    child: Container(
                      width: 180 + _pulse.value * 40,
                      height: 180 + _pulse.value * 40,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF1D9E75), width: 1.5)),
                    ))),
          // Core circle
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
                border: Border.all(color: color, width: 2.5)),
            child: Center(
                child: Icon(
              _phase == _NfcPhase.done
                  ? Icons.check_rounded
                  : _phase == _NfcPhase.error
                      ? Icons.close_rounded
                      : _phase == _NfcPhase.verifying
                          ? null
                          : Icons.nfc_rounded,
              color: color,
              size: _phase == _NfcPhase.verifying ? 0 : 56,
            )),
          ),
          if (_phase == _NfcPhase.verifying)
            const CircularProgressIndicator(
                color: Color(0xFF1D9E75), strokeWidth: 2),
        ]));
  }

  Widget _buildStatus() {
    if (_phase == _NfcPhase.done && _verifyData != null) {
      final d = _verifyData!;
      return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: _greenLight, borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ...[
              [
                AppStrings.of(context).tr('Etudiant', 'Student'),
                d['student_name'] ?? ''
              ],
              [
                AppStrings.of(context).tr('Matricule', 'Matricule'),
                d['matricule'] ?? ''
              ],
              [
                AppStrings.of(context).tr('Document', 'Document'),
                d['title'] ?? ''
              ],
              [
                AppStrings.of(context).tr('Universite', 'University'),
                d['university'] ?? ''
              ],
              [
                AppStrings.of(context).tr('Mention', 'Mention'),
                d['mention'] ?? ''
              ],
              [
                AppStrings.of(context).tr('Blockchain', 'Blockchain'),
                d['blockchain_authentic'] == true
                    ? AppStrings.of(context).tr('Verifiee ✓', 'Verified ✓')
                    : AppStrings.of(context).tr('Non ancree', 'Not anchored')
              ],
            ].map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(
                      width: 90,
                      child: Text(r[0],
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: _textSec))),
                  Expanded(
                      child: Text(r[1],
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _textPri))),
                ]))),
          ]));
    }
    return const SizedBox.shrink();
  }

  Widget _buildAction() {
    if (_phase == _NfcPhase.idle || _phase == _NfcPhase.error) {
      return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
              icon: const Icon(Icons.nfc_rounded, size: 20),
              label: Text(_phase == _NfcPhase.error
                  ? AppStrings.of(context).tr('Reessayer', 'Try again')
                  : AppStrings.of(context)
                      .tr('Demarrer le scan NFC', 'Start NFC scan')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0),
              onPressed: _startScan));
    }
    if (_phase == _NfcPhase.done) {
      return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0),
              onPressed: () => setState(() {
                    _phase = _NfcPhase.idle;
                    _readResult = null;
                    _verifyData = null;
                  }),
              child: Text(AppStrings.of(context)
                  .tr('Scanner un autre diplome', 'Scan another diploma'))));
    }
    return const SizedBox.shrink();
  }
}

enum _NfcPhase { idle, scanning, verifying, done, error }
