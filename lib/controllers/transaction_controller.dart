import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';

class TransactionController extends ChangeNotifier {
  final TransactionService _service;

  TransactionController({TransactionService? service})
      : _service = service ?? TransactionService();

  bool _isPurchasing = false;
  String? _errorMessage;

  bool get isPurchasing => _isPurchasing;
  String? get errorMessage => _errorMessage;

  // ---------- READS ----------
  Stream<List<TransactionModel>> myPurchases(String buyerId) => _service.streamPurchases(buyerId);

  Stream<List<TransactionModel>> mySales(String sellerId) => _service.streamSales(sellerId);

  Stream<bool> hasPurchased({required String buyerId, required String materialId}) =>
      _service.streamHasPurchased(buyerId: buyerId, materialId: materialId);

  /// Running total of this seller's earnings — derived by summing their
  /// sales stream, not a stored value. Recomputes live on every new sale.
  Stream<double> sellerTotalEarnings(String sellerId) {
    return mySales(sellerId).map(
      (transactions) => transactions.fold<double>(0, (sum, t) => sum + t.sellerEarnings),
    );
  }

  // ---------- ADMIN-ONLY ----------
  /// Every transaction on the platform — pair with an admin-only route/guard
  /// in your View layer; Firestore rules are the real enforcement.
  Stream<List<TransactionModel>> allTransactions() => _service.streamAllTransactions();

  /// Running total of platform earnings (sum of every platform_fee) —
  /// derived the same way as sellerTotalEarnings, just unfiltered.
  Stream<double> totalPlatformEarnings() {
    return allTransactions().map(
      (transactions) => transactions.fold<double>(0, (sum, t) => sum + t.platformFee),
    );
  }

  // ---------- WRITE ----------
  Future<bool> purchaseMaterial({
    required String materialId,
    required String buyerId,
    required String paymentMethod,
  }) async {
    _isPurchasing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.purchaseMaterial(
        materialId: materialId,
        buyerId: buyerId,
        paymentMethod: paymentMethod,
      );
      _isPurchasing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isPurchasing = false;
      notifyListeners();
      return false;
    }
  }

  /// Free-tier equivalent of purchaseMaterial — records a $0 transaction so
  /// a saved free material shows up alongside real purchases in My
  /// Purchases / My Materials → Purchased. Reuses isPurchasing/errorMessage
  /// since a given screen only ever triggers one of the two at a time.
  Future<bool> saveFreeMaterial({
    required String materialId,
    required String buyerId,
  }) async {
    _isPurchasing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.saveFreeMaterial(materialId: materialId, buyerId: buyerId);
      _isPurchasing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isPurchasing = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}