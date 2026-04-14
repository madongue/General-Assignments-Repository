import 'package:dio/dio.dart';

/// Real Hyperledger Fabric blockchain service.
///
/// Communicates with the Fabric REST API gateway deployed alongside the
/// Diplomax backend. The gateway is connected to the 'diplomax-channel'
/// and the 'DiplomaxChaincode' smart contract.
///
/// Each diploma hash is stored in an immutable Fabric ledger entry with:
/// - documentId (UUID)
/// - sha256Hash (hex string)
/// - studentMatricule
/// - universityId
/// - issuedAt (ISO timestamp)
/// - issuerPublicKey (university's signing key fingerprint)
///
/// Once written, the entry cannot be modified — only new entries can be
/// appended. This guarantees that even if the Diplomax database is
/// compromised, the original hashes remain independently verifiable on
/// the blockchain.
class BlockchainService {
  final Dio _dio;

  BlockchainService(this._dio);

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Anchors a document hash on the Hyperledger Fabric ledger.
  /// Returns the Fabric transaction ID on success.
  ///
  /// Called by the university app when issuing a diploma.
  Future<BlockchainWriteResult> anchorDocument({
    required String documentId,
    required String sha256Hash,
    required String studentMatricule,
    required String universityId,
    required String issuedAt,
    required String issuerPublicKeyFingerprint,
  }) async {
    try {
      final response = await _dio.post(
        '/blockchain/anchor',
        data: {
          'document_id': documentId,
          'sha256_hash': sha256Hash,
          'student_matricule': studentMatricule,
          'university_id': universityId,
          'issued_at': issuedAt,
          'issuer_key_fingerprint': issuerPublicKeyFingerprint,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return BlockchainWriteResult(
        success: true,
        transactionId: data['transaction_id'] as String,
        blockNumber: data['block_number'] as int?,
        timestamp: DateTime.tryParse(data['timestamp'] as String? ?? ''),
      );
    } on DioException catch (e) {
      return BlockchainWriteResult(
        success: false,
        errorMessage: _extractError(e),
      );
    }
  }

  // ── Verify ─────────────────────────────────────────────────────────────────

  /// Queries the Hyperledger ledger to verify a document hash.
  ///
  /// This is the trustless verification path — it does NOT go through the
  /// Diplomax database, so even a compromised DB cannot affect the result.
  ///
  /// Returns the original anchored record if found, or a failed result.
  Future<BlockchainVerifyResult> verifyDocument({
    required String documentId,
    required String sha256HashToVerify,
  }) async {
    try {
      final response = await _dio.get(
        '/blockchain/verify/$documentId',
        queryParameters: {'hash': sha256HashToVerify},
      );
      final data = response.data as Map<String, dynamic>;
      final storedHash = data['sha256_hash'] as String;
      final hashesMatch = storedHash == sha256HashToVerify;

      return BlockchainVerifyResult(
        found: true,
        isAuthentic: hashesMatch,
        storedHash: storedHash,
        transactionId: data['transaction_id'] as String?,
        blockNumber: data['block_number'] as int?,
        anchoredAt: DateTime.tryParse(data['issued_at'] as String? ?? ''),
        studentMatricule: data['student_matricule'] as String?,
        universityId: data['university_id'] as String?,
        issuerKeyFingerprint: data['issuer_key_fingerprint'] as String?,
        tamperingDetected: !hashesMatch,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return BlockchainVerifyResult(
          found: false,
          isAuthentic: false,
          tamperingDetected: false,
          errorMessage: 'Document not found on blockchain.',
        );
      }
      return BlockchainVerifyResult(
        found: false,
        isAuthentic: false,
        tamperingDetected: false,
        errorMessage: _extractError(e),
      );
    }
  }

  // ── History ────────────────────────────────────────────────────────────────

  /// Returns the full Fabric ledger history for a document.
  /// Useful for auditing — shows every time a query was made.
  Future<List<BlockchainHistoryEntry>> getHistory(String documentId) async {
    try {
      final response = await _dio.get('/blockchain/history/$documentId');
      final list = response.data as List;
      return list
          .cast<Map<String, dynamic>>()
          .map((e) => BlockchainHistoryEntry(
                transactionId: e['tx_id'] as String,
                timestamp: DateTime.tryParse(e['timestamp'] as String? ?? ''),
                isDelete: e['is_delete'] as bool? ?? false,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Network status ─────────────────────────────────────────────────────────

  /// Returns true if the Fabric gateway is reachable and the channel is live.
  Future<bool> isNetworkHealthy() async {
    try {
      final response = await _dio.get('/blockchain/health');
      return response.data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  String _extractError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) return data['detail'] as String? ?? 'Blockchain error';
    } catch (_) {}
    return 'Could not reach blockchain network.';
  }
}

// ── Data types ────────────────────────────────────────────────────────────────

class BlockchainWriteResult {
  final bool success;
  final String? transactionId;
  final int? blockNumber;
  final DateTime? timestamp;
  final String? errorMessage;

  BlockchainWriteResult({
    required this.success,
    this.transactionId,
    this.blockNumber,
    this.timestamp,
    this.errorMessage,
  });
}

class BlockchainVerifyResult {
  final bool found;
  final bool isAuthentic;
  final bool tamperingDetected;
  final String? storedHash;
  final String? transactionId;
  final int? blockNumber;
  final DateTime? anchoredAt;
  final String? studentMatricule;
  final String? universityId;
  final String? issuerKeyFingerprint;
  final String? errorMessage;

  BlockchainVerifyResult({
    required this.found,
    required this.isAuthentic,
    required this.tamperingDetected,
    this.storedHash,
    this.transactionId,
    this.blockNumber,
    this.anchoredAt,
    this.studentMatricule,
    this.universityId,
    this.issuerKeyFingerprint,
    this.errorMessage,
  });
}

class BlockchainHistoryEntry {
  final String transactionId;
  final DateTime? timestamp;
  final bool isDelete;
  BlockchainHistoryEntry({
    required this.transactionId,
    this.timestamp,
    required this.isDelete,
  });
}
