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

  /// Records a "save" of a public_free material — the free-tier equivalent
  /// of purchaseMaterial, so free materials plug into the exact same
  /// transaction log / hasPurchased / myPurchases machinery as paid ones
  /// (no separate "saved materials" concept needed). No fee math applies —
  /// price/fee/earnings all record as 0 — and payment_method is fixed to
  /// 'Free' rather than a buyer-chosen method.
  ///
  /// NOTE: like purchaseMaterial, this doesn't stop a buyer from calling it
  /// twice server-side (Firestore transactions can only get() individual
  /// docs, not run a where() query, so there's no atomic "already saved"
  /// check here). The UI guards against double-saves by hiding the Save
  /// button once streamHasPurchased() reports true for this buyer/material.
  Future<String> saveFreeMaterial({
    required String materialId,
    required String buyerId,
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
      if (data['visibility'] != 'public_free') {
        throw Exception('This material is not free.');
      }
      final sellerId = data['owner_id'] as String? ?? '';
      if (sellerId == buyerId) {
        throw Exception('This is already your own material.');
      }

      txn.set(transactionRef, {
        'transaction_id': transactionRef.id,
        'buyer_id': buyerId,
        'seller_id': sellerId,
        'material_id': materialId,
        'material_price': 0,
        'platform_fee': 0,
        'seller_earnings': 0,
        'payment_method': 'Free',
        'status': 'completed',
        'purchased_at': FieldValue.serverTimestamp(),
      });

      txn.update(materialRef, {'purchase_count': FieldValue.increment(1)});
    });

    return transactionRef.id;
  }

  // ---------- READS (Stream = real-time) ----------

  /// Materials this user has bought (or saved, for free ones) — "My Purchases".
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

  /// Whether this buyer already owns/saved this material — gates access to
  /// a public_paid material's full content, and drives the Save/Saved
  /// button state for public_free materials.
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