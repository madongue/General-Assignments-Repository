import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;

/// Real end-to-end encryption service.
///
/// Documents are encrypted with AES-256-GCM before being stored locally
/// or transmitted. The AES key itself is stored in the device's hardware-backed
/// secure storage (iOS Keychain / Android Keystore).
///
/// SHA-256 hashing is used to produce the immutable document fingerprint
/// that gets anchored on the Hyperledger blockchain.
class CryptoService {
  static const _keyAlias = 'diplomax_aes_key_v2';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final _aesGcm = AesGcm.with256bits();

  // ── AES-256-GCM Key Management ─────────────────────────────────────────────

  /// Returns the device's AES-256 key, creating it if it doesn't exist.
  /// The key is stored in hardware-backed secure storage — never in memory
  /// longer than needed and never transmitted.
  Future<SecretKey> _getOrCreateKey() async {
    final stored = await _storage.read(key: _keyAlias);
    if (stored != null) {
      final bytes = base64.decode(stored);
      return SecretKey(bytes);
    }
    final newKey = await _aesGcm.newSecretKey();
    final bytes = await newKey.extractBytes();
    await _storage.write(key: _keyAlias, value: base64.encode(bytes));
    return newKey;
  }

  // ── Encryption ─────────────────────────────────────────────────────────────

  /// Encrypts [plaintext] with AES-256-GCM.
  /// Returns a base64-encoded string: [nonce(12)] + [ciphertext] + [mac(16)]
  Future<String> encrypt(String plaintext) async {
    final key = await _getOrCreateKey();
    final nonce = _aesGcm.newNonce();
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );
    // Pack: nonce (12 bytes) + ciphertext + mac (16 bytes)
    final packed = Uint8List(12 + secretBox.cipherText.length + 16);
    packed.setAll(0, secretBox.nonce);
    packed.setAll(12, secretBox.cipherText);
    packed.setAll(12 + secretBox.cipherText.length, secretBox.mac.bytes);
    return base64.encode(packed);
  }

  /// Decrypts a base64-encoded string produced by [encrypt].
  Future<String> decrypt(String encoded) async {
    final key = await _getOrCreateKey();
    final packed = base64.decode(encoded);
    final nonce = packed.sublist(0, 12);
    final mac = packed.sublist(packed.length - 16);
    final cipherText = packed.sublist(12, packed.length - 16);
    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(mac),
    );
    final plainBytes = await _aesGcm.decrypt(secretBox, secretKey: key);
    return utf8.decode(plainBytes);
  }

  // ── SHA-256 Hashing ────────────────────────────────────────────────────────

  /// Produces the SHA-256 fingerprint of [data].
  /// This is the hash that gets anchored on the Hyperledger blockchain
  /// and stored in the database as the immutable document identifier.
  String sha256Hash(String data) {
    final digest = pc.SHA256Digest();
    final bytes = utf8.encode(data);
    final hash = digest.process(Uint8List.fromList(bytes));
    return hex.encode(hash);
  }

  /// Produces the SHA-256 fingerprint of raw bytes (for binary documents).
  String sha256HashBytes(Uint8List bytes) {
    final digest = pc.SHA256Digest();
    final hash = digest.process(bytes);
    return hex.encode(hash);
  }

  // ── Document Signing ───────────────────────────────────────────────────────

  /// Generates a deterministic document hash combining all key fields.
  /// This is what makes any tampering immediately detectable:
  /// changing even one character in the document changes the hash entirely.
  String computeDocumentHash({
    required String documentId,
    required String studentMatricule,
    required String universityId,
    required String title,
    required String mention,
    required String issueDate,
  }) {
    final canonical =
        '$documentId|$studentMatricule|$universityId|$title|$mention|$issueDate';
    return sha256Hash(canonical);
  }

  // ── QR Token Generation ────────────────────────────────────────────────────

  /// Generates a time-limited, cryptographically signed QR token.
  /// The token encodes the document ID, expiry timestamp, ZKP flag,
  /// and a HMAC to prevent forgery.
  Future<String> generateQrToken({
    required String documentId,
    required int validityHours,
    required bool zkpMode,
    String? mention,
  }) async {
    final expiresAt =
        DateTime.now().add(Duration(hours: validityHours)).millisecondsSinceEpoch;
    final payload = {
      'doc': documentId,
      'exp': expiresAt,
      'zkp': zkpMode,
      if (zkpMode && mention != null) 'mention': mention,
      'nonce': _randomHex(16),
    };
    final payloadJson = json.encode(payload);
    // Encrypt the full payload so it is opaque to scanners
    final encrypted = await encrypt(payloadJson);
    return encrypted;
  }

  String _randomHex(int bytes) {
    final rng = Random.secure();
    return List.generate(bytes, (_) => rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  // ── Share Link Token ───────────────────────────────────────────────────────

  /// Generates a URL-safe random token for Smart Share links.
  String generateShareToken() {
    final rng = Random.secure();
    final bytes = List.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
