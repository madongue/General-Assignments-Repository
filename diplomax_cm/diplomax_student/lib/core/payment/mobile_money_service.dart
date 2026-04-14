import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Real Mobile Money payment service.
///
/// Integrates with:
/// - MTN Mobile Money (MoMo) API — MTN Cameroon Collection API v1
/// - Orange Money API — Orange Cameroon disbursement/collection endpoints
///
/// Flow:
/// 1. Client calls [requestPayment] → generates an external transaction ID
/// 2. Backend calls the operator's API to initiate the USSD push
/// 3. Customer approves on their phone (out-of-band, real USSD prompt)
/// 4. Operator calls our backend webhook with payment status
/// 5. Client polls [checkStatus] until the payment is confirmed or failed
///
/// API credentials are stored server-side; the mobile client only sends
/// the phone number and amount — never the API keys.
class MobileMoneyService {
  final Dio _dio;

  MobileMoneyService(this._dio);

  // ── MTN MoMo ───────────────────────────────────────────────────────────────

  /// Initiates an MTN MoMo collection request.
  /// Triggers a USSD push to the customer's phone.
  ///
  /// [phoneNumber]: Format '6XXXXXXXX' (Cameroon, no +237)
  /// [amountFcfa]: Amount in FCFA (minimum 100)
  /// [productDescription]: What the payment is for
  Future<PaymentInitResult> initiateMtnMomo({
    required String phoneNumber,
    required int amountFcfa,
    required String productDescription,
    required String studentMatricule,
  }) async {
    final externalId = const Uuid().v4();
    try {
      final response = await _dio.post(
        '/payments/mtn/collect',
        data: {
          'external_id': externalId,
          'phone_number': '237$phoneNumber', // E.164 format
          'amount': amountFcfa,
          'currency': 'XAF',
          'payer_message': productDescription,
          'payee_note': 'Diplomax CM — $studentMatricule',
        },
      );
      final data = response.data as Map<String, dynamic>;
      return PaymentInitResult(
        success: true,
        transactionId: data['transaction_id'] as String,
        externalId: externalId,
        status: PaymentStatus.pending,
        provider: PaymentProvider.mtn,
        message: 'A payment request has been sent to +237 $phoneNumber. '
            'Please approve it on your phone.',
      );
    } on DioException catch (e) {
      return PaymentInitResult(
        success: false,
        externalId: externalId,
        status: PaymentStatus.failed,
        provider: PaymentProvider.mtn,
        errorCode: e.response?.statusCode?.toString(),
        message: _extractError(e),
      );
    }
  }

  // ── Orange Money ───────────────────────────────────────────────────────────

  /// Initiates an Orange Money payment collection request.
  ///
  /// [phoneNumber]: Format '6XXXXXXXX' (Cameroon Orange number)
  Future<PaymentInitResult> initiateOrangeMoney({
    required String phoneNumber,
    required int amountFcfa,
    required String productDescription,
    required String studentMatricule,
  }) async {
    final externalId = const Uuid().v4();
    try {
      final response = await _dio.post(
        '/payments/orange/collect',
        data: {
          'external_id': externalId,
          'phone_number': '237$phoneNumber',
          'amount': amountFcfa,
          'currency': 'XAF',
          'description': productDescription,
          'reference': studentMatricule,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return PaymentInitResult(
        success: true,
        transactionId: data['transaction_id'] as String,
        externalId: externalId,
        status: PaymentStatus.pending,
        provider: PaymentProvider.orange,
        message: 'An Orange Money request has been sent to +237 $phoneNumber. '
            'Enter your PIN to confirm.',
      );
    } on DioException catch (e) {
      return PaymentInitResult(
        success: false,
        externalId: externalId,
        status: PaymentStatus.failed,
        provider: PaymentProvider.orange,
        errorCode: e.response?.statusCode?.toString(),
        message: _extractError(e),
      );
    }
  }

  // ── Status Polling ─────────────────────────────────────────────────────────

  /// Polls the backend for the payment status.
  /// Call this every 3 seconds until [PaymentStatus] is not [pending].
  Future<PaymentStatusResult> checkStatus(String transactionId) async {
    try {
      final response = await _dio.get(
        '/payments/status/$transactionId',
      );
      final data = response.data as Map<String, dynamic>;
      final statusStr = data['status'] as String;
      final status = _parseStatus(statusStr);
      return PaymentStatusResult(
        transactionId: transactionId,
        status: status,
        paidAt: data['paid_at'] != null
            ? DateTime.tryParse(data['paid_at'] as String)
            : null,
        receiptUrl: data['receipt_url'] as String?,
        message: data['message'] as String?,
      );
    } on DioException catch (e) {
      return PaymentStatusResult(
        transactionId: transactionId,
        status: PaymentStatus.unknown,
        message: _extractError(e),
      );
    }
  }

  /// Polls [checkStatus] every [intervalSeconds] seconds until the payment
  /// is confirmed, failed, or [maxAttempts] is reached.
  Stream<PaymentStatusResult> pollUntilComplete({
    required String transactionId,
    int intervalSeconds = 3,
    int maxAttempts = 40, // 2 minutes total
  }) async* {
    for (int i = 0; i < maxAttempts; i++) {
      final result = await checkStatus(transactionId);
      yield result;
      if (result.status != PaymentStatus.pending) break;
      await Future.delayed(Duration(seconds: intervalSeconds));
    }
  }

  // ── Price Catalogue ────────────────────────────────────────────────────────

  static const Map<String, int> productPrices = {
    'certification_numerique': 500,
    'releve_officiel': 1000,
    'dossier_complet': 2500,
    'abonnement_recruteur': 15000,
  };

  // ── Utilities ──────────────────────────────────────────────────────────────

  PaymentStatus _parseStatus(String s) {
    switch (s.toLowerCase()) {
      case 'successful':
      case 'success':
      case 'paid':
        return PaymentStatus.successful;
      case 'failed':
      case 'rejected':
        return PaymentStatus.failed;
      case 'pending':
      case 'processing':
        return PaymentStatus.pending;
      case 'cancelled':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.unknown;
    }
  }

  String _extractError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) return data['detail'] as String? ?? 'Payment failed';
      return 'Payment failed. Please try again.';
    } catch (_) {
      return 'Network error. Check your connection.';
    }
  }
}

// ── Data types ────────────────────────────────────────────────────────────────

enum PaymentProvider { mtn, orange }
enum PaymentStatus   { pending, successful, failed, cancelled, unknown }

class PaymentInitResult {
  final bool success;
  final String? transactionId;
  final String externalId;
  final PaymentStatus status;
  final PaymentProvider provider;
  final String? errorCode;
  final String message;

  PaymentInitResult({
    required this.success,
    this.transactionId,
    required this.externalId,
    required this.status,
    required this.provider,
    this.errorCode,
    required this.message,
  });
}

class PaymentStatusResult {
  final String transactionId;
  final PaymentStatus status;
  final DateTime? paidAt;
  final String? receiptUrl;
  final String? message;

  PaymentStatusResult({
    required this.transactionId,
    required this.status,
    this.paidAt,
    this.receiptUrl,
    this.message,
  });

  bool get isComplete => status != PaymentStatus.pending && status != PaymentStatus.unknown;
  bool get isSuccessful => status == PaymentStatus.successful;
}
