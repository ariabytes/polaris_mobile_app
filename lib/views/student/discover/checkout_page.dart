import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/controllers/auth_controller.dart';
import '/controllers/transaction_controller.dart';
import '/models/material_model.dart';
import '../material/document_viewer.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';
/// Mock checkout flow for a public_paid material.
/// Lives at lib/views/student/discover/checkout_page.dart, next to
/// material_detail_page.dart.
///
/// This is a SIMULATED payment flow, matching the rest of Polaris's
/// marketplace scope — no real payment gateway, no card numbers or mobile
/// numbers are ever sent anywhere or stored. Those "details" fields exist
/// purely so the flow feels like a real checkout; TransactionModel has no
/// fields for them, so they're display-only. The only thing that actually
/// gets written to Firestore is what TransactionService.purchaseMaterial
/// already writes: buyer/seller/material ids, price, platform_fee, and
/// seller_earnings, computed automatically inside an atomic transaction.
///
/// Flow: payment method → mock details → Buy Now → receipt (with the
/// material's attachments immediately openable via DocumentViewer, since
/// the purchase has already gone through by the time this screen shows).
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.material});

  final MaterialModel material;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  Color get cream => context.pc.background;
  Color get navy => context.pc.ink;
  Color get purple => context.pc.accent;
  Color get cardColor => context.pc.card;
  Color get fieldColor => context.pc.field;
  Color get goodColor => context.pc.success;
  Color get badColor => context.pc.danger;


  static const List<String> _paymentMethods = ['GCash', 'Maya', 'Card'];

  String _selectedMethod = 'GCash';
  bool _purchased = false;

  final _mobileController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    super.dispose();
  }

  bool get _detailsValid {
    if (_selectedMethod == 'Card') {
      final digits = _cardNumberController.text.replaceAll(' ', '');
      return digits.length == 16 && _cardExpiryController.text.trim().length == 5;
    }
    return _mobileController.text.trim().length >= 10;
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final transactionController = context.watch<TransactionController>();
    final currentUserId = authController.currentUserProfile?.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _purchased ? 'Receipt' : 'Checkout',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: !_purchased,
      ),
      body: SafeArea(
        child: _purchased
            ? _buildReceipt()
            : _buildCheckoutForm(currentUserId, transactionController),
      ),
    );
  }

  // ---------- CHECKOUT FORM ----------

  Widget _buildCheckoutForm(String? currentUserId, TransactionController transactionController) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildMaterialSummary(),
        const SizedBox(height: 20),
        Text('Payment method', style: TextStyle(fontWeight: FontWeight.bold, color: navy, fontSize: 15)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: _paymentMethods
              .map((m) => ChoiceChip(
                    label: Text(m),
                    selected: _selectedMethod == m,
                    onSelected: (_) => setState(() => _selectedMethod = m),
                    selectedColor: purple,
                    labelStyle: TextStyle(color: _selectedMethod == m ? cream : navy),
                    backgroundColor: fieldColor,
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        _buildMockDetailsFields(),
        const SizedBox(height: 8),
        Text(
          'This is a simulated checkout for this class project — no real payment is processed.',
          style: TextStyle(color: navy.withOpacity(0.45), fontSize: 11.5, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 20),
        if (transactionController.errorMessage != null) ...[
          Text(
            transactionController.errorMessage!,
            style: TextStyle(color: badColor, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: currentUserId == null || !_detailsValid || transactionController.isPurchasing
                ? null
                : () => _handleBuy(currentUserId, transactionController),
            child: transactionController.isPurchasing
                ? SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cream),
                  )
                : Text(currentUserId == null
                    ? 'Log in to purchase'
                    : 'Buy Now · ₱${widget.material.price?.toStringAsFixed(2) ?? "0.00"}'),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.material.title,
            style: TextStyle(fontWeight: FontWeight.bold, color: navy, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.material.course} · ${widget.material.semester}',
            style: TextStyle(color: navy.withOpacity(0.6), fontSize: 12.5),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: TextStyle(color: navy.withOpacity(0.7))),
              Text(
                '₱${widget.material.price?.toStringAsFixed(2) ?? "0.00"}',
                style: TextStyle(color: navy, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMockDetailsFields() {
    if (_selectedMethod == 'Card') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _cardNumberController,
            keyboardType: TextInputType.number,
            maxLength: 16,
            onChanged: (_) => setState(() {}),
            decoration: _decoration('Card number'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cardExpiryController,
            maxLength: 5,
            onChanged: (_) => setState(() {}),
            decoration: _decoration('Expiry (MM/YY)').copyWith(counterText: ''),
          ),
        ],
      );
    }

    return TextField(
      controller: _mobileController,
      keyboardType: TextInputType.phone,
      onChanged: (_) => setState(() {}),
      decoration: _decoration('$_selectedMethod mobile number'),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Future<void> _handleBuy(String buyerId, TransactionController transactionController) async {
    final success = await transactionController.purchaseMaterial(
      materialId: widget.material.materialId,
      buyerId: buyerId,
      paymentMethod: _selectedMethod,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _purchased = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(transactionController.errorMessage ?? 'Purchase failed. Please try again.')),
      );
    }
  }

  // ---------- RECEIPT ----------

  Widget _buildReceipt() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: goodColor.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(Icons.check, color: goodColor, size: 32),
            ),
            const SizedBox(height: 12),
            Text('Purchase successful', style: TextStyle(fontWeight: FontWeight.bold, color: navy, fontSize: 17)),
            const SizedBox(height: 4),
            Text(
              'Paid with $_selectedMethod',
              style: TextStyle(color: navy.withOpacity(0.6), fontSize: 12.5),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildMaterialSummary(),
        const SizedBox(height: 20),
        Text(
          'You now have full access, and it\'s saved to My Materials → Purchased.',
          textAlign: TextAlign.center,
          style: TextStyle(color: navy.withOpacity(0.7), fontSize: 12.5),
        ),
        if (widget.material.attachments.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Open your files', style: TextStyle(fontWeight: FontWeight.bold, color: navy, fontSize: 15)),
          const SizedBox(height: 8),
          ...widget.material.attachments.map((a) => _buildAttachmentLink(a)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentLink(Map<String, dynamic> attachment) {
    final format = (attachment['format'] as String? ?? '').toLowerCase();
    final filename = attachment['original_filename'] as String? ?? 'File';
    final url = attachment['url'] as String?;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.insert_drive_file_outlined, color: purple),
        title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(format.toUpperCase()),
        trailing: Icon(Icons.open_in_new, size: 18, color: navy),
        onTap: url == null
            ? null
            : () => DocumentViewer.open(context, fileUrl: url, format: format),
      ),
    );
  }
}