import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

class TransactionService {
  static const double platformFeeRate = 0.10; // 10% Platform Fee

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _db.collection('transactions');

  // ---------- WRITES ----------

  /// Buys a paid material.
  Future<String> purchaseMaterial({
    required String materialId,
    required String buyerId,
    required String paymentMethod,
  }) {
    return _createTransaction(
      materialId: materialId,
      buyerId: buyerId,
      paymentMethod: paymentMethod,
      requiredVisibility: 'public_paid',
    );
  }

  /// Saves a free material to the buyer's library.
  Future<String> saveFreeMaterial({
    required String materialId,
    required String buyerId,
  }) {
    return _createTransaction(
      materialId: materialId,
      buyerId: buyerId,
      paymentMethod: 'Free',
      requiredVisibility: 'public_free',
    );
  }

  /// Shared logic for paid and free transactions.
  ///
  /// The transaction ID is "buyerId_materialId", so a buyer can only ever have
  /// one transaction per material. Checking for it inside the Firestore
  /// transaction stops double-taps from creating duplicate purchases.
  Future<String> _createTransaction({
    required String materialId,
    required String buyerId,
    required String paymentMethod,
    required String requiredVisibility,
  }) async {
    final isPaid = requiredVisibility == 'public_paid';
    final materialRef = _db.collection('materials').doc(materialId);
    final transactionRef = _transactions.doc('${buyerId}_$materialId');

    await _db.runTransaction((txn) async {
      final materialSnap = await txn.get(materialRef);
      final data = materialSnap.data();
      if (!materialSnap.exists || data == null) {
        throw Exception('This material no longer exists.');
      }
      if (data['status'] != 'active') {
        throw Exception('This material is no longer available.');
      }
      if (data['visibility'] != requiredVisibility) {
        throw Exception(
          isPaid ? 'This material is not for sale.' : 'This material is not free.',
        );
      }

      final sellerId = data['owner_id'] as String? ?? '';
      if (sellerId == buyerId) {
        throw Exception('This is already your own material.');
      }

      if ((await txn.get(transactionRef)).exists) {
        throw Exception('You already own this material.');
      }

      final price = isPaid ? (data['price'] as num?)?.toDouble() ?? 0 : 0.0;
      if (isPaid && price <= 0) {
        throw Exception('This material has no valid price.');
      }

      final platformFee =
          double.parse((price * platformFeeRate).toStringAsFixed(2));
      final sellerEarnings =
          double.parse((price - platformFee).toStringAsFixed(2));

      txn.set(transactionRef, {
        'transaction_id': transactionRef.id,
        'buyer_id': buyerId,
        'seller_id': sellerId,
        'material_id': materialId,
        'material_price': price,
        'platform_fee': platformFee,
        'seller_earnings': sellerEarnings,
        'payment_method': paymentMethod,
        'status': 'completed',
        'purchased_at': FieldValue.serverTimestamp(),
      });

      txn.update(materialRef, {'purchase_count': FieldValue.increment(1)});
    });

    return transactionRef.id;
  }

  // ---------- READS (Stream = real-time) ----------
  Stream<List<TransactionModel>> streamPurchases(String buyerId) {
    return _transactions
        .where('buyer_id', isEqualTo: buyerId)
        .orderBy('purchased_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TransactionModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<TransactionModel>> streamSales(String sellerId) {
    return _transactions
        .where('seller_id', isEqualTo: sellerId)
        .orderBy('purchased_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TransactionModel.fromMap(d.id, d.data())).toList());
  }

  Stream<bool> streamHasPurchased({required String buyerId, required String materialId}) {
    return _transactions
        .where('buyer_id', isEqualTo: buyerId)
        .where('material_id', isEqualTo: materialId)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty);
  }

  Stream<List<TransactionModel>> streamAllTransactions() {
    return _transactions
        .orderBy('purchased_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TransactionModel.fromMap(d.id, d.data())).toList());
  }
}