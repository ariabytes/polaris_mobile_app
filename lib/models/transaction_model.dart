import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String transactionId;
  final String buyerId;
  final String sellerId;
  final String materialId;
  final double materialPrice;
  final double platformFee;
  final double sellerEarnings;
  final String paymentMethod; // "Maya" | "GCash" | "Card"
  final String status; // "completed"
  final DateTime? purchasedAt;

  TransactionModel({
    required this.transactionId,
    required this.buyerId,
    required this.sellerId,
    required this.materialId,
    required this.materialPrice,
    required this.platformFee,
    required this.sellerEarnings,
    required this.paymentMethod,
    this.status = 'completed',
    this.purchasedAt,
  });

  factory TransactionModel.fromMap(String docId, Map<String, dynamic> data) {
    return TransactionModel(
      transactionId: docId,
      buyerId: data['buyer_id'] ?? '',
      sellerId: data['seller_id'] ?? '',
      materialId: data['material_id'] ?? '',
      materialPrice: (data['material_price'] as num?)?.toDouble() ?? 0,
      platformFee: (data['platform_fee'] as num?)?.toDouble() ?? 0,
      sellerEarnings: (data['seller_earnings'] as num?)?.toDouble() ?? 0,
      paymentMethod: data['payment_method'] ?? '',
      status: data['status'] ?? 'completed',
      purchasedAt: (data['purchased_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transaction_id': transactionId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'material_id': materialId,
      'material_price': materialPrice,
      'platform_fee': platformFee,
      'seller_earnings': sellerEarnings,
      'payment_method': paymentMethod,
      'status': status,
      'purchased_at':
          purchasedAt != null ? Timestamp.fromDate(purchasedAt!) : FieldValue.serverTimestamp(),
    };
  }
}