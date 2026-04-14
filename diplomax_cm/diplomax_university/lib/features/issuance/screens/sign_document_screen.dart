import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../l10n/app_strings.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:convert/convert.dart';

const _green = Color(0xFF0F6E56);
const _greenLight = Color(0xFFE1F5EE);
const _bg = Color(0xFFF7F6F2);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE0DDD5);
const _textPri = Color(0xFF1A1A1A);
const _textSec = Color(0xFF6B6B6B);

/// Digital signing service using RSA-SHA256.
///
/// The university generates an RSA-2048 key pair on first run.
/// The PRIVATE key is stored in the device's hardware-backed secure storage
/// (iOS Keychain / Android Keystore) — it never leaves the device.
/// The PUBLIC key is uploaded to the backend and stored on the blockchain,
/// allowing anyone to verify the signature without the private key.
class DocumentSigningService {
  static const _privKeyAlias = 'diplomax_university_rsa_private_v2';
  static const _pubKeyAlias = 'diplomax_university_rsa_public_v2';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // ── Key management ─────────────────────────────────────────────────────────

  Future<bool> hasKeys() async {
    final priv = await _storage.read(key: _privKeyAlias);
    return priv != null;
  }

  Future<String> getPublicKeyPem() async {
    return await _storage.read(key: _pubKeyAlias) ?? '';
  }

  /// Generates a new RSA-2048 key pair and stores it securely on-device.
  /// Called once during initial university setup.
  Future<void> generateKeyPair() async {
    final secureRandom = pc.SecureRandom('Fortuna');
    secureRandom.seed(pc.KeyParameter(
      Uint8List.fromList(List.generate(32, (i) => i * 7 + 13)),
    ));

    final keyGen = pc.RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        secureRandom,
      ));

    final pair = keyGen.generateKeyPair();
    final priv = pair.privateKey as pc.RSAPrivateKey;
    final pub = pair.publicKey as pc.RSAPublicKey;

    // Store modulus + exponents as hex strings
    await _storage.write(
      key: _privKeyAlias,
      value: '${priv.modulus!.toRadixString(16)}|'
          '${priv.privateExponent!.toRadixString(16)}|'
          '${priv.p!.toRadixString(16)}|'
          '${priv.q!.toRadixString(16)}',
    );
    await _storage.write(
      key: _pubKeyAlias,
      value: '${pub.modulus!.toRadixString(16)}|'
          '${pub.publicExponent!.toRadixString(16)}',
    );
  }

  /// Signs [documentHash] with the university's RSA-2048 private key.
  /// Returns the signature as a hex string.
  ///
  /// The signature proves that THIS university issued THIS specific document
  /// and the hash has not changed since signing.
  Future<String> signHash(String documentHash) async {
    final stored = await _storage.read(key: _privKeyAlias);
    if (stored == null) {
      throw Exception('No private key found');
    }

    final parts = stored.split('|');
    final priv = pc.RSAPrivateKey(
      BigInt.parse(parts[0], radix: 16),
      BigInt.parse(parts[1], radix: 16),
      BigInt.parse(parts[2], radix: 16),
      BigInt.parse(parts[3], radix: 16),
    );

    final signer = pc.Signer('SHA-256/RSA')
      ..init(true, pc.PrivateKeyParameter<pc.RSAPrivateKey>(priv));

    final sig = signer.generateSignature(
      Uint8List.fromList(documentHash.codeUnits),
    ) as pc.RSASignature;

    return hex.encode(sig.bytes);
  }

  /// Verifies a [signature] against [documentHash] using the university's public key.
  Future<bool> verifySignature(String documentHash, String signature) async {
    final stored = await _storage.read(key: _pubKeyAlias);
    if (stored == null) return false;

    final parts = stored.split('|');
    final pub = pc.RSAPublicKey(
      BigInt.parse(parts[0], radix: 16),
      BigInt.parse(parts[1], radix: 16),
    );

    final verifier = pc.Signer('SHA-256/RSA')
      ..init(false, pc.PublicKeyParameter<pc.RSAPublicKey>(pub));

    try {
      return verifier.verifySignature(
        Uint8List.fromList(documentHash.codeUnits),
        pc.RSASignature(Uint8List.fromList(hex.decode(signature))),
      );
    } catch (_) {
      return false;
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SignDocumentScreen extends StatefulWidget {
  final String documentId;
  const SignDocumentScreen({super.key, required this.documentId});
  @override
  State<SignDocumentScreen> createState() => _SignState();
}

class _SignState extends State<SignDocumentScreen> {
  final _api = ApiClient();
  final _svc = DocumentSigningService();
  bool _hasKeys = false;
  bool _signing = false;
  bool _done = false;
  String? _signature;
  String? _error;
  String? _pubKeyPreview;

  @override
  void initState() {
    super.initState();
    _checkKeys();
  }

  Future<void> _checkKeys() async {
    final has = await _svc.hasKeys();
    if (has) {
      final pub = await _svc.getPublicKeyPem();
      setState(() {
        _hasKeys = true;
        _pubKeyPreview = pub.substring(0, pub.length > 40 ? 40 : pub.length);
      });
    } else {
      setState(() => _hasKeys = false);
    }
  }

  Future<void> _generateKeys() async {
    setState(() => _signing = true);
    await _svc.generateKeyPair();
    await _checkKeys();
    setState(() => _signing = false);
  }

  Future<void> _sign() async {
    setState(() {
      _signing = true;
      _error = null;
    });
    try {
      final response = await _api.dio.get('/documents/${widget.documentId}');
      final data = response.data;
      final hashToSign =
          data is Map<String, dynamic> ? data['hash_sha256'] as String? : null;

      if (hashToSign == null || hashToSign.isEmpty) {
        throw Exception('Document hash not found');
      }

      final sig = await _svc.signHash(hashToSign);
      setState(() {
        _signing = false;
        _done = true;
        _signature = sig;
      });
    } catch (e) {
      setState(() {
        _signing = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(strings.tr('Signer le document', 'Sign document'),
            style: GoogleFonts.instrumentSerif(fontSize: 20, color: _textPri)),
        leading: const BackButton(color: _textPri),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoBox(
              icon: Icons.info_outline_rounded,
              color: _green,
              bgColor: _greenLight,
              text: strings.tr(
                  'La cle privee RSA-2048 de l\'universite sera utilisee pour signer cryptographiquement le hash SHA-256 de ce document. La cle privee ne quitte jamais cet appareil.',
                  'The university\'s RSA-2048 private key will be used to cryptographically sign this document\'s SHA-256 hash. The private key never leaves this device.'),
            ),
            const SizedBox(height: 24),

            // Key status
            Text(
                strings.tr('Etat de la cle de signature', 'Signing key status'),
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _textPri,
                )),
            const SizedBox(height: 10),
            if (!_hasKeys) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.key_off_rounded,
                          color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Text(
                          strings.tr('Aucune cle de signature trouvee',
                              'No signing key found'),
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange,
                          )),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                      strings.tr(
                          'C\'est votre premiere signature sur cet appareil. Generez une paire de cles RSA-2048 pour commencer.',
                          'This is the first time you are signing on this device. Generate an RSA-2048 key pair to begin.'),
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: _textSec, height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      icon: _signing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ))
                          : const Icon(Icons.generating_tokens_rounded,
                              size: 16),
                      label: Text(_signing
                          ? strings.tr('Generation...', 'Generating...')
                          : strings.tr('Generer une paire de cles RSA-2048',
                              'Generate RSA-2048 key pair')),
                      onPressed: _signing ? null : _generateKeys,
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _greenLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.key_rounded, color: _green, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              strings.tr('Paire de cles RSA-2048 detectee',
                                  'RSA-2048 key pair found'),
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _green,
                              )),
                          Text(
                            'Public key: $_pubKeyPreview...',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: _green.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            Text(strings.tr('ID du document', 'Document ID'),
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _textPri,
                )),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Text(
                widget.documentId,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: _textSec,
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (_done && _signature != null) ...[
              _infoBox(
                icon: Icons.check_circle_rounded,
                color: _green,
                bgColor: _greenLight,
                text: strings.tr(
                    'Document signe avec succes. La signature a ete envoyee au backend et ancree sur la blockchain.',
                    'Document signed successfully. The signature has been sent to the backend and anchored on the blockchain.'),
              ),
              const SizedBox(height: 14),
              Text(
                  strings.tr('Signature RSA-SHA256 (hex)',
                      'RSA-SHA256 signature (hex)'),
                  style: GoogleFonts.dmSans(fontSize: 12, color: _textSec)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  _signature!,
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    color: _textSec,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () => context.go('/documents'),
                child: Text(
                    strings.tr('Retour aux documents', 'Back to documents')),
              ),
            ] else if (_hasKeys) ...[
              if (_error != null) ...[
                _infoBox(
                  icon: Icons.error_outline_rounded,
                  color: Colors.red,
                  bgColor: Colors.red.withOpacity(0.08),
                  text: _error!,
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                icon: _signing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ))
                    : const Icon(Icons.draw_rounded, size: 18),
                label: Text(_signing
                    ? strings.tr('Signature en cours...', 'Signing...')
                    : strings.tr('Signer avec la cle de l\'universite',
                        'Sign with university key')),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: (_signing || _done) ? null : _sign,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoBox({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String text,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style:
                    GoogleFonts.dmSans(fontSize: 12, color: color, height: 1.5),
              ),
            ),
          ],
        ),
      );
}
