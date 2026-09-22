import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

/// Talks to the `transactions` collection (and touches `materials` for the
/// purchase_count bump). This is a MOCK payment flow — no real payment
/// gateway, per the project scope. payment_method is just a label the
/// buyer picked in the UI.
class TransactionService {
  static const double platformFeeRate = 0.10; // 10% platform / 90% creator

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _db.collection('transactions');

  /// Reads the material's current price, writes the transaction, and bumps
  /// the material's purchase_count — all atomically via a Firestore
  /// transaction, so a half-completed purchase can't happen.
  /// Throws an Exception with a user-facing message on failure.
  Future<String> purchaseMaterial({
    required String materialId,
    required String buyerId,
    required String paymentMethod,
  }) async {
    final materialRef = _db.collection('materials').doc(materialId);
    final transactionRef = _transactions.doc();

    await _db.runTransaction((txn) async {
      final materialSnap = await txn.get(materialRef);
      if (!materialSnap.exists || materialSnap.data() == null) {
        throw Exception('This material no longer exists.');
      }
      final data = materialSnap.data()!;

      if (data['status'] != 'active') {
        throw Exception('This material is no longer available.');
      }
      if (data['visibility'] != 'public_paid') {
        throw Exception('This material is not for sale.');
      }
      final sellerId = data['owner_id'] as String? ?? '';
      if (sellerId == buyerId) {
        throw Exception('You cannot purchase your own material.');
      }

      final price = (data['price'] as num?)?.toDouble() ?? 0;
      final platformFee = double.parse((price * platformFeeRate).toStringAsFixed(2));
      final sellerEarnings = double.parse((price - platformFee).toStringAsFixed(2));

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

  /// Materials this user has bought — "My Purchases".
  Stream<List<TransactionModel>> streamPurchases(String buyerId) {
    return _transactions
        .where('buyer_id', isEqualTo: buyerId)
        .orderBy('purchased_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TransactionModel.fromMap(d.id, d.data())).toList());
  }

  /// Sales/earnings for a material owner — "My Sales" / earnings dashboard.
  Stream<List<TransactionModel>> streamSales(String sellerId) {
    return _transactions
        .where('seller_id', isEqualTo: sellerId)
        .orderBy('purchased_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TransactionModel.fromMap(d.id, d.data())).toList());
  }

  /// Whether this buyer already owns this material — gate access to a
  /// public_paid material's full content on the detail page.
  Stream<bool> streamHasPurchased({required String buyerId, required String materialId}) {
    return _transactions
        .where('buyer_id', isEqualTo: buyerId)
        .where('material_id', isEqualTo: materialId)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty);
  }

  /// EVERY transaction on the platform, unfiltered — admin only.
  /// Firestore security rules must restrict this query to users whose
  /// `users/{uid}.role == "admin"`; this client-side call has no gating
  /// of its own.
  Stream<List<TransactionModel>> streamAllTransactions() {
    return _transactions
        .orderBy('purchased_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TransactionModel.fromMap(d.id, d.data())).toList());
  }
}