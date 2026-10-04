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

  Stream<double> sellerTotalEarnings(String sellerId) {
    return mySales(sellerId).map(
      (transactions) => transactions.fold<double>(0, (sum, t) => sum + t.sellerEarnings),
    );
  }

  // ---------- ADMIN-ONLY ----------
  Stream<List<TransactionModel>> allTransactions() => _service.streamAllTransactions();

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
}