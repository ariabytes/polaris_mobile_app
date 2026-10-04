import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

class TransactionService {
  static const double platformFeeRate = 0.10; // 10% Platform Fee

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _db.collection('transactions');

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