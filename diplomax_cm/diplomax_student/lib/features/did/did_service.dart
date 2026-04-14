// ═══════════════════════════════════════════════════════════════════════════
// DIPLOMAX CM — Decentralized Identity (DID) Service
//
// Implements W3C DID (Decentralized Identifiers) standard.
// Each student owns a DID of the form: did:diplomax:cm:{uuid}
//
// The DID Document contains:
//   - The student's DID
//   - Public key for verifiable credentials
//   - Service endpoints (diploma vault URL)
//
// This ensures the STUDENT owns their identity — not the app.
// The private key never leaves the device (iOS Keychain / Android Keystore).
// The DID Document is anchored on the blockchain.
//
// W3C DID Spec: https://www.w3.org/TR/did-core/
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:convert/convert.dart';
import 'package:uuid/uuid.dart';

/// Decentralized Identity service for Diplomax CM.
///
/// The student's DID is: did:diplomax:cm:{uuid}
/// This identifier is permanent, owned by the student, and not controlled
/// by any institution or even by Diplomax itself.
class DidService {
  static const _didAlias    = 'diplomax_did_v1';
  static const _privAlias   = 'diplomax_did_private_key_v1';
  static const _pubAlias    = 'diplomax_did_public_key_v1';
  static const _docAlias    = 'diplomax_did_document_v1';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // ── DID existence ──────────────────────────────────────────────────────────

  /// Returns the student's DID if it exists, null otherwise.
  Future<String?> getDid() => _storage.read(key: _didAlias);

  /// Returns true if this device has a DID with an associated key pair.
  Future<bool> hasDid() async {
    final did  = await _storage.read(key: _didAlias);
    final priv = await _storage.read(key: _privAlias);
    return did != null && priv != null;
  }

  // ── DID creation ───────────────────────────────────────────────────────────

  /// Creates a new DID for the student if one doesn't exist.
  /// Returns the DID string.
  ///
  /// The process:
  /// 1. Generate a unique identifier (UUID v4)
  /// 2. Generate an RSA-2048 key pair
  /// 3. Store private key in hardware-backed secure storage
  /// 4. Build and store the DID Document
  /// 5. Return the DID
  Future<DidDocument> createDid({
    required String studentName,
    required String matricule,
  }) async {
    // Check if already exists
    final existing = await getDid();
    if (existing != null) {
      final docStr = await _storage.read(key: _docAlias);
      if (docStr != null) {
        return DidDocument.fromJson(jsonDecode(docStr));
      }
    }

    // Generate DID identifier
    final uid = const Uuid().v4().replaceAll('-', '');
    final did = 'did:diplomax:cm:$uid';

    // Generate RSA-2048 key pair for the DID
    final keyPair = await _generateKeyPair();
    final privKey = keyPair.privateKey as pc.RSAPrivateKey;
    final pubKey  = keyPair.publicKey  as pc.RSAPublicKey;

    // Encode public key as JWK (JSON Web Key)
    final jwk = _rsaPublicKeyToJwk(pubKey, keyId: '$did#key-1');

    // Build the DID Document (W3C compliant)
    final now = DateTime.now().toUtc().toIso8601String();
    final document = DidDocument(
      id:      did,
      context: ['https://www.w3.org/ns/did/v1', 'https://w3id.org/security/suites/jws-2020/v1'],
      created: now,
      updated: now,
      verificationMethod: [
        VerificationMethod(
          id:           '$did#key-1',
          type:         'JsonWebKey2020',
          controller:   did,
          publicKeyJwk: jwk,
        ),
      ],
      authentication:  ['$did#key-1'],
      keyAgreement:    ['$did#key-1'],
      service: [
        DidService_(
          id:              '$did#vault',
          type:            'DiplomaxVault',
          serviceEndpoint: 'https://verify.diplomax.cm/vault/$uid',
        ),
      ],
    );

    // Persist to secure storage
    await _storage.write(key: _didAlias,  value: did);
    await _storage.write(key: _pubAlias,  value: jwk.toString());
    await _storage.write(key: _docAlias,  value: jsonEncode(document.toJson()));
    await _storage.write(
      key:   _privAlias,
      value: '${privKey.modulus!.toRadixString(16)}|'
             '${privKey.privateExponent!.toRadixString(16)}|'
             '${privKey.p!.toRadixString(16)}|'
             '${privKey.q!.toRadixString(16)}',
    );

    return document;
  }

  // ── DID Document ───────────────────────────────────────────────────────────

  /// Returns the stored DID Document for this student.
  Future<DidDocument?> getDocument() async {
    final docStr = await _storage.read(key: _docAlias);
    if (docStr == null) return null;
    return DidDocument.fromJson(jsonDecode(docStr));
  }

  /// Returns the DID Document as a JSON string, formatted for sharing.
  Future<String?> getDocumentJson() async {
    final docStr = await _storage.read(key: _docAlias);
    if (docStr == null) return null;
    final doc = jsonDecode(docStr);
    return const JsonEncoder.withIndent('  ').convert(doc);
  }

  // ── Verifiable Credential Signing ─────────────────────────────────────────

  /// Signs a diploma credential with the student's DID private key.
  /// This creates a Verifiable Credential (VC) that proves the student
  /// claims ownership of this diploma.
  ///
  /// The VC can be presented to an employer who can verify:
  /// 1. The diploma is authentic (blockchain check)
  /// 2. The person presenting it is the DID holder (signature check)
  Future<String> signCredential(Map<String, dynamic> credential) async {
    final privStr = await _storage.read(key: _privAlias);
    if (privStr == null) throw Exception('DID private key not found');

    final parts = privStr.split('|');
    final priv  = pc.RSAPrivateKey(
      BigInt.parse(parts[0], radix: 16),
      BigInt.parse(parts[1], radix: 16),
      BigInt.parse(parts[2], radix: 16),
      BigInt.parse(parts[3], radix: 16),
    );

    final payload = jsonEncode(credential);
    final signer  = pc.Signer('SHA-256/RSA')
      ..init(true, pc.PrivateKeyParameter<pc.RSAPrivateKey>(priv));

    final sig = signer.generateSignature(
      Uint8List.fromList(payload.codeUnits)) as pc.RSASignature;

    // Return as a Verifiable Presentation (VP) wrapper
    final vp = {
      '@context': ['https://www.w3.org/2018/credentials/v1'],
      'type':     ['VerifiablePresentation'],
      'holder':   await getDid(),
      'verifiableCredential': [credential],
      'proof': {
        'type':               'RsaSignature2018',
        'created':            DateTime.now().toUtc().toIso8601String(),
        'proofPurpose':       'authentication',
        'verificationMethod': '${await getDid()}#key-1',
        'jws':                base64Url.encode(sig.bytes),
      },
    };
    return jsonEncode(vp);
  }

  // ── Key generation ────────────────────────────────────────────────────────

  Future<pc.AsymmetricKeyPair<pc.PublicKey, pc.PrivateKey>> _generateKeyPair() async {
    final secureRandom = pc.SecureRandom('Fortuna');
    final seed = List.generate(32, (i) => (i * 7 + DateTime.now().microsecond) % 256);
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seed)));

    final keyGen = pc.RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        secureRandom,
      ));

    return keyGen.generateKeyPair();
  }

  Map<String, String> _rsaPublicKeyToJwk(pc.RSAPublicKey key, {required String keyId}) {
    return {
      'kid':  keyId,
      'kty':  'RSA',
      'use':  'sig',
      'alg':  'RS256',
      'n':    base64Url.encode(_bigIntToBytes(key.modulus!)).replaceAll('=', ''),
      'e':    base64Url.encode(_bigIntToBytes(key.publicExponent!)).replaceAll('=', ''),
    };
  }

  Uint8List _bigIntToBytes(BigInt n) {
    final hex = n.toRadixString(16).padLeft((n.bitLength + 7) ~/ 4 * 2, '0');
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  /// Delete the DID and all associated keys.
  /// WARNING: This is irreversible. The DID cannot be recovered.
  Future<void> deleteDid() async {
    await _storage.delete(key: _didAlias);
    await _storage.delete(key: _privAlias);
    await _storage.delete(key: _pubAlias);
    await _storage.delete(key: _docAlias);
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class DidDocument {
  final String id;
  final List<String> context;
  final String created;
  final String updated;
  final List<VerificationMethod> verificationMethod;
  final List<String> authentication;
  final List<String> keyAgreement;
  final List<DidService_> service;

  DidDocument({
    required this.id,
    required this.context,
    required this.created,
    required this.updated,
    required this.verificationMethod,
    required this.authentication,
    required this.keyAgreement,
    required this.service,
  });

  factory DidDocument.fromJson(Map<String, dynamic> j) => DidDocument(
    id:       j['id'] as String,
    context:  (j['@context'] as List).cast<String>(),
    created:  j['created'] as String,
    updated:  j['updated'] as String,
    verificationMethod: ((j['verificationMethod'] as List?) ?? [])
        .map((m) => VerificationMethod.fromJson(m as Map<String, dynamic>))
        .toList(),
    authentication: ((j['authentication'] as List?) ?? []).cast<String>(),
    keyAgreement:   ((j['keyAgreement'] as List?) ?? []).cast<String>(),
    service: ((j['service'] as List?) ?? [])
        .map((s) => DidService_.fromJson(s as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    '@context':           context,
    'id':                 id,
    'created':            created,
    'updated':            updated,
    'verificationMethod': verificationMethod.map((v) => v.toJson()).toList(),
    'authentication':     authentication,
    'keyAgreement':       keyAgreement,
    'service':            service.map((s) => s.toJson()).toList(),
  };
}

class VerificationMethod {
  final String id;
  final String type;
  final String controller;
  final Map<String, String> publicKeyJwk;

  VerificationMethod({
    required this.id,
    required this.type,
    required this.controller,
    required this.publicKeyJwk,
  });

  factory VerificationMethod.fromJson(Map<String, dynamic> j) => VerificationMethod(
    id:           j['id'] as String,
    type:         j['type'] as String,
    controller:   j['controller'] as String,
    publicKeyJwk: (j['publicKeyJwk'] as Map).cast<String, String>(),
  );

  Map<String, dynamic> toJson() => {
    'id':           id,
    'type':         type,
    'controller':   controller,
    'publicKeyJwk': publicKeyJwk,
  };
}

class DidService_ {
  final String id;
  final String type;
  final String serviceEndpoint;

  DidService_({required this.id, required this.type, required this.serviceEndpoint});

  factory DidService_.fromJson(Map<String, dynamic> j) => DidService_(
    id:              j['id'] as String,
    type:            j['type'] as String,
    serviceEndpoint: j['serviceEndpoint'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id':              id,
    'type':            type,
    'serviceEndpoint': serviceEndpoint,
  };
}
